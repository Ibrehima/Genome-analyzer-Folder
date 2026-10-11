import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import '../engines/contig_assembly_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';
import '../widgets/project_switcher.dart';

/// Contig assembly module: merges overlapping reads from the active
/// project (e.g. Sanger/amplicon fragments, overlapping PCR reads) into
/// consensus contigs using a greedy Overlap-Layout-Consensus approach.
class ContigAssemblyScreen extends StatefulWidget {
  const ContigAssemblyScreen({super.key});

  @override
  State<ContigAssemblyScreen> createState() => _ContigAssemblyScreenState();
}

class _ContigAssemblyScreenState extends State<ContigAssemblyScreen> {
  List<String> _selectedIds = [];
  int _minOverlap = 20;
  double _minIdentity = 90;
  bool _running = false;
  AssemblyResult? _result;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .whereType<BioSequence>()
        .toList();
    if (seqs.length < 2) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final result = ContigAssemblyEngine.assemble(
      seqs,
      minOverlap: _minOverlap,
      minIdentity: _minIdentity,
    );
    setState(() {
      _result = result;
      _running = false;
    });
  }

  Future<void> _addContigsToLibrary() async {
    final r = _result;
    if (r == null) return;
    final appState = context.read<AppState>();
    final newSeqs = r.contigs
        .asMap()
        .entries
        .map(
          (e) => BioSequence(
            name: 'contig_${e.key + 1}',
            description:
                '${e.value.reads.length} read(s) merged · mean coverage '
                '${e.value.meanCoverage.toStringAsFixed(1)}x',
            type: SequenceType.dna,
            sequence: e.value.consensusSequence,
            source: 'contig_assembly',
            tags: const ['contig'],
          ),
        )
        .toList();
    await appState.addSequences(newSeqs, projectId: appState.activeProjectId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newSeqs.length} contig(s) to the library.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Contig Assembly Report');
    return ReportData(
      title: 'Contig Assembly Report',
      subtitle: '${r.contigs.length} contig(s) from ${r.inputReadCount} read(s)',
      sections: [
        ReportSection(
          title: 'Summary',
          table: [
            ['Metric', 'Value'],
            ['Input reads', '${r.inputReadCount}'],
            ['Contigs produced', '${r.contigs.length}'],
            ['Total assembled bases', '${r.totalAssembledBases}'],
            ['N50', '${r.n50} bp'],
            ['Unassembled reads', '${r.unassembledReadNames.length}'],
            ['Computed in', '${r.elapsedMs.toStringAsFixed(1)} ms'],
          ],
        ),
        ReportSection(title: 'Pipeline Steps', bullets: r.stepsLog),
        if (r.warnings.isNotEmpty) ReportSection(title: 'Warnings', bullets: r.warnings),
        ReportSection(
          title: 'Contigs',
          table: [
            ['Contig', 'Length (bp)', 'Reads merged', 'Mean coverage'],
            ...r.contigs.asMap().entries.map(
              (e) => [
                'contig_${e.key + 1}',
                '${e.value.length}',
                '${e.value.reads.length}',
                '${e.value.meanCoverage.toStringAsFixed(1)}x',
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contig Assembly'),
        actions: [
          const ProjectSwitcher(),
          if (_result != null)
            ExportMenuButton(reportBuilder: _buildReport, moduleType: 'Contig Assembly'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gradAssembly.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1A237E), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select 2+ overlapping reads from this project (e.g. Sanger '
                    'fragments covering the same region) to merge into contigs '
                    'via a greedy overlap-layout-consensus approach. Reads with '
                    'no qualifying overlap are kept as unmerged singletons.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SequenceSelector(
            selectedIds: _selectedIds,
            multiple: true,
            onChanged: (v) => setState(() => _selectedIds = v),
            label: 'Select reads to assemble',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min overlap (bp)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _minOverlap.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: '$_minOverlap',
                      onChanged: (v) => setState(() => _minOverlap = v.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min identity (%)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _minIdentity,
                      min: 70,
                      max: 100,
                      divisions: 30,
                      label: '${_minIdentity.toStringAsFixed(0)}%',
                      onChanged: (v) => setState(() => _minIdentity = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.length < 2 || _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.merge_type_rounded),
              label: Text(_running ? 'Assembling...' : 'Assemble Contigs'),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null)
            _AssemblyResultView(result: _result!, onAddToLibrary: _addContigsToLibrary),
        ],
      ),
    );
  }
}

class _AssemblyResultView extends StatelessWidget {
  final AssemblyResult result;
  final VoidCallback onAddToLibrary;
  const _AssemblyResultView({required this.result, required this.onAddToLibrary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${result.contigs.length} contig(s)')),
                    Chip(label: Text('N50 = ${result.n50} bp')),
                    Chip(label: Text('${result.totalAssembledBases} bp assembled')),
                    Chip(label: Text('${result.elapsedMs.toStringAsFixed(1)} ms')),
                  ],
                ),
                const SizedBox(height: 12),
                ...result.stepsLog.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 15, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 12.5))),
                      ],
                    ),
                  ),
                ),
                if (result.warnings.isNotEmpty) ...[
                  const Divider(),
                  ...result.warnings.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(w, style: const TextStyle(fontSize: 12.5))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (result.contigs.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Contigs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              TextButton.icon(
                onPressed: onAddToLibrary,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Add all to Library'),
              ),
            ],
          ),
          ...result.contigs.asMap().entries.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: AppColors.gradAssembly.first.withValues(alpha: 0.15),
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  'contig_${e.key + 1} — ${e.value.length} bp',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${e.value.reads.length} read(s) merged · mean coverage ${e.value.meanCoverage.toStringAsFixed(1)}x',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
