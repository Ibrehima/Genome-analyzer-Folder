import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/connectivity_service.dart';
import 'services/storage_service.dart';
import 'utils/app_theme.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const GenomeAnalyzerApp());
}

class GenomeAnalyzerApp extends StatelessWidget {
  const GenomeAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..loadFromDisk()),
        ChangeNotifierProvider(
          create: (_) => ConnectivityService()..startPeriodicChecks(),
        ),
      ],
      child: MaterialApp(
        title: 'Genome Analyzer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const MainShell(),
      ),
    );
  }
}
