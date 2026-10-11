import 'package:uuid/uuid.dart';
import '../engines/export/report_data.dart';

/// A saved result from the "Smart Workflow" (sequential multi-analysis
/// launcher): the user picks a sequence + a checklist of analyses, Genome
/// Analyzer runs them one after another, and the combined output is stored
/// here — tied to the owning account (via [ownerId]/[ownerEmail]) so it
/// shows up in "My Results" whenever that user opens their account. The
/// super-administrator can see every user's results on this installation
/// (see AdminDashboardScreen / AuthService honesty note).
class WorkflowResultRecord {
  final String id;
  final String ownerId;
  final String ownerEmail;
  final String sequenceName;
  final List<String> taskLabels;
  final DateTime createdAt;
  final ReportData reportData;

  WorkflowResultRecord({
    String? id,
    required this.ownerId,
    required this.ownerEmail,
    required this.sequenceName,
    required this.taskLabels,
    DateTime? createdAt,
    required this.reportData,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'ownerEmail': ownerEmail,
    'sequenceName': sequenceName,
    'taskLabels': taskLabels,
    'createdAt': createdAt.toIso8601String(),
    'reportData': reportData.toJson(),
  };

  factory WorkflowResultRecord.fromJson(Map<String, dynamic> json) => WorkflowResultRecord(
    id: json['id'] as String?,
    ownerId: json['ownerId'] as String? ?? '',
    ownerEmail: json['ownerEmail'] as String? ?? '',
    sequenceName: json['sequenceName'] as String? ?? '',
    taskLabels: (json['taskLabels'] as List?)?.map((e) => e.toString()).toList() ?? [],
    createdAt: json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
        : DateTime.now(),
    reportData: ReportData.fromJson(Map<String, dynamic>.from(json['reportData'] as Map? ?? {})),
  );
}
