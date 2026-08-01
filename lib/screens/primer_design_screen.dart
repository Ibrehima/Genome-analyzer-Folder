import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/primer_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class PrimerDesignScreen extends StatefulWidget {
  const PrimerDesignScreen({super.key});

  @override
  State<PrimerDesignScreen> createState() => _PrimerDesignScreenState();
}

class _PrimerDesignScreenState extends State<PrimerDesignScreen> {
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
      title: 'Primer Design Report',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primer Design'),
        actions: [
          if (_results.isNotEmpty)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Primer Design',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
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
      ),
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
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
