import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/bio_sequence.dart';
import '../models/analysis_models.dart';
import 'storage_service.dart';

/// Central application state shared across all screens via Provider.
class AppState extends ChangeNotifier {
  List<BioSequence> _sequences = [];
  List<ReportHistoryItem> _reportHistory = [];
  List<SequenceAnnotation> _annotations = [];
  bool _loaded = false;
  // Home-dashboard module tile density, persisted across sessions — lets
  // users on desktop/tablet screens re-size module icons/tiles as requested.
  String _iconDensity = 'comfortable'; // 'compact' | 'comfortable' | 'large'

  List<BioSequence> get sequences => List.unmodifiable(_sequences);
  List<ReportHistoryItem> get reportHistory =>
      List.unmodifiable(_reportHistory);
  List<SequenceAnnotation> get annotations => List.unmodifiable(_annotations);
  bool get isLoaded => _loaded;
  String get iconDensity => _iconDensity;

  List<SequenceAnnotation> annotationsFor(String sequenceId) =>
      _annotations.where((a) => a.sequenceId == sequenceId).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  Future<void> loadFromDisk() async {
    _sequences = StorageService.loadAllSequences();
    _reportHistory = await StorageService.loadReportHistory();
    _annotations = StorageService.loadAllAnnotations();
    _iconDensity =
        await StorageService.getSetting('icon_density') ?? 'comfortable';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setIconDensity(String density) async {
    _iconDensity = density;
    await StorageService.setSetting('icon_density', density);
    notifyListeners();
  }

  Future<void> addAnnotation(SequenceAnnotation a) async {
    _annotations.add(a);
    await StorageService.saveAnnotation(a);
    notifyListeners();
  }

  Future<void> removeAnnotation(String id) async {
    _annotations.removeWhere((a) => a.id == id);
    await StorageService.deleteAnnotation(id);
    notifyListeners();
  }

  /// Generates an auto-numbered lab reference code such as
  /// "DNA-20260801-003": type + import date + running index for that
  /// type/date combination, so the library stays organized and traceable.
  String _generateLabCode(BioSequence seq) {
    final datePart = DateFormat('yyyyMMdd').format(seq.dateAdded);
    final typeCode = seq.type.shortCode;
    final prefix = '$typeCode-$datePart-';
    final countToday = _sequences
        .where((s) => s.labCode.startsWith(prefix))
        .length;
    final index = countToday + 1;
    return '$prefix${index.toString().padLeft(3, '0')}';
  }

  Future<void> addSequence(BioSequence seq) async {
    if (seq.labCode.isEmpty) {
      seq.labCode = _generateLabCode(seq);
    }
    _sequences.insert(0, seq);
    await StorageService.saveSequence(seq);
    notifyListeners();
  }

  Future<void> addSequences(List<BioSequence> seqs) async {
    for (final s in seqs) {
      if (s.labCode.isEmpty) {
        s.labCode = _generateLabCode(s);
      }
      _sequences.insert(0, s);
      await StorageService.saveSequence(s);
    }
    notifyListeners();
  }

  Future<void> removeSequence(String id) async {
    _sequences.removeWhere((s) => s.id == id);
    await StorageService.deleteSequence(id);
    notifyListeners();
  }

  Future<void> updateSequence(BioSequence seq) async {
    final idx = _sequences.indexWhere((s) => s.id == seq.id);
    if (idx >= 0) {
      _sequences[idx] = seq;
      await StorageService.saveSequence(seq);
      notifyListeners();
    }
  }

  BioSequence? getSequenceById(String id) {
    try {
      return _sequences.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordReport(ReportHistoryItem item) async {
    _reportHistory.insert(0, item);
    await StorageService.addReportHistory(item);
    notifyListeners();
  }

  Future<void> clearSequenceLibrary() async {
    _sequences.clear();
    await StorageService.clearAllSequences();
    notifyListeners();
  }
}
