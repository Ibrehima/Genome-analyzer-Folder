import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../engines/proteomics_engine.dart';
import '../engines/sequence_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class ProteomicsScreen extends StatefulWidget {
  const ProteomicsScreen({super.key});

  @override
  State<ProteomicsScreen> createState() => _ProteomicsScreenState();
}

class _ProteomicsScreenState extends State<ProteomicsScreen> {
  String? _selectedId;
  bool _autoFrame = true;
  int _frame = 1; // 1,2,3
  bool _forwardStrand = true;
  ProteinPropertiesResult? _result;
  String? _translationNote;

  Map<String, dynamic> _bestOrfFrame(String dna) {
    String best = '';
    int bestFrame = 1;
    bool bestForward = true;
    for (final forward in [true, false]) {
      final seq = forward ? dna : SequenceEngine.reverseComplement(dna);
      for (int f = 0; f < 3; f++) {
        final trimmed = seq.length > f ? seq.substring(f) : '';
        final protein = SequenceEngine.translate(trimmed);
        // Longest M...* stretch
        for (final part in protein.split('*')) {
          final mIdx = part.indexOf('M');
          if (mIdx >= 0) {
            final candidate = part.substring(mIdx);
            if (candidate.length > best.length) {
              best = candidate;
              bestFrame = f + 1;
              bestForward = forward;
            }
          }
        }
      }
    }
    if (best.isEmpty) {
      // fallback: forward frame 1, no ORF found
      best = SequenceEngine.translate(dna);
    }
    return {'protein': best, 'frame': bestFrame, 'forward': bestForward};
  }

