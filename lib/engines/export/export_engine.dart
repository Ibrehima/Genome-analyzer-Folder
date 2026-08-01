import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import '../../models/analysis_models.dart';
import 'report_data.dart';
import 'pdf_export.dart';
import 'excel_export.dart';
import 'docx_export.dart';
import 'pptx_export.dart';
import 'txt_export.dart';

/// Unified export facade: generates bytes for the requested format and
/// triggers a cross-platform (Web + Android) file save/download.
class ExportEngine {
  static Future<Uint8List> generateBytes(
    ReportData data,
    ExportFormat format,
  ) async {
    switch (format) {
      case ExportFormat.pdf:
        return await PdfExportEngine.generate(data);
      case ExportFormat.xlsx:
        return ExcelExportEngine.generate(data);
      case ExportFormat.docx:
        return DocxExportEngine.generate(data);
      case ExportFormat.pptx:
        return PptxExportEngine.generate(data);
      case ExportFormat.txt:
        return TxtExportEngine.generate(data);
    }
  }

  static String extensionFor(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.xlsx:
        return 'xlsx';
      case ExportFormat.docx:
        return 'docx';
      case ExportFormat.pptx:
        return 'pptx';
      case ExportFormat.txt:
        return 'txt';
    }
  }

  static MimeType mimeFor(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return MimeType.pdf;
      case ExportFormat.xlsx:
        return MimeType.microsoftExcel;
      case ExportFormat.docx:
        return MimeType.microsoftWord;
      case ExportFormat.pptx:
        return MimeType.microsoftPresentation;
      case ExportFormat.txt:
        return MimeType.text;
    }
  }

  /// Generates the document and saves/downloads it. Returns the saved
  /// path/name reported by file_saver.
  static Future<String> exportAndSave({
    required ReportData data,
    required ExportFormat format,
    String? fileNameOverride,
  }) async {
    final bytes = await generateBytes(data, format);
    final safeName = (fileNameOverride ?? data.title)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
        .replaceAll(' ', '_');
    final name = safeName.isEmpty ? 'genome_analyzer_report' : safeName;

    final result = await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: extensionFor(format),
      mimeType: mimeFor(format),
    );
    return result;
  }
}
