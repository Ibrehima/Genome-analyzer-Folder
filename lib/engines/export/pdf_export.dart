import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'report_data.dart';

class PdfExportEngine {
  static Future<Uint8List> generate(ReportData data) async {
    final doc = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(data.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.teal, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Genome Analyzer',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.teal700),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            data.title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          if (data.subtitle.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                data.subtitle,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          pw.SizedBox(height: 16),
          ...data.sections.expand((s) => _buildSection(s)),
        ],
      ),
    );

    return doc.save();
  }

  static List<pw.Widget> _buildSection(ReportSection s) {
    final widgets = <pw.Widget>[];
    if (s.title.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            s.title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800,
            ),
          ),
        ),
      );
    }
    if (s.bodyText != null && s.bodyText!.isNotEmpty) {
      widgets.add(
        pw.Text(
          s.bodyText!,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
        ),
      );
    }
    if (s.bullets != null && s.bullets!.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: s.bullets!
                .map(
                  (b) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '•  ',
                          style: const pw.TextStyle(fontSize: 10.5),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            b,
                            style: const pw.TextStyle(fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    if (s.table != null && s.table!.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              for (int i = 0; i < s.table!.first.length; i++)
                i: const pw.FlexColumnWidth(),
            },
            children: [
              for (int r = 0; r < s.table!.length; r++)
                pw.TableRow(
                  decoration: r == 0
                      ? const pw.BoxDecoration(color: PdfColors.teal50)
                      : null,
                  children: [
                    for (final cell in s.table![r])
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          cell,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: r == 0
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