  void _run(BioSequence seq) {
    String protein;
    String note;
    if (seq.type == SequenceType.protein) {
      protein = seq.sequence;
      note = 'Using sequence directly as protein.';
    } else {
      final dna = seq.sequence.toUpperCase().replaceAll('U', 'T');
      if (_autoFrame) {
        final best = _bestOrfFrame(dna);
        protein = best['protein'] as String;
        note =
            'Auto-detected longest ORF: frame ${best['frame']}, '
            '${best['forward'] ? 'forward' : 'reverse'} strand.';
        setState(() {
          _frame = best['frame'] as int;
          _forwardStrand = best['forward'] as bool;
        });
      } else {
        final strandSeq = _forwardStrand
            ? dna
            : SequenceEngine.reverseComplement(dna);
        final trimmed = strandSeq.length > (_frame - 1)
            ? strandSeq.substring(_frame - 1)
            : '';
        protein = SequenceEngine.translate(trimmed);
        note =
            'Translated frame $_frame, ${_forwardStrand ? 'forward' : 'reverse'} strand.';
      }
    }
    setState(() {
      _result = ProteomicsEngine.analyze(protein);
      _translationNote = note;
    });
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Proteomics Report');
    final comp = r.aminoAcidComposition.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ReportData(
      title: 'Proteomics / Physicochemical Properties Report',
      subtitle: _translationNote ?? '',
      sections: [
        ReportSection(title: 'Protein Sequence', bodyText: r.proteinSequence),
        ReportSection(
          title: 'Physicochemical Properties (ProtParam-style)',
          table: [
            ['Property', 'Value'],
            ['Length', '${r.proteinSequence.length} aa'],
            [
              'Molecular weight',
              '${r.molecularWeightDa.toStringAsFixed(1)} Da',
            ],
            ['Theoretical pI', r.isoelectricPoint.toStringAsFixed(2)],
            ['GRAVY (hydrophobicity)', r.gravyScore.toStringAsFixed(3)],
            ['Aliphatic index', r.aliphaticIndex.toStringAsFixed(1)],
            [
              'Extinction coeff. (280nm)',
              '${r.extinctionCoefficient280.toStringAsFixed(0)} M⁻¹cm⁻¹',
            ],
            [
              'Cysteines / Tryptophans / Tyrosines',
              '${r.numCysteines} / ${r.numTryptophans} / ${r.numTyrosines}',
            ],
          ],
        ),
        ReportSection(
          title: 'Amino Acid Composition',
          table: [
            ['Residue', 'Count', 'Percent'],
            ...comp.map(
              (e) => [
                e.key,
                '${e.value}',
                '${(e.value / r.proteinSequence.length * 100).toStringAsFixed(1)}%',
              ],
            ),
          ],
        ),
        ReportSection(
          title: 'Secondary Structure Propensity (Chou-Fasman, indicative)',
          bodyText:
              'Helix: ${r.secondaryStructurePropensity['Helix']!.toStringAsFixed(2)} · '
              'Sheet: ${r.secondaryStructurePropensity['Sheet']!.toStringAsFixed(2)} · '
              'Turn: ${r.secondaryStructurePropensity['Turn']!.toStringAsFixed(2)}\n'
              '(index > 1 favors that conformation, < 1 disfavors it — classic 1978 scale, indicative only)',
        ),
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
        title: const Text('Proteomics'),
        actions: [
          if (_result != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Proteomics',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedId != null ? [_selectedId!] : [],
            multiple: false,
            onChanged: (v) => setState(() {
              _selectedId = v.isNotEmpty ? v.first : null;
              _result = null;
            }),
            label: 'Select a DNA, RNA or Protein sequence',
          ),
          if (selectedSeq != null &&
              selectedSeq.type != SequenceType.protein) ...[
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoFrame,
              onChanged: (v) => setState(() => _autoFrame = v),
              title: const Text(
                'Auto-detect best reading frame (longest ORF)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (!_autoFrame) ...[
              Row(
                children: [
                  const Text('Frame: ', style: TextStyle(fontSize: 12.5)),
                  DropdownButton<int>(
                    value: _frame,
                    items: const [1, 2, 3]
                        .map(
                          (f) => DropdownMenuItem(value: f, child: Text('$f')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _frame = v ?? 1),
                  ),
                  const SizedBox(width: 20),
                  const Text('Strand: ', style: TextStyle(fontSize: 12.5)),
                  DropdownButton<bool>(
                    value: _forwardStrand,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Forward')),
                      DropdownMenuItem(value: false, child: Text('Reverse')),
                    ],
                    onChanged: (v) =>
                        setState(() => _forwardStrand = v ?? true),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedSeq == null ? null : () => _run(selectedSeq),
              icon: const Icon(Icons.science),
              label: const Text('Analyze Protein Properties'),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null)
            _ProteomicsResultView(
              result: _result!,
              note: _translationNote ?? '',
            ),
        ],
      ),
    );
  }
}

class _ProteomicsResultView extends StatelessWidget {
  final ProteinPropertiesResult result;
  final String note;
  const _ProteomicsResultView({required this.result, required this.note});

  @override
  Widget build(BuildContext context) {
    final comp = result.aminoAcidComposition.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = result.proteinSequence.length.clamp(1, 1 << 30);

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
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _metric(
                  'Length',
                  '${result.proteinSequence.length} aa',
                  AppColors.primaryBlue,
                ),
                _metric(
                  'MW',
                  '${(result.molecularWeightDa / 1000).toStringAsFixed(1)} kDa',
                  AppColors.teal,
                ),
                _metric(
                  'pI',
                  result.isoelectricPoint.toStringAsFixed(2),
                  AppColors.gradProteomics.first,
                ),
                _metric(
                  'GRAVY',
                  result.gravyScore.toStringAsFixed(2),
                  result.gravyScore > 0 ? AppColors.warning : AppColors.success,
                ),
                _metric(
                  'Aliphatic idx.',
                  result.aliphaticIndex.toStringAsFixed(1),
                  AppColors.primaryBlue,
                ),
                _metric(
                  'ε(280nm)',
                  result.extinctionCoefficient280.toStringAsFixed(0),
                  AppColors.textDark,
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
                  'Amino Acid Composition',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: comp
                          .map(
                            (e) => BarChartGroupData(
                              x: e.key.codeUnitAt(0),
                              barRods: [
                                BarChartRodData(
                                  toY: e.value / total * 100,
                                  color: AppColors.gradProteomics.first,
                                  width: 10,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final aa = comp.firstWhere(
                                (e) => e.key.codeUnitAt(0) == value.toInt(),
                                orElse: () => comp.first,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  aa.key,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
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
                  'Secondary Structure Propensity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Text(
                  'Chou-Fasman scale (1978) — indicative only, index > 1 favors that conformation.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                ...result.secondaryStructurePropensity.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (e.value / 2).clamp(0, 1),
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: e.value >= 1
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.value.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
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

  Widget _metric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10.5, color: color)),
        ],
      ),
    );
  }
}
