import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import '../engines/mutation_engine.dart';
import '../engines/sequence_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';
import '../widgets/genome_map_view.dart';
import '../widgets/project_switcher.dart';

/// Mutation / variant detection & characterization portal: compares a
/// reference sequence against a query, detects substitutions, insertions
/// and deletions, classifies them (SNP vs indel, transition/transversion,
/// and — if a coding frame is given — synonymous/missense/nonsense/
/// frameshift), and renders the results on an annotated schematic map
/// (circular or linear) with numbered positions.
class MutationDetectionScreen extends StatefulWidget {
  const MutationDetectionScreen({super.key});
  @override
  State<MutationDetectionScreen> createState() => _MutationDetectionScreenState();
}

class _MutationDetectionScreenState extends State<MutationDetectionScreen> {
  String? _refId;
  String? _queryId;
  bool _useCodingFrame = false;
  int _frameStart = 1;
  bool _running = false;
  MutationAnalysisResult? _result;
  GenomeMapShape _shape = GenomeMapShape.linear;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final ref = _refId != null ? appState.getSequenceById(_refId!) : null;
    final query = _queryId != null ? appState.getSequenceById(_queryId!) : null;
    if (ref == null || query == null) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final result = MutationEngine.analyze(
      ref.sequence,
      query.sequence,
      codingFrameStart: _useCodingFrame ? (_frameStart - 1).clamp(0, 1 << 30) : null,
    );
    setState(() {
      _result = result;
      _running = false;
    });
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Mutation Detection Report');
    return ReportData(
      title: 'Mutation Detection & Characterization Report',
      subtitle: '${r.mutations.length} mutation(s) found',
      sections: [
        ReportSection(
          title: 'Summary',
          table: [
            ['Metric', 'Value'],
            ['Reference length', '${r.referenceLength} bp'],
            ['Query length', '${r.queryLength} bp'],
            ['Total mutations', '${r.mutations.length}'],
            ['Substitutions (SNP/MNP)', '${r.snpCount}'],
            ['  - Transitions', '${r.transitionCount}'],
            ['  - Transversions', '${r.transversionCount}'],
            ['Insertions', '${r.insertionCount}'],
            ['Deletions', '${r.deletionCount}'],
          ],
        ),
        if (r.notes.isNotEmpty) ReportSection(title: 'Notes', bodyText: r.notes.join('\n\n')),
        ReportSection(
          title: 'Mutation Calls',
          table: [
            ['Notation', 'Type', 'Position (ref)', 'Impact', 'Protein change'],
            ...r.mutations.map(
              (m) => [
                m.notation,
                m.type.shortLabel,
                '${m.refStart + 1}-${m.refEnd}',
                m.impact.label,
                m.proteinNotation,
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    GenomeMapData? mapData;
    if (r != null && _refId != null) {
      final ref = context.read<AppState>().getSequenceById(_refId!);
      if (ref != null) {
        mapData = GenomeMapData(
          sequenceName: ref.name,
          sequenceLength: ref.length,
          gcContent: SequenceEngine.gcContent(ref.sequence),
          features: r.toMapFeatures(),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutation Detection'),
        actions: [
          const ProjectSwitcher(),
          if (_result != null)
            ExportMenuButton(reportBuilder: _buildReport, moduleType: 'Mutation Detection'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gradMutation.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB71C1C), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select a reference and a query sequence to detect and '
                    'characterize every substitution, insertion and deletion '
                    'between them (transition/transversion, and — with a coding '
                    'frame — synonymous/missense/nonsense/frameshift), then view '
                    'them on an annotated, numbered schematic map.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SequenceSelector(
            selectedIds: _refId != null ? [_refId!] : [],
            onChanged: (v) => setState(() => _refId = v.isNotEmpty ? v.first : null),
            label: 'Reference sequence',
          ),
          const SizedBox(height: 14),
          SequenceSelector(
            selectedIds: _queryId != null ? [_queryId!] : [],
            onChanged: (v) => setState(() => _queryId = v.isNotEmpty ? v.first : null),
            label: 'Query sequence',
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useCodingFrame,
            onChanged: (v) => setState(() => _useCodingFrame = v),
            title: const Text(
              'Classify protein impact (requires coding frame)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (_useCodingFrame)
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reading frame start (1-based position on reference)',
              ),
              controller: TextEditingController(text: '$_frameStart'),
              onChanged: (v) => _frameStart = int.tryParse(v) ?? 1,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_refId == null || _queryId == null || _running) ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bug_report_rounded),
              label: Text(_running ? 'Analyzing...' : 'Detect Mutations'),
            ),
          ),
          const SizedBox(height: 20),
          if (r != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${r.mutations.length} mutations')),
                    Chip(label: Text('${r.snpCount} SNP/MNP')),
                    Chip(label: Text('${r.insertionCount} insertions')),
                    Chip(label: Text('${r.deletionCount} deletions')),
                    Chip(label: Text('${r.transitionCount} transitions')),
                    Chip(label: Text('${r.transversionCount} transversions')),
                  ],
                ),
              ),
            ),
            if (r.notes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFEF6C00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.notes.join('\n\n'), style: const TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (mapData != null && mapData.features.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'Map shape:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Wrap(
                    spacing: 8,
                    children: GenomeMapShape.values
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s.label),
                            selected: _shape == s,
                            onSelected: (_) => setState(() => _shape = s),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: GenomeMapView(data: mapData, shape: _shape),
                ),
              ),
              const SizedBox(height: 12),
              const GenomeMapLegend(),
              const SizedBox(height: 20),
            ],
            const Text(
              'Mutation Calls',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...r.mutations
                .take(100)
                .map(
                  (m) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.gradMutation.first.withValues(alpha: 0.15),
                        child: Text(
                          m.type.shortLabel,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        m.notation,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${m.impact.label}${m.proteinNotation.isNotEmpty ? " · ${m.proteinNotation}" : ""}'
                        '${m.type == MutationType.substitution ? (m.isTransition ? " · transition" : " · transversion") : ""}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class BioSequenceRefHelper {
  static BioSequence? byId(AppState state, String? id) =>
      id != null ? state.getSequenceById(id) : null;
}
