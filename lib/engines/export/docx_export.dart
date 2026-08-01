import 'dart:typed_data';
import 'ooxml_utils.dart';
import 'report_data.dart';

/// Generates minimal, valid .docx (Word) documents entirely on-device
/// using hand-built OOXML (no external Word-generation package required).
class DocxExportEngine {
  static Uint8List generate(ReportData data) {
    final documentXml = _buildDocumentXml(data);

    final parts = <String, String>{
      '[Content_Types].xml': _contentTypesXml(),
      '_rels/.rels': _rootRelsXml(),
      'docProps/core.xml': OoxmlUtils.coreProps(
        title: data.title,
        date: data.generatedAt,
      ),
      'docProps/app.xml': OoxmlUtils.appProps(),
      'word/document.xml': documentXml,
    };

    return OoxmlUtils.buildZip(parts);
  }

  static String _contentTypesXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

  static String _rootRelsXml() =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">
  <Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="${OoxmlUtils.relNsOffice}/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static String _titleParagraph(String text) =>
      '''
<w:p>
  <w:pPr><w:spacing w:after="240"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="44"/><w:color w:val="0D47A1"/></w:rPr><w:t xml:space="preserve">${OoxmlUtils.escapeXml(text)}</w:t></w:r>
</w:p>
''';

  static String _subtitleParagraph(String text) =>
      '''
<w:p>
  <w:pPr><w:spacing w:after="200"/></w:pPr>
  <w:r><w:rPr><w:i/><w:sz w:val="24"/><w:color w:val="616161"/></w:rPr><w:t xml:space="preserve">${OoxmlUtils.escapeXml(text)}</w:t></w:r>
</w:p>
''';

  static String _sectionHeading(String text) =>
      '''
<w:p>
  <w:pPr><w:spacing w:before="280" w:after="140"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="00695C"/></w:rPr><w:t xml:space="preserve">${OoxmlUtils.escapeXml(text)}</w:t></w:r>
</w:p>
''';

  static String _bodyParagraph(String text) =>
      '''
<w:p>
  <w:pPr><w:spacing w:after="160"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">${OoxmlUtils.escapeXml(text)}</w:t></w:r>
</w:p>
''';

  static String _bulletParagraph(String text) =>
      '''
<w:p>
  <w:pPr><w:spacing w:after="80"/><w:ind w:left="360"/></w:pPr>
  <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">•  ${OoxmlUtils.escapeXml(text)}</w:t></w:r>
</w:p>
''';

  static String _table(List<List<String>> rows) {
    final sb = StringBuffer();
    sb.write('''
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="0" w:type="auto"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="4" w:color="B0BEC5"/>
      <w:left w:val="single" w:sz="4" w:color="B0BEC5"/>
      <w:bottom w:val="single" w:sz="4" w:color="B0BEC5"/>
      <w:right w:val="single" w:sz="4" w:color="B0BEC5"/>
      <w:insideH w:val="single" w:sz="4" w:color="B0BEC5"/>
      <w:insideV w:val="single" w:sz="4" w:color="B0BEC5"/>
    </w:tblBorders>
  </w:tblPr>
''');
    for (int r = 0; r < rows.length; r++) {
      sb.write('<w:tr>');
      for (final cell in rows[r]) {
        final shade = r == 0 ? '<w:shd w:val="clear" w:fill="E0F2F1"/>' : '';
        final bold = r == 0 ? '<w:b/>' : '';
        sb.write('''
<w:tc>
  <w:tcPr><w:tcW w:w="0" w:type="auto"/>$shade</w:tcPr>
  <w:p><w:r><w:rPr>$bold<w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">${OoxmlUtils.escapeXml(cell)}</w:t></w:r></w:p>
</w:tc>
''');
      }
      sb.write('</w:tr>');
    }
    sb.write('</w:tbl><w:p/>');
    return sb.toString();
  }

  static String _buildDocumentXml(ReportData data) {
    final sb = StringBuffer();
    sb.write(_titleParagraph(data.title));
    if (data.subtitle.isNotEmpty) sb.write(_subtitleParagraph(data.subtitle));
    sb.write(
      _subtitleParagraph(
        'Generated: ${data.generatedAt.toString().substring(0, 19)}',
      ),
    );

    for (final section in data.sections) {
      if (section.title.isNotEmpty) sb.write(_sectionHeading(section.title));
      if (section.bodyText != null && section.bodyText!.isNotEmpty) {
        sb.write(_bodyParagraph(section.bodyText!));
      }
      if (section.bullets != null) {
        for (final b in section.bullets!) {
          sb.write(_bulletParagraph(b));
        }
      }
      if (section.table != null && section.table!.isNotEmpty) {
        sb.write(_table(section.table!));
      }
    }

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${sb.toString()}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }
}
