import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../main_shell.dart';
import 'login_screen.dart';

/// Root gate: shows the login screen until a local account is signed in,
/// then reveals the full app ([MainShell]). This conditions ALL access to
/// Genome Analyzer on having created an account, as requested.
class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    return const MainShell();
  }
}
