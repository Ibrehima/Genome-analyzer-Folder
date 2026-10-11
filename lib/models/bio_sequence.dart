import 'package:uuid/uuid.dart';

/// A project is an isolated "folder" of sequences: every [BioSequence] is
/// tagged with a [Project.id] via [BioSequence.projectId], so work done in
/// one project (imports, trimming, assembly, alignment...) never mixes with
/// or affects the data of another project. A default "General" project is
/// auto-created on first launch so existing/ungrouped sequences always have
/// a home.
class Project {
  final String id;
  String name;
  String description;
  final DateTime createdAt;
  // A small accent color (ARGB int) so projects are visually distinguishable
  // in pickers/switchers — purely cosmetic, stored as a plain int for Hive.
  int colorValue;

  Project({
    String? id,
    required this.name,
    this.description = '',
    DateTime? createdAt,
    this.colorValue = 0xFF1565C0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Fixed id for the always-present default project.
  static const String defaultId = 'default';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'colorValue': colorValue,
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Project',
    description: json['description'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    colorValue: json['colorValue'] as int? ?? 0xFF1565C0,
  );
}

/// Type of biological sequence
enum SequenceType { dna, rna, protein, unknown }

extension SequenceTypeLabel on SequenceType {
  String get label {
    switch (this) {
      case SequenceType.dna:
        return 'DNA';
      case SequenceType.rna:
        return 'RNA';
      case SequenceType.protein:
        return 'Protein';
      case SequenceType.unknown:
        return 'Unknown';
    }
  }

  String get shortCode {
    switch (this) {
      case SequenceType.dna:
        return 'DNA';
      case SequenceType.rna:
        return 'RNA';
      case SequenceType.protein:
        return 'PRT';
      case SequenceType.unknown:
        return 'UNK';
    }
  }
}

/// Core representation of a biological sequence (FASTA or FASTQ derived)
class BioSequence {
  final String id;
  String name;
  String description;
  SequenceType type;
  String sequence; // uppercase raw letters (no whitespace)
  List<int>? qualityScores; // Phred quality per base (FASTQ only)
  final DateTime dateAdded;
  String source; // 'upload', 'manual', 'online:NCBI', 'generated', 'sample'
  List<String> tags;

  /// Auto-generated lab reference code, e.g. "DNA-20260801-003".
  /// Numbered by type + date of import, so the library stays organized
  /// and traceable even with hundreds of entries.
  String labCode;

  /// Which [Project] this sequence belongs to — isolates working sets so
  /// that processing sequences in one project never impacts another.
  /// Defaults to [Project.defaultId] for backward-compatible data.
  String projectId;

  BioSequence({
    String? id,
    required this.name,
    this.description = '',
    required this.type,
    required this.sequence,
    this.qualityScores,
    DateTime? dateAdded,
    this.source = 'manual',
    List<String>? tags,
    String? labCode,
    String? projectId,
  }) : id = id ?? const Uuid().v4(),
       dateAdded = dateAdded ?? DateTime.now(),
       tags = tags ?? [],
       labCode = labCode ?? '',
       projectId = projectId ?? Project.defaultId;

  int get length => sequence.length;

  bool get hasQuality => qualityScores != null && qualityScores!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'sequence': sequence,
    'qualityScores': qualityScores,
    'dateAdded': dateAdded.toIso8601String(),
    'source': source,
    'tags': tags,
    'labCode': labCode,
    'projectId': projectId,
  };

  factory BioSequence.fromJson(Map<String, dynamic> json) => BioSequence(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Unnamed',
    description: json['description'] as String? ?? '',
    type: SequenceType.values.firstWhere(
      (e) => e.name == (json['type'] as String? ?? 'unknown'),
      orElse: () => SequenceType.unknown,
    ),
    sequence: json['sequence'] as String? ?? '',
    qualityScores: (json['qualityScores'] as List?)?.cast<int>(),
    dateAdded: json['dateAdded'] != null
        ? DateTime.tryParse(json['dateAdded'] as String) ?? DateTime.now()
        : DateTime.now(),
    source: json['source'] as String? ?? 'manual',
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    labCode: json['labCode'] as String? ?? '',
    projectId: json['projectId'] as String? ?? Project.defaultId,
  );

  BioSequence copyWith({
    String? name,
    String? description,
    SequenceType? type,
    String? sequence,
    List<int>? qualityScores,
    String? source,
    List<String>? tags,
    String? labCode,
    String? projectId,
  }) {
    return BioSequence(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      sequence: sequence ?? this.sequence,
      qualityScores: qualityScores ?? this.qualityScores,
      dateAdded: dateAdded,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      labCode: labCode ?? this.labCode,
      projectId: projectId ?? this.projectId,
    );
  }
}
