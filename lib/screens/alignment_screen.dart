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
  MsaMethod _msaMethod = MsaMethod.centerStar;
  bool _running = false;
  bool _showAdvanced = false;

  // Advanced scoring/algorithm options.
  SubstitutionMatrixType _matrixType = SubstitutionMatrixType.simple;
  GapModel _gapModel = GapModel.linear;
  int _matchScore = AlignmentEngine.matchScore;
  int _mismatchScore = AlignmentEngine.mismatchScore;
  int _gapPenalty = AlignmentEngine.gapPenalty;
  int _gapOpenPenalty = -8;
  int _gapExtendPenalty = -1;
  bool _autoBand = true;

  PairwiseAlignmentResult? _pairwise;
  MultipleAlignmentResult? _msa;
  List<String> _usedNames = [];
  List<BioSequence> _usedSeqs = [];

  AlignmentOptions get _options => AlignmentOptions(
    matrixType: _matrixType,
    matchScore: _matchScore,
    mismatchScore: _mismatchScore,
    gapModel: _gapModel,
    gapPenalty: _gapPenalty,
    gapOpenPenalty: _gapOpenPenalty,
    gapExtendPenalty: _gapExtendPenalty,
    autoBand: _autoBand,
  );

  /// Detects protein sequences among the current selection and switches the
  /// substitution scheme to BLOSUM62 automatically (users can still change
  /// it manually afterwards).
  void _autoSuggestMatrix(List<BioSequence> seqs) {
    final hasProtein = seqs.any((s) => s.type == SequenceType.protein);
    if (hasProtein && _matrixType == SubstitutionMatrixType.simple) {
      _matrixType = SubstitutionMatrixType.blosum62;
    } else if (!hasProtein && _matrixType.isProteinMatrix) {
      _matrixType = SubstitutionMatrixType.simple;
    }
  }

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .whereType<BioSequence>()
        .toList();
    if (seqs.length < 2) return;
    setState(() {
      _running = true;
      _autoSuggestMatrix(seqs);
    });
    await Future.delayed(const Duration(milliseconds: 50));

    if (seqs.length == 2) {
      final result = AlignmentEngine.align(
        seqs[0].sequence,
        seqs[1].sequence,
        _mode,
        options: _options,
      );
      setState(() {
        _pairwise = result;
        _msa = null;
        _usedNames = [seqs[0].name, seqs[1].name];
        _usedSeqs = seqs;
        _running = false;
      });
    } else {
      final result = AlignmentEngine.multipleAlign(
        seqs.map((s) => s.name).toList(),
        seqs.map((s) => s.sequence).toList(),
        options: _options,
        method: _msaMethod,
      );
      setState(() {
        _msa = result;
        _pairwise = null;
        _usedNames = seqs.map((s) => s.name).toList();
        _usedSeqs = seqs;
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
            '${_usedNames.join(" vs ")} · ${p.mode.label} · '
            '${p.matrixType.label} · ${p.gapModel.label}',
        sections: [
          ReportSection(
            title: 'Summary',
            table: [
              ['Metric', 'Value'],
              ['Algorithm', p.mode.label],
              ['Substitution scheme', p.matrixType.label],
              ['Gap model', p.gapModel.label],
              ['Alignment score', '${p.score}'],
              ['Identity', '${p.identityPercent.toStringAsFixed(2)}%'],
              ['Similarity', '${p.similarityPercent.toStringAsFixed(2)}%'],
              ['Gaps (bases)', '${p.gaps}'],
              ['Gap openings', '${p.gapOpenings}'],
              ['Aligned length', '${p.alignedSeqA.length}'],
              [
                'Computed in',
                p.banded
                    ? '${p.elapsedMs.toStringAsFixed(1)} ms (banded)'
                    : '${p.elapsedMs.toStringAsFixed(1)} ms',
              ],
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
            '${m.names.length} sequences · ${m.method.label} · '
            'Average identity ${m.averageIdentity.toStringAsFixed(1)}%',
        sections: [
          ReportSection(
            title: 'Summary',
            table: [
              ['Metric', 'Value'],
              ['Method', m.method.label],
              ['Sequences aligned', '${m.names.length}'],
              ['Alignment length', '${m.consensusLength}'],
              [
                'Average pairwise identity',
                '${m.averageIdentity.toStringAsFixed(2)}%',
              ],
              ['Computed in', '${m.elapsedMs.toStringAsFixed(1)} ms'],
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
    final isProteinSelection = _usedSeqs.isNotEmpty
        ? _usedSeqs.any((s) => s.type == SequenceType.protein)
        : context
              .watch<AppState>()
              .sequences
              .where((s) => _selectedIds.contains(s.id))
              .any((s) => s.type == SequenceType.protein);

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
              'Alignment algorithm',
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
                ButtonSegment(
                  value: AlignmentMode.glocal,
                  label: Text('Semi-global'),
                  icon: Icon(Icons.open_in_full),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              _mode.description,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
          ] else if (_selectedIds.length >= 3) ...[
            const Text(
              'Multiple alignment method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<MsaMethod>(
              segments: const [
                ButtonSegment(
                  value: MsaMethod.centerStar,
                  label: Text('Fast'),
                  icon: Icon(Icons.speed),
                ),
                ButtonSegment(
                  value: MsaMethod.guideTree,
                  label: Text('Accurate (guide-tree)'),
                  icon: Icon(Icons.account_tree),
                ),
              ],
              selected: {_msaMethod},
              onSelectionChanged: (v) => setState(() => _msaMethod = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              _msaMethod.description,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
          ],
          _AdvancedOptionsPanel(
            expanded: _showAdvanced,
            onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
            matrixType: _matrixType,
            gapModel: _gapModel,
            matchScore: _matchScore,
            mismatchScore: _mismatchScore,
            gapPenalty: _gapPenalty,
            gapOpenPenalty: _gapOpenPenalty,
            gapExtendPenalty: _gapExtendPenalty,
            autoBand: _autoBand,
            isProteinSelection: isProteinSelection,
            onMatrixChanged: (v) => setState(() => _matrixType = v),
            onGapModelChanged: (v) => setState(() => _gapModel = v),
            onMatchScoreChanged: (v) => setState(() => _matchScore = v),
            onMismatchScoreChanged: (v) => setState(() => _mismatchScore = v),
            onGapPenaltyChanged: (v) => setState(() => _gapPenalty = v),
            onGapOpenChanged: (v) => setState(() => _gapOpenPenalty = v),
            onGapExtendChanged: (v) => setState(() => _gapExtendPenalty = v),
            onAutoBandChanged: (v) => setState(() => _autoBand = v),
          ),
          const SizedBox(height: 16),
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

class _AdvancedOptionsPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final SubstitutionMatrixType matrixType;
  final GapModel gapModel;
  final int matchScore;
  final int mismatchScore;
  final int gapPenalty;
  final int gapOpenPenalty;
  final int gapExtendPenalty;
  final bool autoBand;
  final bool isProteinSelection;
  final ValueChanged<SubstitutionMatrixType> onMatrixChanged;
  final ValueChanged<GapModel> onGapModelChanged;
  final ValueChanged<int> onMatchScoreChanged;
  final ValueChanged<int> onMismatchScoreChanged;
  final ValueChanged<int> onGapPenaltyChanged;
  final ValueChanged<int> onGapOpenChanged;
  final ValueChanged<int> onGapExtendChanged;
  final ValueChanged<bool> onAutoBandChanged;

  const _AdvancedOptionsPanel({
    required this.expanded,
    required this.onToggle,
    required this.matrixType,
    required this.gapModel,
    required this.matchScore,
    required this.mismatchScore,
    required this.gapPenalty,
    required this.gapOpenPenalty,
    required this.gapExtendPenalty,
    required this.autoBand,
    required this.isProteinSelection,
    required this.onMatrixChanged,
    required this.onGapModelChanged,
    required this.onMatchScoreChanged,
    required this.onMismatchScoreChanged,
    required this.onGapPenaltyChanged,
    required this.onGapOpenChanged,
    required this.onGapExtendChanged,
    required this.onAutoBandChanged,
  });

  List<SubstitutionMatrixType> get _availableMatrices => isProteinSelection
      ? const [
          SubstitutionMatrixType.simple,
          SubstitutionMatrixType.blosum62,
          SubstitutionMatrixType.pam250,
        ]
      : const [
          SubstitutionMatrixType.simple,
          SubstitutionMatrixType.dnaTransitionTransversion,
        ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Advanced scoring & performance options',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Substitution scheme',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<SubstitutionMatrixType>(
                    isExpanded: true,
                    value: _availableMatrices.contains(matrixType)
                        ? matrixType
                        : _availableMatrices.first,
                    items: _availableMatrices
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onMatrixChanged(v);
                    },
                  ),
                  if (matrixType == SubstitutionMatrixType.simple) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Match score',
                            value: matchScore,
                            onChanged: onMatchScoreChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NumberField(
                            label: 'Mismatch score',
                            value: mismatchScore,
                            onChanged: onMismatchScoreChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Gap penalty model',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<GapModel>(
                    segments: const [
                      ButtonSegment(
                        value: GapModel.linear,
                        label: Text('Linear'),
                      ),
                      ButtonSegment(
                        value: GapModel.affine,
                        label: Text('Affine (Gotoh)'),
                      ),
                    ],
                    selected: {gapModel},
                    onSelectionChanged: (v) => onGapModelChanged(v.first),
                  ),
                  const SizedBox(height: 10),
                  if (gapModel == GapModel.linear)
                    _NumberField(
                      label: 'Gap penalty (per base)',
                      value: gapPenalty,
                      onChanged: onGapPenaltyChanged,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Gap open penalty',
                            value: gapOpenPenalty,
                            onChanged: onGapOpenChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _NumberField(
                            label: 'Gap extend penalty',
                            value: gapExtendPenalty,
                            onChanged: onGapExtendChanged,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Auto-band long similar sequences',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Speeds up global alignment of long (800+ nt), '
                      'near-equal-length sequence pairs with no accuracy loss.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: autoBand,
                    onChanged: onAutoBandChanged,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onChanged: (s) {
        final v = int.tryParse(s);
        if (v != null) onChanged(v);
      },
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
                _statPill(
                  'Time',
                  '${result.elapsedMs.toStringAsFixed(1)} ms',
                  Colors.grey.shade700,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _tag(result.mode.shortLabel),
                _tag(result.matrixType.label),
                _tag(result.gapModel.label),
                if (result.banded) _tag('Banded (fast path)'),
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
            SequenceLegend(isProtein: result.matrixType.isProteinMatrix),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10.5)),
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
              'Average identity: ${result.averageIdentity.toStringAsFixed(1)}% · '
              'Length: ${result.consensusLength} · ${result.method.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Computed in ${result.elapsedMs.toStringAsFixed(1)} ms',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
