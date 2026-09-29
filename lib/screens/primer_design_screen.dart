import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/primer_engine.dart';
import '../engines/lamp_primer_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

/// Primer Design workbench with two amplification chemistries:
///  - PCR: classic forward/reverse primer pair design (Primer3-style).
///  - LAMP: isothermal amplification primer sets (F3/B3 outer + FIP/BIP
///    composite inner primers, optional LF/LB loop primers).
class PrimerDesignScreen extends StatefulWidget {
  const PrimerDesignScreen({super.key});

  @override
  State<PrimerDesignScreen> createState() => _PrimerDesignScreenState();
}

class _PrimerDesignScreenState extends State<PrimerDesignScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primer Design'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'PCR', icon: Icon(Icons.linear_scale_rounded, size: 20)),
            Tab(
              text: 'LAMP',
              icon: Icon(Icons.all_inclusive_rounded, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_PcrPrimerTab(), _LampPrimerTab()],
      ),
    );
  }
}

// =========================================================================
// PCR TAB (pre-existing forward/reverse primer-pair design)
// =========================================================================

class _PcrPrimerTab extends StatefulWidget {
  const _PcrPrimerTab();

  @override
  State<_PcrPrimerTab> createState() => _PcrPrimerTabState();
}

class _PcrPrimerTabState extends State<_PcrPrimerTab> {
  List<String> _selectedIds = [];
  RangeValues _lenRange = const RangeValues(18, 24);
  RangeValues _productRange = const RangeValues(100, 500);
  List<PrimerPairResult> _results = [];
  bool _running = false;
  String? _templateName;

  Future<void> _run() async {
    if (_selectedIds.isEmpty) return;
    final seq = context.read<AppState>().getSequenceById(_selectedIds.first);
    if (seq == null) return;
    setState(() {
      _running = true;
      _templateName = seq.name;
    });
    await Future.delayed(const Duration(milliseconds: 50));
    final results = PrimerEngine.designPrimerPairs(
      seq.sequence,
      minLen: _lenRange.start.round(),
      maxLen: _lenRange.end.round(),
      minProductSize: _productRange.start.round(),
      maxProductSize: _productRange.end.round(),
      maxPairs: 8,
    );
    setState(() {
      _results = results;
      _running = false;
    });
  }

