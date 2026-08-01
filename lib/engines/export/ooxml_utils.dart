import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Shared helpers for building minimal, valid OOXML (.docx / .pptx) packages
/// entirely on-device without any third-party document generation package.
class OoxmlUtils {
  static String escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Builds a ZIP archive (the container format for .docx/.pptx/.xlsx)
  /// from a map of internal file paths -> UTF8 text content.
  static Uint8List buildZip(Map<String, String> parts) {
    final archive = Archive();
    parts.forEach((path, content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });
    final encoded = ZipEncoder().encode(archive) ?? <int>[];
    return Uint8List.fromList(encoded);
  }

  static String isoDate(DateTime dt) =>
      '${dt.toUtc().toIso8601String().split('.').first}Z';

  static const relNsPackage =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const relNsOffice =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static String coreProps({required String title, required DateTime date}) =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${escapeXml(title)}</dc:title>
  <dc:creator>Genome Analyzer</dc:creator>
  <cp:lastModifiedBy>Genome Analyzer</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${isoDate(date)}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${isoDate(date)}</dcterms:modified>
</cp:coreProperties>
''';

  static String appProps() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Genome Analyzer</Application>
</Properties>
''';
}
