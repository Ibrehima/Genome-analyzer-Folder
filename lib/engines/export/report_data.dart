/// Generic report content model shared by all export engines (PDF, Word,
/// PowerPoint, Excel) so that any analysis module can produce a document
/// through a single unified interface.
class ReportSection {
  final String title;
  final String? bodyText;
  final List<String>? bullets;
  final List<List<String>>? table; // first row = header

  ReportSection({this.title = '', this.bodyText, this.bullets, this.table});
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
}
