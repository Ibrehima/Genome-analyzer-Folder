// Basic smoke test for Genome Analyzer.
import 'package:flutter_test/flutter_test.dart';

import 'package:genome_analyzer/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const GenomeAnalyzerApp());
    await tester.pump();
    expect(find.text('Genome Analyzer'), findsWidgets);
  });
}
