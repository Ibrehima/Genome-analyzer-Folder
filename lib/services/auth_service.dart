import 'package:flutter/foundation.dart';
import '../models/user_account.dart';
import '../models/activity_log.dart';
import 'storage_service.dart';

/// Authentication / access-control state shared across the whole app via
/// Provider. Access to Genome Analyzer is fully conditioned on having a
/// local account (see [currentUser]); the super-administrator account
/// (guindo50@gmail.com) is automatically promoted to [UserRole.superAdmin]
/// on registration or login and can view every recorded activity plus
/// aggregate statistics (see AdminDashboardScreen).
///
/// HONESTY NOTE: there is no cloud/Firebase backend configured for this
/// build, so accounts & the activity log are stored locally (Hive) on this
/// device/browser only. The super-admin dashboard therefore reflects every
/// account & activity recorded on *this* installation, not a true
/// cross-device view of every user of the app. If a multi-device shared
/// view is required, a backend (e.g. Firebase) must be configured.
class AuthService extends ChangeNotifier {
  UserAccount? _currentUser;
  List<UserAccount> _allUsers = [];
  List<ActivityLogEntry> _activityLog = [];
  bool _loaded = false;

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  bool get isLoaded => _loaded;
  List<UserAccount> get allUsers => List.unmodifiable(_allUsers);
  List<ActivityLogEntry> get activityLog => List.unmodifiable(_activityLog);

  static const String _sessionKey = 'current_user_id';

  Future<void> loadFromDisk() async {
    _allUsers = StorageService.loadAllUsers();
    _activityLog = StorageService.loadAllActivity();
    final sessionId = await StorageService.getSetting(_sessionKey);
    if (sessionId != null) {
      try {
        _currentUser = _allUsers.firstWhere((u) => u.id == sessionId);
      } catch (_) {
        _currentUser = null;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Returns an error message (French, shown directly in the UI) or null on
  /// success.
  Future<String?> register({
    required String email,
    required String password,
    required String country,
    required String city,
    required String institution,
    required OccupationType occupation,
    required String specialty,
    required String phoneNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return 'Adresse e-mail invalide.';
    }
    if (password.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    if (StorageService.findUserByEmail(normalizedEmail) != null) {
      return 'Un compte existe déjà avec cette adresse e-mail.';
    }
    final user = UserAccount(
      email: normalizedEmail,
      passwordHash: UserAccount.hashPassword(password),
      country: country.trim(),
      city: city.trim(),
      institution: institution.trim(),
      occupation: occupation,
      specialty: specialty.trim(),
      phoneNumber: phoneNumber.trim(),
    );
    await StorageService.saveUser(user);
    _allUsers.add(user);
    _currentUser = user;
    await StorageService.setSetting(_sessionKey, user.id);
    await logActivity(module: 'Compte', action: 'Inscription');
    notifyListeners();
    return null;
  }

  /// Returns an error message (French) or null on success.
  Future<String?> login({required String email, required String password}) async {
    final user = StorageService.findUserByEmail(email);
    if (user == null) {
      return 'Aucun compte trouvé avec cette adresse e-mail.';
    }
    if (!user.checkPassword(password)) {
      return 'Mot de passe incorrect.';
    }
    _currentUser = user;
    await StorageService.setSetting(_sessionKey, user.id);
    notifyListeners();
    await logActivity(module: 'Compte', action: 'Connexion');
    return null;
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      await logActivity(module: 'Compte', action: 'Déconnexion');
    }
    _currentUser = null;
    await StorageService.setSetting(_sessionKey, '');
    notifyListeners();
  }

  /// Records a usage event (which module, what action, by whom) so the
  /// super-admin dashboard can show real activity statistics.
  Future<void> logActivity({required String module, required String action}) async {
    if (_currentUser == null) return;
    final entry = ActivityLogEntry(
      userId: _currentUser!.id,
      userEmail: _currentUser!.email,
      module: module,
      action: action,
    );
    _activityLog.insert(0, entry);
    await StorageService.logActivity(entry);
    notifyListeners();
  }

  /// Refreshes the in-memory user & activity lists from disk (used by the
  /// admin dashboard to pick up the latest data before building charts).
  void refreshAdminData() {
    _allUsers = StorageService.loadAllUsers();
    _activityLog = StorageService.loadAllActivity();
    notifyListeners();
  }
}
