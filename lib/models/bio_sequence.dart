import 'package:uuid/uuid.dart';

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
  }) : id = id ?? const Uuid().v4(),
       dateAdded = dateAdded ?? DateTime.now(),
       tags = tags ?? [],
       labCode = labCode ?? '';

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
    );
  }
}
