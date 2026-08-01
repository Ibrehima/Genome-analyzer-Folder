import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/statistics_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<String> _selectedIds = [];
  bool _running = false;
  StatisticsReport? _report;

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .where((s) => s != null)
        .toList();
    if (seqs.isEmpty) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final report = StatisticsEngine.analyzeCollection(
      seqs.map((s) => s!).toList(),
    );
    setState(() {
      _report = report;
      _running = false;
    });
  }

  Future<void> _useAll() async {
    final all = context.read<AppState>().sequences;
    setState(() => _selectedIds = all.map((s) => s.id).toList());
    await _run();
  }

  ReportData _buildReport() {
    final r = _report!;
    return ReportData(
      title: 'Statistical Analysis Report',
      subtitle: '${r.totalSequences} sequence(s) analyzed',
      sections: [
        ReportSection(
          title: 'Descriptive Statistics — Sequence Length',
          table: [
            ['Metric', 'Value'],
            ['Mean', r.lengthStats.mean.toStringAsFixed(2)],
            ['Median', r.lengthStats.median.toStringAsFixed(2)],
            ['Std. Dev.', r.lengthStats.stdDev.toStringAsFixed(2)],
            ['Min', r.lengthStats.min.toStringAsFixed(0)],
            ['Max', r.lengthStats.max.toStringAsFixed(0)],
          ],
        ),
        ReportSection(
          title: 'Descriptive Statistics — GC Content (%)',
          table: [
            ['Metric', 'Value'],
            ['Mean', r.gcStats.mean.toStringAsFixed(2)],
            ['Median', r.gcStats.median.toStringAsFixed(2)],
            ['Std. Dev.', r.gcStats.stdDev.toStringAsFixed(2)],
            ['Min', r.gcStats.min.toStringAsFixed(2)],
            ['Max', r.gcStats.max.toStringAsFixed(2)],
          ],
        ),
        ReportSection(
          title: 'Diversity Indices',
          bodyText:
              'Shannon diversity index (H\'): ${r.shannonDiversityIndex.toStringAsFixed(3)} bits\n'
              'Simpson diversity index (1-D): ${r.simpsonDiversityIndex.toStringAsFixed(3)}\n\n'
              'These indices summarize nucleotide/residue compositional diversity across the selected collection.',
        ),
        ReportSection(
          title: 'Nucleotide / Residue Frequency',
          table: [
            ['Symbol', 'Count'],
            ...r.nucleotideFrequency.entries.map((e) => [e.key, '${e.value}']),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics Lab'),
        actions: [
          if (_report != null)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Statistics',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select sequences for analysis',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(onPressed: _useAll, child: const Text('Use all')),
            ],
          ),
          SequenceSelector(
            selectedIds: _selectedIds,
            multiple: true,
            onChanged: (v) => setState(() => _selectedIds = v),
            label: '',
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
                  : const Icon(Icons.bar_chart_rounded),
              label: Text(
                _running ? 'Computing statistics...' : 'Compute Statistics',
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_report != null) _StatisticsView(report: _report!),
        ],
      ),
    );
  }
}

class _StatisticsView extends StatelessWidget {
  final StatisticsReport report;
  const _StatisticsView({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Sequences',
                '${report.totalSequences}',
                AppColors.primaryBlue,
                Icons.dns_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Shannon H\'',
                report.shannonDiversityIndex.toStringAsFixed(2),
                const Color(0xFFAD1457),
                Icons.scatter_plot,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Mean length',
                report.lengthStats.mean.toStringAsFixed(0),
                AppColors.teal,
                Icons.straighten,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Mean GC%',
                report.gcStats.mean.toStringAsFixed(1),
                AppColors.warning,
                Icons.opacity,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nucleotide / Residue Frequency',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = report.nucleotideFrequency.keys
                                  .toList();
                              final idx = value.toInt();
                              if (idx < 0 || idx >= keys.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  keys[idx],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: report.nucleotideFrequency.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((e) {
                            final colors = [
                              AppColors.primaryBlue,
                              AppColors.teal,
                              const Color(0xFF7B1FA2),
                              AppColors.warning,
                              Colors.grey,
                            ];
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.value.toDouble(),
                                  color: colors[e.key % colors.length],
                                  width: 22,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          })
                          .toList(),
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
                  'Diversity Indices',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                _diversityRow(
                  'Shannon Index (H\')',
                  report.shannonDiversityIndex,
                  4,
                ),
                const SizedBox(height: 8),
                _diversityRow(
                  'Simpson Index (1-D)',
                  report.simpsonDiversityIndex,
                  1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _diversityRow(String label, double value, double max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            Text(
              value.toStringAsFixed(3),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (value / max).clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.teal),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
