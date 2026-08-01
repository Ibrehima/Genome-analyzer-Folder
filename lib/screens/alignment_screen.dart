import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../models/bio_sequence.dart';
import '../engines/alignment_engine.dart';
import '../engines/statistics_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/colored_sequence_view.dart';
import '../widgets/export_menu_button.dart';

class AlignmentScreen extends StatefulWidget {
  const AlignmentScreen({super.key});

  @override
  State<AlignmentScreen> createState() => _AlignmentScreenState();
}

class _AlignmentScreenState extends State<AlignmentScreen> {
  List<String> _selectedIds = [];
  AlignmentMode _mode = AlignmentMode.global;
  bool _running = false;

  PairwiseAlignmentResult? _pairwise;
  MultipleAlignmentResult? _msa;
  List<String> _usedNames = [];

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .whereType<BioSequence>()
        .toList();
    if (seqs.length < 2) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));

    if (seqs.length == 2) {
      final result = _mode == AlignmentMode.global
          ? AlignmentEngine.globalAlign(seqs[0].sequence, seqs[1].sequence)
          : AlignmentEngine.localAlign(seqs[0].sequence, seqs[1].sequence);
      setState(() {
        _pairwise = result;
        _msa = null;
        _usedNames = [seqs[0].name, seqs[1].name];
        _running = false;
      });
    } else {
      final result = AlignmentEngine.multipleAlign(
        seqs.map((s) => s.name).toList(),
        seqs.map((s) => s.sequence).toList(),
      );
      setState(() {
        _msa = result;
        _pairwise = null;
        _usedNames = seqs.map((s) => s.name).toList();
        _running = false;
      });
    }
  }

  ReportData _buildReport() {
    if (_pairwise != null) {
      final p = _pairwise!;
      final variants = StatisticsEngine.callVariants(
        p.alignedSeqA,
        p.alignedSeqB,
      );
      return ReportData(
        title: 'Pairwise Alignment Report',
        subtitle:
            '${_usedNames.join(" vs ")} · ${p.mode == AlignmentMode.global ? "Global (Needleman-Wunsch)" : "Local (Smith-Waterman)"}',
        sections: [
          ReportSection(
            title: 'Summary',
            table: [
              ['Metric', 'Value'],
              ['Alignment score', '${p.score}'],
              ['Identity', '${p.identityPercent.toStringAsFixed(2)}%'],
              ['Similarity', '${p.similarityPercent.toStringAsFixed(2)}%'],
              ['Gaps', '${p.gaps}'],
              ['Aligned length', '${p.alignedSeqA.length}'],
            ],
          ),
          ReportSection(
            title: 'Aligned Sequences',
            bodyText:
                '${_usedNames.isNotEmpty ? _usedNames[0] : "Seq A"}:\n${p.alignedSeqA}\n\n'
                '${_usedNames.length > 1 ? _usedNames[1] : "Seq B"}:\n${p.alignedSeqB}',
          ),
          ReportSection(
            title: 'Detected Variants (${variants.length})',
            table: [
              ['Position', 'Reference', 'Query', 'Type'],
              ...variants
                  .take(50)
                  .map(
                    (v) => ['${v.position + 1}', v.refBase, v.altBase, v.type],
                  ),
            ],
          ),
        ],
      );
    } else if (_msa != null) {
      final m = _msa!;
      return ReportData(
        title: 'Multiple Sequence Alignment Report',
        subtitle:
            '${m.names.length} sequences · Average identity ${m.averageIdentity.toStringAsFixed(1)}%',
        sections: [
          ReportSection(
            title: 'Summary',
            table: [
              ['Metric', 'Value'],
              ['Sequences aligned', '${m.names.length}'],
              ['Alignment length', '${m.consensusLength}'],
              [
                'Average pairwise identity',
                '${m.averageIdentity.toStringAsFixed(2)}%',
              ],
            ],
          ),
          ReportSection(
            title: 'Aligned Sequences',
            bodyText: List.generate(
              m.names.length,
              (i) => '${m.names[i]}:\n${m.alignedSequences[i]}',
            ).join('\n\n'),
          ),
          ReportSection(
            title: 'Consensus Sequence',
            bodyText: m.consensusSequence,
          ),
        ],
      );
    }
    return ReportData(title: 'Alignment Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Alignment'),
        actions: [
          if (_pairwise != null || _msa != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Sequence Alignment',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SequenceSelector(
            selectedIds: _selectedIds,
            multiple: true,
            onChanged: (v) => setState(() => _selectedIds = v),
            label:
                'Select 2+ sequences (2 = pairwise, 3+ = multiple alignment)',
          ),
          const SizedBox(height: 14),
          if (_selectedIds.length == 2) ...[
            const Text(
              'Alignment mode',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AlignmentMode>(
              segments: const [
                ButtonSegment(
                  value: AlignmentMode.global,
                  label: Text('Global (NW)'),
                  icon: Icon(Icons.compare_arrows),
                ),
                ButtonSegment(
                  value: AlignmentMode.local,
                  label: Text('Local (SW)'),
                  icon: Icon(Icons.center_focus_strong),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedIds.length < 2 || _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.align_horizontal_left_rounded),
              label: Text(_running ? 'Aligning...' : 'Run Alignment'),
            ),
          ),
          const SizedBox(height: 20),
          if (_pairwise != null)
            _PairwiseResultView(result: _pairwise!, names: _usedNames),
          if (_msa != null) _MsaResultView(result: _msa!),
        ],
      ),
    );
  }
}

class _PairwiseResultView extends StatelessWidget {
  final PairwiseAlignmentResult result;
  final List<String> names;
  const _PairwiseResultView({required this.result, required this.names});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _statPill('Score', '${result.score}', AppColors.primaryBlue),
                _statPill(
                  'Identity',
                  '${result.identityPercent.toStringAsFixed(1)}%',
                  AppColors.success,
                ),
                _statPill(
                  'Similarity',
                  '${result.similarityPercent.toStringAsFixed(1)}%',
                  AppColors.teal,
                ),
                _statPill('Gaps', '${result.gaps}', AppColors.warning),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              names.isNotEmpty ? names[0] : 'Sequence A',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            ColoredSequenceView(sequence: result.alignedSeqA),
            const SizedBox(height: 8),
            Text(
              names.length > 1 ? names[1] : 'Sequence B',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            ColoredSequenceView(sequence: result.alignedSeqB),
            const SizedBox(height: 10),
            const SequenceLegend(),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 15,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10.5, color: color)),
        ],
      ),
    );
  }
}

class _MsaResultView extends StatelessWidget {
  final MultipleAlignmentResult result;
  const _MsaResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average identity: ${result.averageIdentity.toStringAsFixed(1)}% · Length: ${result.consensusLength}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              result.names.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.names[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    ColoredSequenceView(
                      sequence: result.alignedSequences[i],
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            const Text(
              'Consensus',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            ColoredSequenceView(
              sequence: result.consensusSequence,
              fontSize: 12,
            ),
            const SizedBox(height: 8),
            const SequenceLegend(),
          ],
        ),
      ),
    );
  }
}
