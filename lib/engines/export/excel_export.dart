import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'report_data.dart';

class ExcelExportEngine {
  static Uint8List generate(ReportData data) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheetName];
    excel.rename(defaultSheetName, 'Summary');

    int rowIdx = 0;

    void writeRow(List<String> values, {bool bold = false}) {
      for (int c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        );
        cell.value = TextCellValue(values[c]);
        if (bold) {
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#E0F2F1'),
          );
        }
      }
      rowIdx++;
    }

    writeRow([data.title], bold: true);
    if (data.subtitle.isNotEmpty) writeRow([data.subtitle]);
    writeRow(['Generated: ${data.generatedAt.toIso8601String()}']);
    rowIdx++;

    for (final section in data.sections) {
      if (section.title.isNotEmpty) {
        writeRow([section.title], bold: true);
      }
      if (section.bodyText != null && section.bodyText!.isNotEmpty) {
        writeRow([section.bodyText!]);
      }
      if (section.bullets != null) {
        for (final b in section.bullets!) {
          writeRow(['- $b']);
        }
      }
      if (section.table != null && section.table!.isNotEmpty) {
        for (int r = 0; r < section.table!.length; r++) {
          writeRow(section.table![r], bold: r == 0);
        }
      }
      rowIdx++; // blank separator row
    }

    // Also create one sheet per table-bearing section for cleaner data analysis
    for (final section in data.sections) {
      if (section.table != null && section.table!.length > 1) {
        final safeName = _safeSheetName(section.title);
        final s = excel[safeName];
        for (int r = 0; r < section.table!.length; r++) {
          for (int c = 0; c < section.table![r].length; c++) {
            final cell = s.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
            );
            cell.value = TextCellValue(section.table![r][c]);
            if (r == 0) {
              cell.cellStyle = CellStyle(
                bold: true,
                backgroundColorHex: ExcelColor.fromHexString('#B2DFDB'),
              );
            }
          }
        }
      }
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  static String _safeSheetName(String raw) {
    var name = raw.replaceAll(RegExp(r'[\\/:*?\[\]]'), '').trim();
    if (name.isEmpty) name = 'Data';
    if (name.length > 28) name = name.substring(0, 28);
    return name;
  }
}
