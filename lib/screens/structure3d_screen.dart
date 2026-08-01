import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../engines/structure3d_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';
import '../widgets/structure3d_view.dart';

/// 3D visualization + stability analysis module.
///
/// HONESTY NOTE (also shown in-app): this generates an idealized / schematic
/// 3D model (a standard B-DNA double helix for DNA/RNA, or a ribbon whose
/// local shape follows a simplified per-residue secondary-structure guess
/// for proteins). It is NOT a structure-prediction tool (no AlphaFold, no
/// molecular dynamics, no energy minimization) — it is meant for visual /
/// educational intuition and for the accompanying composition-based
/// stability indicators only.
class Structure3DScreen extends StatefulWidget {
  const Structure3DScreen({super.key});

  @override
  State<Structure3DScreen> createState() => _Structure3DScreenState();
}

class _Structure3DScreenState extends State<Structure3DScreen> {
  String? _selectedId;
  Structure3DResult? _structure;
  StabilityReport? _stability;
  String? _note;

  void _generate(BioSequence seq) {
    Structure3DResult structure;
    String note;
    if (seq.type == SequenceType.protein) {
      structure = Structure3DEngine.proteinBackbone(seq.sequence);
      note =
          'Protein ribbon model (${seq.length} aa${seq.length > 150 ? ", first 150 shown" : ""}) '
          '— local shape follows a simplified per-residue Chou-Fasman-based '
          'secondary-structure guess, not a folded 3D prediction.';
    } else {
      structure = Structure3DEngine.dnaHelix(seq.sequence);
      note =
          'Idealized B-form double-helix model (${seq.length} bp${seq.length > 120 ? ", first 120 shown" : ""}) '
          'using standard helical geometry — not derived from this specific sequence\'s real structure.';
    }
    setState(() {
      _structure = structure;
      _stability = Structure3DEngine.buildStabilityReport(seq);
      _note = note;
    });
  }

  ReportData _buildReport() {
    final s = _stability;
    final st = _structure;
    if (s == null || st == null) {
      return ReportData(title: '3D Structure & Stability Report');
    }
    return ReportData(
      title: '3D Structure & Stability Report',
      subtitle: s.sequenceName,
      sections: [
        ReportSection(
          title: 'Model Summary',
          bodyText:
              'Sequence: ${s.sequenceName}\n'
              'Type: ${s.type.label}\n'
              'Model kind: ${st.modelKind == "dna_helix" ? "Idealized B-DNA double helix" : "Schematic protein backbone ribbon"}\n'
              'Atoms rendered: ${st.atoms.length}\n\n'
              '$_note',
        ),
        ReportSection(
          title: 'Stability Assessment',
          bodyText:
              'Overall: ${s.overallAssessment}'
              '${s.estimatedTm != null ? "\nEstimated Tm: ${s.estimatedTm!.toStringAsFixed(1)} °C" : ""}'
              '${s.gravy != null ? "\nGRAVY: ${s.gravy!.toStringAsFixed(2)}" : ""}'
              '${s.aliphaticIndex != null ? "\nAliphatic index: ${s.aliphaticIndex!.toStringAsFixed(1)}" : ""}',
          bullets: s.observations,
        ),
        ReportSection(
          title: 'Disclaimer',
          bodyText:
              'This 3D model is idealized/schematic and this stability analysis is '
              'based on sequence-composition heuristics (GC content / empirical Tm '
              'formula for nucleic acids; GRAVY and aliphatic index for proteins). '
              'It does NOT replace structure-prediction tools (e.g. AlphaFold), '
              'molecular dynamics simulation, or experimental thermal-stability assays.',
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
        title: const Text('3D Structure & Stability'),
        actions: [
          if (_stability != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: '3D Structure',
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
              color: AppColors.gradStructure3D.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.gradStructure3D.first.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.gradStructure3D.first,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Schematic / idealized visualization for intuition only — not a '
                    'structure-prediction or molecular-dynamics tool. Stability metrics '
                    'are derived from sequence composition (GC%, GRAVY, aliphatic index).',
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
              _structure = null;
              _stability = null;
            }),
            label: 'Select a DNA, RNA or Protein sequence',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedSeq == null
                  ? null
                  : () => _generate(selectedSeq),
              icon: const Icon(Icons.view_in_ar_rounded),
              label: const Text('Generate 3D Model'),
            ),
          ),
          const SizedBox(height: 20),
          if (_structure != null && _stability != null)
            _Structure3DResultView(
              structure: _structure!,
              stability: _stability!,
              note: _note ?? '',
            ),
        ],
      ),
    );
  }
}

class _Structure3DResultView extends StatelessWidget {
  final Structure3DResult structure;
  final StabilityReport stability;
  final String note;

  const _Structure3DResultView({
    required this.structure,
    required this.stability,
    required this.note,
  });

  Color _assessmentColor(String assessment) {
    final lower = assessment.toLowerCase();
    if (lower.contains('higher') || lower.contains('stable (gc')) {
      return AppColors.success;
    }
    if (lower.contains('lower')) return AppColors.danger;
    if (lower.contains('moderate')) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
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
        Structure3DView(structure: structure),
        const SizedBox(height: 8),
        const Text(
          'Drag to rotate · pinch/scroll to zoom',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendDot('Helix', const Color(0xFF4FC3F7)),
                _legendDot('Sheet', const Color(0xFFFFB74D)),
                _legendDot('Coil', const Color(0xFF81C784)),
                _legendDot('Base pair / strand', const Color(0xFFB39DDB)),
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
                Row(
                  children: [
                    const Text(
                      'Stability Assessment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _assessmentColor(
                          stability.overallAssessment,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stability.overallAssessment,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _assessmentColor(stability.overallAssessment),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (stability.estimatedTm != null)
                      _metric(
                        'Est. Tm',
                        '${stability.estimatedTm!.toStringAsFixed(1)} °C',
                        AppColors.gradStructure3D.first,
                      ),
                    if (stability.gravy != null)
                      _metric(
                        'GRAVY',
                        stability.gravy!.toStringAsFixed(2),
                        AppColors.primaryBlue,
                      ),
                    if (stability.aliphaticIndex != null)
                      _metric(
                        'Aliphatic idx.',
                        stability.aliphaticIndex!.toStringAsFixed(1),
                        AppColors.teal,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Observations',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...stability.observations.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
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
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
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
