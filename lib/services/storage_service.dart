import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import '../models/user_account.dart';
import '../models/activity_log.dart';

/// Local persistence layer. Uses Hive for the sequence library (structured
/// documents) and shared_preferences for lightweight settings & report
/// history metadata.
class StorageService {
  static const String _sequenceBoxName = 'sequences_box';
  static const String _annotationBoxName = 'annotations_box';
  static const String _projectBoxName = 'projects_box';
  static const String _userBoxName = 'users_box';
  static const String _activityBoxName = 'activity_log_box';
  static Box? _sequenceBox;
  static Box? _annotationBox;
  static Box? _projectBox;
  static Box? _userBox;
  static Box? _activityBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _sequenceBox = await Hive.openBox(_sequenceBoxName);
    _annotationBox = await Hive.openBox(_annotationBoxName);
    _projectBox = await Hive.openBox(_projectBoxName);
    _userBox = await Hive.openBox(_userBoxName);
    _activityBox = await Hive.openBox(_activityBoxName);
  }

  // ---------------- User Accounts ----------------
  static Future<void> saveUser(UserAccount u) async {
    await _userBox?.put(u.id, u.toJson());
  }

  static Future<void> deleteUser(String id) async {
    await _userBox?.delete(id);
  }

  static List<UserAccount> loadAllUsers() {
    if (_userBox == null) return [];
    final List<UserAccount> result = [];
    for (final key in _userBox!.keys) {
      final raw = _userBox!.get(key);
      if (raw is Map) {
        try {
          result.add(UserAccount.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip corrupted entry
        }
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  static UserAccount? findUserByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final u in loadAllUsers()) {
      if (u.email.trim().toLowerCase() == normalized) return u;
    }
    return null;
  }

  // ---------------- Activity Log ----------------
  static Future<void> logActivity(ActivityLogEntry entry) async {
    await _activityBox?.put(entry.id, entry.toJson());
  }

  static List<ActivityLogEntry> loadAllActivity() {
    if (_activityBox == null) return [];
    final List<ActivityLogEntry> result = [];
    for (final key in _activityBox!.keys) {
      final raw = _activityBox!.get(key);
      if (raw is Map) {
        try {
          result.add(ActivityLogEntry.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip corrupted entry
        }
      }
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  static Future<void> clearActivityLog() async {
    await _activityBox?.clear();
  }

  // ---------------- Projects ----------------
  static Future<void> saveProject(Project p) async {
    await _projectBox?.put(p.id, p.toJson());
  }

  static Future<void> deleteProject(String id) async {
    await _projectBox?.delete(id);
  }

  static List<Project> loadAllProjects() {
    if (_projectBox == null) return [];
    final List<Project> result = [];
    for (final key in _projectBox!.keys) {
      final raw = _projectBox!.get(key);
      if (raw is Map) {
        try {
          result.add(Project.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip corrupted entry
        }
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  // ---------------- Sequence Annotations ----------------
  static Future<void> saveAnnotation(SequenceAnnotation a) async {
    await _annotationBox?.put(a.id, a.toJson());
  }

  static Future<void> deleteAnnotation(String id) async {
    await _annotationBox?.delete(id);
  }

  static List<SequenceAnnotation> loadAllAnnotations() {
    if (_annotationBox == null) return [];
    final List<SequenceAnnotation> result = [];
    for (final key in _annotationBox!.keys) {
      final raw = _annotationBox!.get(key);
      if (raw is Map) {
        try {
          result.add(SequenceAnnotation.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip corrupted entry
        }
      }
    }
    return result;
  }

  // ---------------- Sequence Library ----------------
  static Future<void> saveSequence(BioSequence seq) async {
    await _sequenceBox?.put(seq.id, seq.toJson());
  }

  static Future<void> deleteSequence(String id) async {
    await _sequenceBox?.delete(id);
  }

  static List<BioSequence> loadAllSequences() {
    if (_sequenceBox == null) return [];
    final List<BioSequence> result = [];
    for (final key in _sequenceBox!.keys) {
      final raw = _sequenceBox!.get(key);
      if (raw is Map) {
        try {
          result.add(BioSequence.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip corrupted entry
        }
      }
    }
    result.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return result;
  }

  static Future<void> clearAllSequences() async {
    await _sequenceBox?.clear();
  }

  // ---------------- Report History ----------------
  static const String _reportHistoryKey = 'report_history_v1';

  static Future<List<ReportHistoryItem>> loadReportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_reportHistoryKey) ?? [];
    return raw
        .map((s) {
          try {
            return ReportHistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ReportHistoryItem>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> addReportHistory(ReportHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_reportHistoryKey) ?? [];
    raw.add(jsonEncode(item.toJson()));
    // Keep only the most recent 100 entries
    final trimmed = raw.length > 100 ? raw.sublist(raw.length - 100) : raw;
    await prefs.setStringList(_reportHistoryKey, trimmed);
  }

  static Future<void> clearReportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reportHistoryKey);
  }

  // ---------------- Settings ----------------
  static Future<void> setSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
