import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_models.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  final bool embedded;
  const ReportsScreen({super.key, this.embedded = false});

  IconData _icon(ExportFormat f) {
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

  Color _color(ExportFormat f) {
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

  String _formatLabel(ExportFormat f) => f.name.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().reportHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Export Center'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear history',
              onPressed: () async {
                await StorageService.clearReportHistory();
                if (context.mounted) {
                  await context.read<AppState>().loadFromDisk();
                }
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: Color(0xFFFFCC80),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No reports yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Run any analysis module and tap "Export" to generate PDF, Word, PowerPoint or Excel reports. They will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final item = history[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _color(
                        item.format,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        _icon(item.format),
                        color: _color(item.format),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      '${item.moduleType} · ${_formatLabel(item.format)} · ${item.createdAt.toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
