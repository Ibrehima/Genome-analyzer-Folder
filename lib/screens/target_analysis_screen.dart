import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../engines/target_analysis_engine.dart';
import '../engines/sequence_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

/// Therapeutic / vaccine molecular-target triage module: surface
/// hydrophilicity profiling, transmembrane-segment prediction, and
/// candidate linear-epitope / vaccine-target ranking for a protein
/// sequence (DNA/RNA input is auto-translated via its longest ORF).
class TargetAnalysisScreen extends StatefulWidget {
  const TargetAnalysisScreen({super.key});

  @override
  State<TargetAnalysisScreen> createState() => _TargetAnalysisScreenState();
}

class _TargetAnalysisScreenState extends State<TargetAnalysisScreen> {
  String? _selectedId;
  TargetAnalysisResult? _result;
  String? _note;

  String _bestOrfProtein(String dna) {
    String best = '';
    for (final forward in [true, false]) {
      final seq = forward ? dna : SequenceEngine.reverseComplement(dna);
      for (int f = 0; f < 3; f++) {
        final trimmed = seq.length > f ? seq.substring(f) : '';
        final protein = SequenceEngine.translate(trimmed);
        for (final part in protein.split('*')) {
          final mIdx = part.indexOf('M');
          if (mIdx >= 0) {
            final candidate = part.substring(mIdx);
            if (candidate.length > best.length) best = candidate;
          }
        }
      }
    }
    if (best.isEmpty) best = SequenceEngine.translate(dna);
    return best;
  }

  void _run(BioSequence seq) {
    String protein;
    String note;
    if (seq.type == SequenceType.protein) {
      protein = seq.sequence;
      note = 'Analyzing protein sequence directly.';
    } else {
      final dna = seq.sequence.toUpperCase().replaceAll('U', 'T');
      protein = _bestOrfProtein(dna);
      note =
          'Auto-translated from the longest detected ORF before target analysis.';
    }
    setState(() {
      _result = TargetAnalysisEngine.analyze(protein);
      _note = note;
    });
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) {
      return ReportData(title: 'Therapeutic / Vaccine Target Report');
    }
    return ReportData(
      title: 'Therapeutic & Vaccine Molecular Target Report',
      subtitle: _note ?? '',
      sections: [
        ReportSection(
          title: 'Transmembrane Regions (Kyte-Doolittle heuristic)',
          table: r.transmembraneRegions.isEmpty
              ? null
              : [
                  ['Start', 'End', 'Mean hydrophobicity'],
                  ...r.transmembraneRegions.map(
                    (t) => [
                      '${t.start + 1}',
                      '${t.end}',
                      t.meanHydrophobicity.toStringAsFixed(2),
                    ],
                  ),
                ],
          bodyText: r.transmembraneRegions.isEmpty
              ? 'No transmembrane segments predicted.'
              : null,
        ),
        ReportSection(
          title: 'Candidate Linear Epitopes (Parker hydrophilicity)',
          table: [
            ['Position', 'Peptide', 'Antigenicity score', 'Surface exposed'],
            ...r.candidateEpitopes.map(
              (e) => [
                '${e.start + 1}-${e.end}',
                e.peptide,
                e.antigenicityScore.toStringAsFixed(1),
                e.surfaceExposed ? 'Yes' : 'No',
              ],
            ),
          ],
        ),
        ReportSection(
          title: 'Top Vaccine-Target Candidates',
          bullets: r.vaccineTargetCandidates
              .map(
                (e) =>
                    '${e.peptide}  (pos ${e.start + 1}-${e.end}, score ${e.antigenicityScore.toStringAsFixed(1)})',
              )
              .toList(),
        ),
        ReportSection(title: 'Disclaimer', bodyText: r.disclaimer),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedSeq = _selectedId != null
        ? appState.getSequenceById(_selectedId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapeutic & Vaccine Targets'),
        actions: [
          if (_result != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Target Analysis',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gradTargets.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.gradTargets.first.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.gradTargets.first,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Heuristic exploratory triage only (Parker hydrophilicity + '
                    'Kyte-Doolittle rule-of-thumb) — NOT a validated immunoinformatics '
                    'tool. Always confirm candidates with dedicated tools (IEDB, BepiPred, '
                    'NetMHC) and lab assays before therapeutic/vaccine use.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SequenceSelector(
            selectedIds: _selectedId != null ? [_selectedId!] : [],
            multiple: false,
            onChanged: (v) => setState(() {
              _selectedId = v.isNotEmpty ? v.first : null;
              _result = null;
            }),
            label: 'Select a DNA, RNA or Protein sequence',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedSeq == null ? null : () => _run(selectedSeq),
              icon: const Icon(Icons.vaccines_rounded),
              label: const Text('Analyze Molecular Targets'),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null)
            _TargetResultView(result: _result!, note: _note ?? ''),
        ],
      ),
    );
  }
}

class _TargetResultView extends StatelessWidget {
  final TargetAnalysisResult result;
  final String note;
  const _TargetResultView({required this.result, required this.note});

  @override
  Widget build(BuildContext context) {
    final profile = result.hydrophilicityProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              note,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Surface Hydrophilicity Profile (Parker scale)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Text(
                  'Higher = more likely surface-exposed / hydrophilic region.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: profile.isEmpty
                      ? const Center(child: Text('No data'))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 34,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (int i = 0; i < profile.length; i++)
                                    FlSpot(i.toDouble(), profile[i]),
                                ],
                                isCurved: true,
                                barWidth: 1.6,
                                color: AppColors.gradTargets.first,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.gradTargets.first.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Predicted Transmembrane Regions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (result.transmembraneRegions.isEmpty)
                  const Text(
                    'None predicted — likely a soluble / non-membrane protein.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  ...result.transmembraneRegions.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'pos ${t.start + 1}-${t.end}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'mean hydrophobicity ${t.meanHydrophobicity.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Vaccine-Target Candidates',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Text(
                  'Surface-exposed, non-transmembrane, high-antigenicity-score peptides.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                if (result.vaccineTargetCandidates.isEmpty)
                  const Text(
                    'No strong candidates found with current heuristic thresholds.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  ...result.vaccineTargetCandidates.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.peptide,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  'Position ${e.start + 1}-${e.end}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'score ${e.antigenicityScore.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.disclaimer,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
