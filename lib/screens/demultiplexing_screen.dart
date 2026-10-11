import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import '../engines/demux_trim_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';
import '../widgets/project_switcher.dart';

/// Standalone demultiplexing module: splits any selected reads from the
/// active project into per-sample buckets using a barcode sheet, in-line
/// 5' matching (Hamming distance tolerant). Independent from the Raw
/// Sequencing pipeline so it can be run on any sequences already imported.
class DemultiplexingScreen extends StatefulWidget {
  const DemultiplexingScreen({super.key});
  @override
  State<DemultiplexingScreen> createState() => _DemultiplexingScreenState();
}

class _DemultiplexingScreenState extends State<DemultiplexingScreen> {
  List<String> _selectedIds = [];
  final _barcodeCtrl = TextEditingController(text: 'SampleA,ACGTAC\nSampleB,TGCATG');
  int _maxMismatches = 1;
  bool _running = false;
  DemuxBatchResult? _result;

  List<DemuxSample> _parseBarcodes() {
    final list = <DemuxSample>[];
    for (final line in _barcodeCtrl.text.split(RegExp(r'\r?\n'))) {
      final parts = line.split(',');
      if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
        list.add(DemuxSample(name: parts[0].trim(), barcode: parts[1].trim().toUpperCase()));
      }
    }
    return list;
  }

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .whereType<BioSequence>()
        .toList();
    final barcodes = _parseBarcodes();
    if (seqs.isEmpty || barcodes.isEmpty) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final result = DemuxTrimEngine.demultiplex(seqs, barcodes, maxMismatches: _maxMismatches);
    setState(() {
      _result = result;
      _running = false;
    });
  }

  Future<void> _addSampleToLibrary(DemuxResultEntry e) async {
    final appState = context.read<AppState>();
    await appState.addSequences(e.reads, projectId: appState.activeProjectId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${e.reads.length} read(s) to the library.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Demultiplexing Report');
    return ReportData(
      title: 'Demultiplexing Report',
      subtitle: '${r.assignedReads}/${r.totalReads} reads assigned',
      sections: [
        ReportSection(
          title: 'Summary',
          table: [
            ['Metric', 'Value'],
            ['Total reads', '${r.totalReads}'],
            ['Assigned', '${r.assignedReads}'],
            ['Unassigned', '${r.unassignedReads}'],
          ],
        ),
        ReportSection(title: 'Pipeline Steps', bullets: r.stepsLog),
        ReportSection(
          title: 'Per-sample Counts',
          table: [
            ['Sample', 'Reads'],
            ...r.perSample.map(
              (e) => [e.sampleName.isEmpty ? 'Unassigned' : e.sampleName, '${e.reads.length}'],
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
        title: const Text('Demultiplexing'),
        actions: [
          const ProjectSwitcher(),
          if (_result != null)
            ExportMenuButton(reportBuilder: _buildReport, moduleType: 'Demultiplexing'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gradDemux.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF00695C), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Split pooled reads into per-sample files using a barcode '
                    'sheet (in-line 5\' match, tolerant to a few mismatches). '
                    'Works on any sequences from this project.',
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
            label: 'Select reads to demultiplex',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcodeCtrl,
            maxLines: 5,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Sample sheet (name,barcode) — one per line',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Max mismatches:', style: TextStyle(fontSize: 12.5)),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _maxMismatches,
                items: [0, 1, 2].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                onChanged: (v) => setState(() => _maxMismatches = v ?? 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.isEmpty || _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.call_split_rounded),
              label: Text(_running ? 'Processing...' : 'Run Demultiplexing'),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${_result!.totalReads} total')),
                    Chip(label: Text('${_result!.assignedReads} assigned')),
                    Chip(label: Text('${_result!.unassignedReads} unassigned')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ..._result!.perSample.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    e.sampleName.isEmpty ? Icons.help_outline : Icons.folder_shared_outlined,
                    color: e.sampleName.isEmpty ? AppColors.warning : AppColors.primaryBlue,
                  ),
                  title: Text(
                    e.sampleName.isEmpty ? 'Unassigned' : e.sampleName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${e.reads.length} read(s)', style: const TextStyle(fontSize: 11)),
                  trailing: e.reads.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.playlist_add, size: 20),
                          tooltip: 'Add to Library',
                          onPressed: () => _addSampleToLibrary(e),
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
