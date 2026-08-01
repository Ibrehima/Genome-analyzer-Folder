import 'dart:typed_data';
import 'ooxml_utils.dart';
import 'report_data.dart';

/// Generates minimal, valid .pptx (PowerPoint) presentations entirely
/// on-device using hand-built OOXML (no external PPTX-generation package).
class PptxExportEngine {
  static Uint8List generate(ReportData data) {
    // Build slide list: 1 title slide + 1 slide per section (splitting long
    // bullet/table content across multiple slides if needed).
    final slideBodies = <_SlideContent>[];
    slideBodies.add(
      _SlideContent(
        title: data.title,
        lines: [
          if (data.subtitle.isNotEmpty) data.subtitle,
          'Generated: ${data.generatedAt.toString().substring(0, 19)}',
        ],
      ),
    );

    for (final section in data.sections) {
      final lines = <String>[];
      if (section.bodyText != null && section.bodyText!.isNotEmpty) {
        lines.add(section.bodyText!);
      }
      if (section.bullets != null) {
        lines.addAll(section.bullets!.map((b) => '• $b'));
      }
      if (section.table != null && section.table!.isNotEmpty) {
        lines.add('');
        for (final row in section.table!.take(12)) {
          lines.add(row.join('   |   '));
        }
      }
      // Split into chunks of ~10 lines per slide for readability
      const chunkSize = 10;
      if (lines.isEmpty) {
        slideBodies.add(_SlideContent(title: section.title, lines: []));
      } else {
        for (int i = 0; i < lines.length; i += chunkSize) {
          final chunk = lines.sublist(
            i,
            (i + chunkSize).clamp(0, lines.length),
          );
          slideBodies.add(
            _SlideContent(
              title: i == 0 ? section.title : '${section.title} (cont.)',
              lines: chunk,
            ),
          );
        }
      }
    }

    final parts = <String, String>{
      '[Content_Types].xml': _contentTypesXml(slideBodies.length),
      '_rels/.rels': _rootRelsXml(),
      'docProps/core.xml': OoxmlUtils.coreProps(
        title: data.title,
        date: data.generatedAt,
      ),
      'docProps/app.xml': OoxmlUtils.appProps(),
      'ppt/presentation.xml': _presentationXml(slideBodies.length),
      'ppt/_rels/presentation.xml.rels': _presentationRelsXml(
        slideBodies.length,
      ),
      'ppt/theme/theme1.xml': _themeXml(),
      'ppt/slideMasters/slideMaster1.xml': _slideMasterXml(),
      'ppt/slideMasters/_rels/slideMaster1.xml.rels': _slideMasterRelsXml(),
      'ppt/slideLayouts/slideLayout1.xml': _slideLayoutXml(),
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels': _slideLayoutRelsXml(),
    };

    for (int i = 0; i < slideBodies.length; i++) {
      parts['ppt/slides/slide${i + 1}.xml'] = _slideXml(slideBodies[i]);
      parts['ppt/slides/_rels/slide${i + 1}.xml.rels'] = _slideRelsXml();
    }

    return OoxmlUtils.buildZip(parts);
  }

  static String _contentTypesXml(int slideCount) {
    final overrides = StringBuffer();
    for (int i = 1; i <= slideCount; i++) {
      overrides.write(
        '<Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  $overrides
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';
  }

  static String _rootRelsXml() =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">
  <Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="${OoxmlUtils.relNsOffice}/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static String _presentationXml(int slideCount) {
    final sldIds = StringBuffer();
    for (int i = 0; i < slideCount; i++) {
      sldIds.write('<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>');
    }
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>$sldIds</p:sldIdLst>
  <p:sldSz cx="12192000" cy="6858000"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
''';
  }

  static String _presentationRelsXml(int slideCount) {
    final rels = StringBuffer();
    rels.write(
      '<Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
    );
    for (int i = 0; i < slideCount; i++) {
      rels.write(
        '<Relationship Id="rId${i + 2}" Type="${OoxmlUtils.relNsOffice}/slide" Target="slides/slide${i + 1}.xml"/>',
      );
    }
    rels.write(
      '<Relationship Id="rId${slideCount + 2}" Type="${OoxmlUtils.relNsOffice}/theme" Target="theme/theme1.xml"/>',
    );
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">$rels</Relationships>
''';
  }

  static String _slideMasterXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
</p:sldMaster>
''';

  static String _slideMasterRelsXml() =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">
  <Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="${OoxmlUtils.relNsOffice}/theme" Target="../theme/theme1.xml"/>
</Relationships>
''';

  static String _slideLayoutXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:overrideClrMapping bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/></p:clrMapOvr>
</p:sldLayout>
''';

  static String _slideLayoutRelsXml() =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">
  <Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>
''';

  static String _slideRelsXml() =>
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="${OoxmlUtils.relNsPackage}">
  <Relationship Id="rId1" Type="${OoxmlUtils.relNsOffice}/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>
''';

  static String _slideXml(_SlideContent content) {
    final paragraphs = StringBuffer();
    if (content.lines.isEmpty) {
      paragraphs.write(
        '<a:p><a:r><a:rPr lang="en-US" sz="1800"/><a:t></a:t></a:r></a:p>',
      );
    }
    for (final line in content.lines) {
      paragraphs.write(
        '<a:p><a:r><a:rPr lang="en-US" sz="1800"/><a:t xml:space="preserve">${OoxmlUtils.escapeXml(line)}</a:t></a:r></a:p>',
      );
    }
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="457200" y="274638"/><a:ext cx="11277600" cy="914400"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr>
          <a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="3000" b="1"><a:solidFill><a:srgbClr val="1565C0"/></a:solidFill></a:rPr><a:t xml:space="preserve">${OoxmlUtils.escapeXml(content.title)}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="457200" y="1300000"/><a:ext cx="11277600" cy="5200000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square"><a:normAutofit fontScale="90000"/></a:bodyPr>
          <a:lstStyle/>
          $paragraphs
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:overrideClrMapping bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/></p:clrMapOvr>
</p:sld>
''';
  }

  static String _themeXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="GenomeAnalyzerTheme">
  <a:themeElements>
    <a:clrScheme name="GenomeAnalyzer">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="0D47A1"/></a:dk2>
      <a:lt2><a:srgbClr val="E0F2F1"/></a:lt2>
      <a:accent1><a:srgbClr val="1565C0"/></a:accent1>
      <a:accent2><a:srgbClr val="00897B"/></a:accent2>
      <a:accent3><a:srgbClr val="7B1FA2"/></a:accent3>
      <a:accent4><a:srgbClr val="F4511E"/></a:accent4>
      <a:accent5><a:srgbClr val="43A047"/></a:accent5>
      <a:accent6><a:srgbClr val="FBC02D"/></a:accent6>
      <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
      <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="GenomeAnalyzer">
      <a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="GenomeAnalyzer">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="25400"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>
''';
}

class _SlideContent {
  final String title;
  final List<String> lines;
  _SlideContent({required this.title, required this.lines});
}
