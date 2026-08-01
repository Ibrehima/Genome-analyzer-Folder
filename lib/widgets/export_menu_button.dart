import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../engines/export/report_data.dart';
import '../engines/export/export_engine.dart';
import '../services/app_state.dart';

/// Reusable export control: lets the user pick PDF / Word / PowerPoint /
/// Excel and handles generation, saving/downloading and history logging.
class ExportMenuButton extends StatefulWidget {
  final ReportData Function() reportBuilder;
  final String moduleType;
  final List<ExportFormat> formats;

  const ExportMenuButton({
    super.key,
    required this.reportBuilder,
    required this.moduleType,
    this.formats = const [
      ExportFormat.pdf,
      ExportFormat.docx,
      ExportFormat.pptx,
      ExportFormat.xlsx,
      ExportFormat.txt,
    ],
  });

  @override
  State<ExportMenuButton> createState() => _ExportMenuButtonState();
}

class _ExportMenuButtonState extends State<ExportMenuButton> {
  bool _exporting = false;

  String _formatLabel(ExportFormat f) {
    switch (f) {
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.docx:
        return 'Word (.docx)';
      case ExportFormat.pptx:
        return 'PowerPoint (.pptx)';
      case ExportFormat.xlsx:
        return 'Excel (.xlsx)';
      case ExportFormat.txt:
        return 'Plain Text (.txt)';
    }
  }

  IconData _formatIcon(ExportFormat f) {
    switch (f) {
      case ExportFormat.pdf:
        return Icons.picture_as_pdf;
      case ExportFormat.docx:
        return Icons.description;
      case ExportFormat.pptx:
        return Icons.slideshow;
      case ExportFormat.xlsx:
        return Icons.grid_on;
      case ExportFormat.txt:
        return Icons.notes_rounded;
    }
  }

  Color _formatColor(ExportFormat f) {
    switch (f) {
      case ExportFormat.pdf:
        return const Color(0xFFC62828);
      case ExportFormat.docx:
        return const Color(0xFF1565C0);
      case ExportFormat.pptx:
        return const Color(0xFFEF6C00);
      case ExportFormat.xlsx:
        return const Color(0xFF2E7D32);
      case ExportFormat.txt:
        return const Color(0xFF546E7A);
    }
  }

  Future<void> _export(ExportFormat format) async {
    setState(() => _exporting = true);
    try {
      final data = widget.reportBuilder();
      await ExportEngine.exportAndSave(data: data, format: format);
      if (mounted) {
        await context.read<AppState>().recordReport(
          ReportHistoryItem(
            title: data.title,
            moduleType: widget.moduleType,
            format: format,
            summary: data.subtitle,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported "${data.title}" as ${_formatLabel(format)}',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exporting) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<ExportFormat>(
      tooltip: 'Export report',
      onSelected: _export,
      itemBuilder: (context) => widget.formats
          .map(
            (f) => PopupMenuItem<ExportFormat>(
              value: f,
              child: Row(
                children: [
                  Icon(_formatIcon(f), color: _formatColor(f), size: 20),
                  const SizedBox(width: 10),
                  Text(_formatLabel(f)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