  ReportData _buildReport() {
    final rows = <List<String>>[
      [
        '#',
        'Forward Primer (5\'->3\')',
        'Fwd Tm',
        'Fwd GC%',
        'Reverse Primer (5\'->3\')',
        'Rev Tm',
        'Rev GC%',
        'Product (bp)',
        'Score',
      ],
    ];
    for (int i = 0; i < _results.length; i++) {
      final r = _results[i];
      rows.add([
        '${i + 1}',
        r.forward.sequence,
        r.forward.meltingTemp.toStringAsFixed(1),
        r.forward.gcContent.toStringAsFixed(1),
        r.reverse.sequence,
        r.reverse.meltingTemp.toStringAsFixed(1),
        r.reverse.gcContent.toStringAsFixed(1),
        '${r.productSize}',
        r.pairScore.toStringAsFixed(1),
      ]);
    }
    return ReportData(
      title: 'PCR Primer Design Report',
      subtitle:
          'Template: ${_templateName ?? ""} · ${_results.length} candidate pairs',
      sections: [
        ReportSection(
          title: 'Overview',
          bodyText:
              'Primer candidates were designed using local heuristics (GC% 30-70%, Tm balancing, hairpin & dimer risk minimization). '
              'Length range: ${_lenRange.start.round()}-${_lenRange.end.round()} nt. Product size range: ${_productRange.start.round()}-${_productRange.end.round()} bp.',
        ),
        ReportSection(title: 'Top Primer Pairs', table: rows),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        if (_results.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Primer Design (PCR)',
            ),
          ),
        SequenceSelector(
          selectedIds: _selectedIds,
          onChanged: (v) => setState(() => _selectedIds = v),
          label: 'Select a template sequence',
        ),
        const SizedBox(height: 18),
        Text(
          'Primer length range: ${_lenRange.start.round()}–${_lenRange.end.round()} nt',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        RangeSlider(
          values: _lenRange,
          min: 15,
          max: 30,
          divisions: 15,
          labels: RangeLabels(
            '${_lenRange.start.round()}',
            '${_lenRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _lenRange = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Product size range: ${_productRange.start.round()}–${_productRange.end.round()} bp',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        RangeSlider(
          values: _productRange,
          min: 50,
          max: 1000,
          divisions: 19,
          labels: RangeLabels(
            '${_productRange.start.round()}',
            '${_productRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _productRange = v),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.biotech),
            label: Text(_running ? 'Designing primers...' : 'Design Primers'),
          ),
        ),
        const SizedBox(height: 20),
        if (_results.isEmpty && !_running)
          const _InfoBanner(
            text:
                'Results will appear here. Primers are ranked by an overall quality score combining Tm balance, GC content and dimer/hairpin risk.',
          ),
        ..._results.asMap().entries.map(
          (e) => _PrimerPairCard(index: e.key, result: e.value),
        ),
      ],
    );
  }
}

class _PrimerPairCard extends StatelessWidget {
  final int index;
  final PrimerPairResult result;
  const _PrimerPairCard({required this.index, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradPrimer,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pair ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Score: ${result.pairScore.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PrimerRow(label: 'Forward', primer: result.forward),
            const SizedBox(height: 8),
            _PrimerRow(label: 'Reverse', primer: result.reverse),
            const Divider(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Metric(
                  label: 'Product size',
                  value: '${result.productSize} bp',
                ),
                _Metric(
                  label: 'Tm difference',
                  value: '${result.tmDifference.toStringAsFixed(1)} °C',
                ),
                _Metric(
                  label: 'Cross-dimer risk',
                  value: '${(result.crossDimerRisk * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimerRow extends StatelessWidget {
  final String label;
  final PrimerCandidate primer;
  const _PrimerRow({required this.label, required this.primer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SelectableText(
            "5'-${primer.sequence}-3'",
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              _Metric(
                label: 'Tm',
                value: '${primer.meltingTemp.toStringAsFixed(1)}°C',
              ),
              _Metric(
                label: 'GC%',
                value: '${primer.gcContent.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Hairpin',
                value: '${(primer.hairpinRisk * 100).toStringAsFixed(0)}%',
              ),
              _Metric(
                label: 'Self-dimer',
                value: '${(primer.selfDimerRisk * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// LAMP TAB (new: isothermal amplification primer sets)
// =========================================================================

class _LampPrimerTab extends StatefulWidget {
  const _LampPrimerTab();

  @override
  State<_LampPrimerTab> createState() => _LampPrimerTabState();
}

class _LampPrimerTabState extends State<_LampPrimerTab> {
  List<String> _selectedIds = [];
  RangeValues _outerLenRange = const RangeValues(18, 22);
  RangeValues _innerLenRange = const RangeValues(18, 22);
  RangeValues _coreRange = const RangeValues(40, 80);
  bool _includeLoopPrimers = true;
  List<LampPrimerSet> _results = [];
  bool _running = false;
  String? _templateName;
  String? _tooShortWarning;

  Future<void> _run() async {
    if (_selectedIds.isEmpty) return;
    final seq = context.read<AppState>().getSequenceById(_selectedIds.first);
    if (seq == null) return;
    setState(() {
      _running = true;
      _templateName = seq.name;
      _tooShortWarning = null;
    });
    await Future.delayed(const Duration(milliseconds: 50));
    if (seq.sequence.length < 150) {
      setState(() {
        _running = false;
        _results = [];
        _tooShortWarning =
            'Template is ${seq.sequence.length} nt — LAMP needs at least '
            '~150-200 nt to fit the F3/F2/F1c...B1c/B2/B3 topology. '
            'Choose a longer template sequence.';
      });
      return;
    }
    final results = LampPrimerEngine.designLampPrimers(
      seq.sequence,
      outerMinLen: _outerLenRange.start.round(),
      outerMaxLen: _outerLenRange.end.round(),
      innerMinLen: _innerLenRange.start.round(),
      innerMaxLen: _innerLenRange.end.round(),
      coreSizeRange: [_coreRange.start.round(), _coreRange.end.round()],
      includeLoopPrimers: _includeLoopPrimers,
      maxSets: 6,
    );
    setState(() {
      _results = results;
      _running = false;
      if (results.isEmpty) {
        _tooShortWarning =
            'No valid LAMP primer set could be found with the current '
            'settings. Try widening the primer length ranges, increasing '
            'the amplicon core size range, or using a longer/different '
            'template.';
      }
    });
  }

  ReportData _buildReport() {
    final rows = <List<String>>[
      [
        '#',
        'F3',
        'FIP (F1c+F2)',
        'BIP (B1c+B2)',
        'B3',
        'LF',
        'LB',
        'Core (bp)',
        'Span (bp)',
        'Score',
      ],
    ];
    for (int i = 0; i < _results.length; i++) {
      final s = _results[i];
      rows.add([
        '${i + 1}',
        s.f3.sequence,
        s.fip,
        s.bip,
        s.b3.sequence,
        s.lf?.sequence ?? '—',
        s.lb?.sequence ?? '—',
        '${s.ampliconCoreSize}',
        '${s.totalSpan}',
        s.score.toStringAsFixed(1),
      ]);
    }
    return ReportData(
      title: 'LAMP Primer Design Report',
      subtitle:
          'Template: ${_templateName ?? ""} · ${_results.length} candidate primer sets',
      sections: [
        ReportSection(title: 'Overview', bodyText: LampPrimerEngine.disclaimer),
        ReportSection(title: 'Candidate LAMP Primer Sets', table: rows),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        if (_results.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Primer Design (LAMP)',
            ),
          ),
        SequenceSelector(
          selectedIds: _selectedIds,
          onChanged: (v) => setState(() => _selectedIds = v),
          label: 'Select a template sequence (≥150 nt recommended)',
        ),
        const SizedBox(height: 16),
        const _InfoBanner(
          text:
              'LAMP (Loop-mediated isothermal AMPlification) uses 4-6 primers: '
              'outer F3/B3, composite inner FIP (F1c+F2) & BIP (B1c+B2), and '
              'optional loop primers LF/LB that speed up amplification.',
        ),
        const SizedBox(height: 14),
        Text(
          'Outer primer (F3/B3) length: ${_outerLenRange.start.round()}–${_outerLenRange.end.round()} nt',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        RangeSlider(
          values: _outerLenRange,
          min: 15,
          max: 26,
          divisions: 11,
          labels: RangeLabels(
            '${_outerLenRange.start.round()}',
            '${_outerLenRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _outerLenRange = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Inner primer segment (F2/F1c/B1c/B2) length: ${_innerLenRange.start.round()}–${_innerLenRange.end.round()} nt',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        RangeSlider(
          values: _innerLenRange,
          min: 15,
          max: 26,
          divisions: 11,
          labels: RangeLabels(
            '${_innerLenRange.start.round()}',
            '${_innerLenRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _innerLenRange = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Amplicon core size (F1–B1 gap): ${_coreRange.start.round()}–${_coreRange.end.round()} bp',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        RangeSlider(
          values: _coreRange,
          min: 20,
          max: 150,
          divisions: 13,
          labels: RangeLabels(
            '${_coreRange.start.round()}',
            '${_coreRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _coreRange = v),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeLoopPrimers,
          onChanged: (v) => setState(() => _includeLoopPrimers = v),
          title: const Text(
            'Design loop primers (LF/LB)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          subtitle: const Text(
            'Optional but recommended — speeds up the LAMP reaction',
            style: TextStyle(fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedIds.isEmpty || _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.all_inclusive_rounded),
            label: Text(
              _running ? 'Designing LAMP primers...' : 'Design LAMP Primers',
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_tooShortWarning != null)
          _InfoBanner(text: _tooShortWarning!, isWarning: true),
        if (_results.isEmpty && !_running && _tooShortWarning == null)
          const _InfoBanner(
            text:
                'Results will appear here. Sets are ranked by Tm balance across '
                'all 6 core segments, hairpin risk and FIP/BIP cross-dimer risk.',
          ),
        ..._results.asMap().entries.map(
          (e) => _LampSetCard(index: e.key, set: e.value),
        ),
      ],
    );
  }
}

class _LampSetCard extends StatelessWidget {
  final int index;
  final LampPrimerSet set;
  const _LampSetCard({required this.index, required this.set});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradPrimer,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Set ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Score: ${set.score.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AmpliconMapChip(set: set),
            const SizedBox(height: 12),
            _LampPrimerRow(label: 'F3 (outer)', piece: set.f3),
            const SizedBox(height: 8),
            _LampComposite(
              label: 'FIP  (5\'-F1c-F2-3\')',
              sequence: set.fip,
              tm1: set.f1c.meltingTemp,
              tm2: set.f2.meltingTemp,
            ),
            const SizedBox(height: 8),
            _LampComposite(
              label: 'BIP  (5\'-B1c-B2-3\')',
              sequence: set.bip,
              tm1: set.b1c.meltingTemp,
              tm2: set.b2.meltingTemp,
            ),
            const SizedBox(height: 8),
            _LampPrimerRow(label: 'B3 (outer)', piece: set.b3),
            if (set.hasLoopPrimers) ...[
              const SizedBox(height: 8),
              _LampPrimerRow(label: 'LF (loop, forward)', piece: set.lf!),
              const SizedBox(height: 8),
              _LampPrimerRow(label: 'LB (loop, backward)', piece: set.lb!),
            ],
            const Divider(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Metric(
                  label: 'Amplicon core',
                  value: '${set.ampliconCoreSize} bp',
                ),
                _Metric(label: 'Total span', value: '${set.totalSpan} bp'),
                _Metric(
                  label: 'Loop primers',
                  value: set.hasLoopPrimers ? 'Yes' : 'Not found',
                ),
              ],
            ),
            if (set.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...set.notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• $n',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tiny inline schematic of the F3-F2-F1c...B1c-B2-B3 (+LF/LB) layout, using
/// colored chips in template order — helps the user sanity-check the primer
/// map at a glance without needing a full graphical renderer.
class _AmpliconMapChip extends StatelessWidget {
  final LampPrimerSet set;
  const _AmpliconMapChip({required this.set});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );

    final items = <Widget>[
      chip('F3', const Color(0xFF1565C0)),
      chip('F2', const Color(0xFF00897B)),
      if (set.hasLoopPrimers) chip('LF', const Color(0xFF9E9D24)),
      chip('F1c', const Color(0xFF00897B)),
      const Icon(Icons.more_horiz, size: 14, color: AppColors.textMuted),
      chip('B1c', const Color(0xFFAD1457)),
      if (set.hasLoopPrimers) chip('LB', const Color(0xFF9E9D24)),
      chip('B2', const Color(0xFFAD1457)),
      chip('B3', const Color(0xFF6A1B9A)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

class _LampPrimerRow extends StatelessWidget {
  final String label;
  final LampPrimerPiece piece;
  const _LampPrimerRow({required this.label, required this.piece});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SelectableText(
            "5'-${piece.sequence}-3'",
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              _Metric(label: 'Length', value: '${piece.length} nt'),
              _Metric(
                label: 'Tm',
                value: '${piece.meltingTemp.toStringAsFixed(1)}°C',
              ),
              _Metric(
                label: 'GC%',
                value: '${piece.gcContent.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays a composite primer (FIP or BIP) with its full concatenated
/// sequence plus the individual Tm of its two constituent segments.
class _LampComposite extends StatelessWidget {
  final String label;
  final String sequence;
  final double tm1;
  final double tm2;
  const _LampComposite({
    required this.label,
    required this.sequence,
    required this.tm1,
    required this.tm2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradPrimer.first.withValues(alpha: 0.08),
            AppColors.gradPrimer.last.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.gradPrimer.first.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SelectableText(
            "5'-$sequence-3'",
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              _Metric(label: 'Length', value: '${sequence.length} nt'),
              _Metric(
                label: 'Segment 1 Tm',
                value: '${tm1.toStringAsFixed(1)}°C',
              ),
              _Metric(
                label: 'Segment 2 Tm',
                value: '${tm2.toStringAsFixed(1)}°C',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Shared small widgets
// =========================================================================

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11.5),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final bool isWarning;
  const _InfoBanner({required this.text, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.lightbulb_outline,
            color: isWarning ? AppColors.warning : AppColors.primaryBlue,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
