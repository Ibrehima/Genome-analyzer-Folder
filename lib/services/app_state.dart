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
  List<Project> _projects = [];
  String _activeProjectId = Project.defaultId;
  bool _loaded = false;
  // Home-dashboard module tile density, persisted across sessions — lets
  // users on desktop/tablet screens re-size module icons/tiles as requested.
  String _iconDensity = 'comfortable'; // 'compact' | 'comfortable' | 'large'

  /// All sequences across every project (used rarely — prefer
  /// [sequencesInActiveProject] for normal module usage so that processing
  /// never leaks across project boundaries).
  List<BioSequence> get sequences => List.unmodifiable(_sequences);
  List<ReportHistoryItem> get reportHistory => List.unmodifiable(_reportHistory);
  List<SequenceAnnotation> get annotations => List.unmodifiable(_annotations);
  bool get isLoaded => _loaded;
  String get iconDensity => _iconDensity;

  List<Project> get projects => List.unmodifiable(_projects);
  String get activeProjectId => _activeProjectId;
  Project get activeProject => _projects.firstWhere(
    (p) => p.id == _activeProjectId,
    orElse: () =>
        _projects.isNotEmpty ? _projects.first : Project(id: Project.defaultId, name: 'General'),
  );

  /// Sequences belonging only to the currently active project — this is
  /// what every analysis module should use, so work on one project's data
  /// never impacts another project's sequences.
  List<BioSequence> get sequencesInActiveProject =>
      List.unmodifiable(_sequences.where((s) => s.projectId == _activeProjectId));

  List<SequenceAnnotation> annotationsFor(String sequenceId) =>
      _annotations.where((a) => a.sequenceId == sequenceId).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  Future<void> loadFromDisk() async {
    _sequences = StorageService.loadAllSequences();
    _reportHistory = await StorageService.loadReportHistory();
    _annotations = StorageService.loadAllAnnotations();
    _projects = StorageService.loadAllProjects();
    if (_projects.isEmpty) {
      final def = Project(id: Project.defaultId, name: 'General');
      _projects = [def];
      await StorageService.saveProject(def);
    }
    _activeProjectId = await StorageService.getSetting('active_project_id') ?? _projects.first.id;
    if (!_projects.any((p) => p.id == _activeProjectId)) {
      _activeProjectId = _projects.first.id;
    }
    _iconDensity = await StorageService.getSetting('icon_density') ?? 'comfortable';
    _loaded = true;
    notifyListeners();
  }

  // ---------------- Projects ----------------
  Future<Project> createProject(
    String name, {
    String description = '',
    int colorValue = 0xFF1565C0,
  }) async {
    final p = Project(
      name: name.trim().isEmpty ? 'Untitled project' : name.trim(),
      description: description,
      colorValue: colorValue,
    );
    _projects.add(p);
    await StorageService.saveProject(p);
    notifyListeners();
    return p;
  }

  Future<void> renameProject(String id, String name, {String? description}) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _projects[idx].name = name.trim().isEmpty ? _projects[idx].name : name.trim();
    if (description != null) _projects[idx].description = description;
    await StorageService.saveProject(_projects[idx]);
    notifyListeners();
  }

  /// Deletes a project and every sequence that belongs to it (sequences in
  /// other projects are untouched). The default project can't be deleted.
  Future<void> deleteProject(String id) async {
    if (id == Project.defaultId) return;
    final toRemove = _sequences.where((s) => s.projectId == id).toList();
    for (final s in toRemove) {
      _sequences.remove(s);
      await StorageService.deleteSequence(s.id);
    }
    _projects.removeWhere((p) => p.id == id);
    await StorageService.deleteProject(id);
    if (_activeProjectId == id) {
      _activeProjectId = _projects.isNotEmpty ? _projects.first.id : Project.defaultId;
      await StorageService.setSetting('active_project_id', _activeProjectId);
    }
    notifyListeners();
  }

  Future<void> setActiveProject(String id) async {
    _activeProjectId = id;
    await StorageService.setSetting('active_project_id', id);
    notifyListeners();
  }

  int sequenceCountFor(String projectId) =>
      _sequences.where((s) => s.projectId == projectId).length;

  /// Moves a sequence into a different project (e.g. "send assembled contig
  /// to Project X"), without affecting any other sequence.
  Future<void> moveSequenceToProject(String sequenceId, String projectId) async {
    final idx = _sequences.indexWhere((s) => s.id == sequenceId);
    if (idx < 0) return;
    _sequences[idx].projectId = projectId;
    await StorageService.saveSequence(_sequences[idx]);
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
    final countToday = _sequences.where((s) => s.labCode.startsWith(prefix)).length;
    final index = countToday + 1;
    return '$prefix${index.toString().padLeft(3, '0')}';
  }

  Future<void> addSequence(BioSequence seq, {String? projectId}) async {
    if (seq.labCode.isEmpty) {
      seq.labCode = _generateLabCode(seq);
    }
    seq.projectId = projectId ?? seq.projectId;
    _sequences.insert(0, seq);
    await StorageService.saveSequence(seq);
    notifyListeners();
  }

  /// Adds a batch of sequences. If [projectId] is omitted, each sequence
  /// keeps its own [BioSequence.projectId] (defaulting to the active
  /// project is the caller's responsibility when constructing them) —
  /// callers that don't care should pass the active project explicitly.
  Future<void> addSequences(List<BioSequence> seqs, {String? projectId}) async {
    for (final s in seqs) {
      if (s.labCode.isEmpty) {
        s.labCode = _generateLabCode(s);
      }
      if (projectId != null) s.projectId = projectId;
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
