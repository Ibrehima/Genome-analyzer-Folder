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

/// Standalone trimming module: adapter / quality / length / fixed-length
/// hard trimming on any sequences from the active project. Independent
/// from the Raw Sequencing pipeline so it can be re-run at any time on any
/// data, including already-imported sequences.
class TrimmingScreen extends StatefulWidget {
  const TrimmingScreen({super.key});
  @override
  State<TrimmingScreen> createState() => _TrimmingScreenState();
}

class _TrimmingScreenState extends State<TrimmingScreen> {
  List<String> _selectedIds = [];
  final _adapterCtrl = TextEditingController(text: 'AGATCGGAAGAGC');
  bool _useAdapter = false;
  bool _useQuality = true;
  int _slidingWindow = 4;
  int _qualityThreshold = 20;
  int _minLength = 20;
  int _hardStart = 0;
  int _hardEnd = 0;
  bool _running = false;
  TrimBatchResult? _result;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .whereType<BioSequence>()
        .toList();
    if (seqs.isEmpty) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final result = DemuxTrimEngine.trim(
      seqs,
      adapter: _useAdapter ? _adapterCtrl.text.trim() : null,
      qualityTrim: _useQuality,
      slidingWindow: _slidingWindow,
      qualityThreshold: _qualityThreshold,
      minLength: _minLength,
      hardTrimStart: _hardStart,
      hardTrimEnd: _hardEnd,
    );
    setState(() {
      _result = result;
      _running = false;
    });
  }

  Future<void> _addKeptToLibrary() async {
    final r = _result;
    if (r == null) return;
    final appState = context.read<AppState>();
    await appState.addSequences(r.keptSequences, projectId: appState.activeProjectId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${r.keptSequences.length} trimmed sequence(s) to the library.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  ReportData _buildReport() {
    final r = _result;
    if (r == null) return ReportData(title: 'Trimming Report');
    return ReportData(
      title: 'Trimming Report',
      subtitle: '${r.keptSequences.length}/${r.results.length} reads kept',
      sections: [
        ReportSection(
          title: 'Summary',
          table: [
            ['Metric', 'Value'],
            ['Reads processed', '${r.results.length}'],
            ['Kept', '${r.keptSequences.length}'],
            ['Discarded', '${r.discardedCount}'],
            ['Total bases trimmed', '${r.totalBasesTrimmed}'],
          ],
        ),
        ReportSection(title: 'Pipeline Steps', bullets: r.stepsLog),
        ReportSection(
          title: 'Per-read Detail',
          table: [
            ['Read', 'Original length', 'Trimmed (start/end)', 'Kept?', 'Reason'],
            ...r.results
                .take(100)
                .map(
                  (res) => [
                    res.trimmedSequence.name,
                    '${res.originalLength}',
                    '${res.trimmedFromStart}/${res.trimmedFromEnd}',
                    res.discarded ? 'No' : 'Yes',
                    res.reason,
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
        title: const Text('Trimming'),
        actions: [
          const ProjectSwitcher(),
          if (_result != null)
            ExportMenuButton(reportBuilder: _buildReport, moduleType: 'Trimming'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gradTrim.first.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFD84315), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trim adapters, low-quality ends and short/fixed-length '
                    'regions from any sequence in this project — standalone '
                    'from the Raw Sequencing pipeline, so it can be rerun '
                    'anytime on any data.',
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
            label: 'Select reads to trim',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useAdapter,
            onChanged: (v) => setState(() => _useAdapter = v),
            title: const Text(
              'Adapter trimming',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (_useAdapter)
            TextField(
              controller: _adapterCtrl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: const InputDecoration(labelText: 'Adapter sequence'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useQuality,
            onChanged: (v) => setState(() => _useQuality = v),
            title: const Text(
              'Quality trimming (sliding window)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (_useQuality)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Window (bp)'),
                    controller: TextEditingController(text: '$_slidingWindow'),
                    onChanged: (v) => _slidingWindow = int.tryParse(v) ?? _slidingWindow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quality threshold'),
                    controller: TextEditingController(text: '$_qualityThreshold'),
                    onChanged: (v) => _qualityThreshold = int.tryParse(v) ?? _qualityThreshold,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hard-trim start (bp)'),
                  controller: TextEditingController(text: '$_hardStart'),
                  onChanged: (v) => _hardStart = int.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hard-trim end (bp)'),
                  controller: TextEditingController(text: '$_hardEnd'),
                  onChanged: (v) => _hardEnd = int.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum final length (bp)'),
            controller: TextEditingController(text: '$_minLength'),
            onChanged: (v) => _minLength = int.tryParse(v) ?? _minLength,
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
                  : const Icon(Icons.content_cut_rounded),
              label: Text(_running ? 'Trimming...' : 'Run Trimming'),
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
                    Chip(label: Text('${_result!.keptSequences.length} kept')),
                    Chip(label: Text('${_result!.discardedCount} discarded')),
                    Chip(label: Text('${_result!.totalBasesTrimmed} bp trimmed')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _addKeptToLibrary,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Add kept sequences to Library'),
            ),
            ..._result!.results
                .take(50)
                .map(
                  (res) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        res.discarded ? Icons.remove_circle_outline : Icons.check_circle_outline,
                        color: res.discarded ? AppColors.danger : AppColors.success,
                        size: 20,
                      ),
                      title: Text(res.trimmedSequence.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${res.originalLength} -> ${res.trimmedSequence.length} bp'
                        '${res.reason.isNotEmpty ? " · ${res.reason}" : ""}',
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
