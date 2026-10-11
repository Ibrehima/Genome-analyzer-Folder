// Basic smoke test for Genome Analyzer.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genome_analyzer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AuthService.loadFromDisk() reads a session key via
    // StorageService.getSetting(), which goes through SharedPreferences —
    // without this mock, getInstance() waits on a platform channel that
    // never responds in the test environment and the pump loop hangs.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds without crashing and shows the login gate', (WidgetTester tester) async {
    await tester.pumpWidget(const GenomeAnalyzerApp());
    // Avoid pumpAndSettle here: ConnectivityService schedules a periodic
    // network-check timer that never "settles". A few manual pumps are
    // enough to let StorageService/AuthService finish their async loads.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Access is now gated behind authentication: an unauthenticated launch
    // should show the login screen rather than the home dashboard.
    expect(find.text('Genome Analyzer'), findsWidgets);
    expect(find.text('Se connecter'), findsWidgets);
  });
}
