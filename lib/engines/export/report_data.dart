/// Generic report content model shared by all export engines (PDF, Word,
/// PowerPoint, Excel) so that any analysis module can produce a document
/// through a single unified interface.
class ReportSection {
  final String title;
  final String? bodyText;
  final List<String>? bullets;
  final List<List<String>>? table; // first row = header

  ReportSection({this.title = '', this.bodyText, this.bullets, this.table});

  Map<String, dynamic> toJson() => {
    'title': title,
    'bodyText': bodyText,
    'bullets': bullets,
    'table': table,
  };

  factory ReportSection.fromJson(Map<String, dynamic> json) => ReportSection(
    title: json['title'] as String? ?? '',
    bodyText: json['bodyText'] as String?,
    bullets: (json['bullets'] as List?)?.map((e) => e.toString()).toList(),
    table: (json['table'] as List?)
        ?.map((row) => (row as List).map((c) => c.toString()).toList())
        .toList(),
  );
}

class ReportData {
  final String title;
  final String subtitle;
  final DateTime generatedAt;
  final List<ReportSection> sections;

  ReportData({
    required this.title,
    this.subtitle = '',
    DateTime? generatedAt,
    List<ReportSection>? sections,
  }) : generatedAt = generatedAt ?? DateTime.now(),
       sections = sections ?? [];

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'generatedAt': generatedAt.toIso8601String(),
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    generatedAt: json['generatedAt'] != null
        ? (DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now())
        : DateTime.now(),
    sections: (json['sections'] as List? ?? [])
        .map((e) => ReportSection.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
