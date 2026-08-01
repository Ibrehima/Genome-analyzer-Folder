import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/quality_engine.dart';
import '../engines/export/report_data.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/sequence_selector.dart';
import '../widgets/export_menu_button.dart';

class QualityControlScreen extends StatefulWidget {
  const QualityControlScreen({super.key});

  @override
  State<QualityControlScreen> createState() => _QualityControlScreenState();
}

class _QualityControlScreenState extends State<QualityControlScreen> {
  List<String> _selectedIds = [];
  bool _running = false;
  List<QualityReport> _reports = [];

  Future<void> _run() async {
    final appState = context.read<AppState>();
    final seqs = _selectedIds
        .map((id) => appState.getSequenceById(id))
        .where((s) => s != null)
        .toList();
    if (seqs.isEmpty) return;
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final reports = seqs.map((s) => QualityEngine.analyze(s!)).toList();
    setState(() {
      _reports = reports;
      _running = false;
    });
  }

  ReportData _buildReport() {
    final rows = <List<String>>[
      ['Sequence', 'Length', 'GC%', 'N%', 'Mean Q', 'Q20%', 'Q30%', 'Grade'],
    ];
    for (final r in _reports) {
      rows.add([
        r.sequenceName,
        '${r.length}',
        r.gcContent.toStringAsFixed(1),
        r.nPercent.toStringAsFixed(2),
        r.meanQuality >= 0 ? r.meanQuality.toStringAsFixed(1) : 'N/A',
        r.q20Percent >= 0 ? r.q20Percent.toStringAsFixed(1) : 'N/A',
        r.q30Percent >= 0 ? r.q30Percent.toStringAsFixed(1) : 'N/A',
        r.overallGrade,
      ]);
    }
    return ReportData(
      title: 'Sequence Quality Control Report',
      subtitle: '${_reports.length} sequence(s) analyzed',
      sections: [
        ReportSection(
          title: 'Methodology',
          bodyText:
              'Quality was assessed using FastQC-style metrics: GC/AT/N content, base composition, and (when Phred scores are '
              'available from FASTQ input) mean/min/max quality plus the percentage of bases at or above Q20 and Q30 thresholds.',
        ),
        ReportSection(title: 'Summary Table', table: rows),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Control'),
        actions: [
          if (_reports.isNotEmpty)
            ExportMenuButton(
              reportBuilder: _buildReport,
              moduleType: 'Quality Control',
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
            label: 'Select sequence(s) to assess',
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
                  : const Icon(Icons.verified_rounded),
              label: Text(
                _running ? 'Analyzing quality...' : 'Run Quality Analysis',
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._reports.map((r) => _QualityCard(report: r)),
        ],
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  final QualityReport report;
  const _QualityCard({required this.report});

  Color get _gradeColor {
    switch (report.overallGrade) {
      case 'A':
        return AppColors.success;
      case 'B':
        return AppColors.primaryBlue;
      case 'C':
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.sequenceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gradeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    report.overallGrade,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _gradeColor,
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
                _metricTile(
                  'Length',
                  '${report.length} bp',
                  AppColors.primaryBlue,
                ),
                _metricTile(
                  'GC content',
                  '${report.gcContent.toStringAsFixed(1)}%',
                  AppColors.teal,
                ),
                _metricTile(
                  'N content',
                  '${report.nPercent.toStringAsFixed(2)}%',
                  AppColors.warning,
                ),
                if (report.meanQuality >= 0)
                  _metricTile(
                    'Mean Q',
                    report.meanQuality.toStringAsFixed(1),
                    const Color(0xFF7B1FA2),
                  ),
                if (report.q30Percent >= 0)
                  _metricTile(
                    'Q30',
                    '${report.q30Percent.toStringAsFixed(1)}%',
                    AppColors.success,
                  ),
              ],
            ),
            if (report.qualityPerPositionBin.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Quality across read position',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 42,
                    lineBarsData: [
                      LineChartBarData(
                        spots: report.qualityPerPositionBin.entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: AppColors.primaryBlue,
                        barWidth: 2.4,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Phred quality scores available (FASTA input). Upload a FASTQ file to see per-base quality trends.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Base composition',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.baseComposition.entries
                  .map(
                    (e) => Chip(
                      label: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
