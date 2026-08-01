import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lightweight connectivity monitor. Since no native connectivity plugin is
/// used, availability is inferred by attempting a fast HTTP request to a
/// highly-available public endpoint.
class ConnectivityService extends ChangeNotifier {
  bool _isOnline = false;
  bool _checking = false;
  DateTime? _lastChecked;

  bool get isOnline => _isOnline;
  bool get isChecking => _checking;
  DateTime? get lastChecked => _lastChecked;

  ConnectivityService() {
    checkNow();
  }

  Future<bool> checkNow() async {
    _checking = true;
    notifyListeners();
    bool online = false;
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.gbif.org/v1/species/match?name=Homo%20sapiens',
            ),
          )
          .timeout(const Duration(seconds: 5));
      online = response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      online = false;
    }
    _isOnline = online;
    _checking = false;
    _lastChecked = DateTime.now();
    notifyListeners();
    return online;
  }

  Timer? _periodicTimer;

  void startPeriodicChecks({Duration interval = const Duration(minutes: 2)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => checkNow());
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
