import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'report_data.dart';

/// Simple, universal plain-text export — the most portable format,
/// readable on any device without special software.
class TxtExportEngine {
  static Uint8List generate(ReportData data) {
    final buf = StringBuffer();
    buf.writeln('=' * 70);
    buf.writeln(data.title.toUpperCase());
    if (data.subtitle.isNotEmpty) buf.writeln(data.subtitle);
    buf.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(data.generatedAt)}',
    );
    buf.writeln('=' * 70);
    buf.writeln();

    for (final section in data.sections) {
      final dashCount = (66 - section.title.length).clamp(0, 66);
      buf.writeln('-- ${section.title} ${'-' * dashCount}');
      buf.writeln();
      final bodyText = section.bodyText;
      if (bodyText != null && bodyText.isNotEmpty) {
        buf.writeln(bodyText);
        buf.writeln();
      }
      final bullets = section.bullets;
      if (bullets != null && bullets.isNotEmpty) {
        for (final b in bullets) {
          buf.writeln('  * $b');
        }
        buf.writeln();
      }
      final table = section.table;
      if (table != null && table.isNotEmpty) {
        final widths = <int>[];
        for (final row in table) {
          for (int i = 0; i < row.length; i++) {
            final len = row[i].length;
            if (widths.length <= i) {
              widths.add(len);
            } else if (len > widths[i]) {
              widths[i] = len;
            }
          }
        }
        for (int r = 0; r < table.length; r++) {
          final row = table[r];
          final line = StringBuffer();
          for (int i = 0; i < row.length; i++) {
            line.write(row[i].padRight(widths[i] + 2));
          }
          buf.writeln(line.toString());
          if (r == 0) {
            buf.writeln('-' * (widths.fold<int>(0, (a, b) => a + b + 2)));
          }
        }
        buf.writeln();
      }
    }
    buf.writeln('=' * 70);
    buf.writeln('Genome Analyzer - offline bioinformatics workbench');
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }
}
