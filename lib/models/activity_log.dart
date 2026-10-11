import 'package:uuid/uuid.dart';

/// A single recorded user action, used to power the super-admin statistics
/// dashboard ("see every activity performed on Genome Analyzer").
class ActivityLogEntry {
  final String id;
  final String userId;
  final String userEmail;
  final String module;
  final String action;
  final DateTime timestamp;

  ActivityLogEntry({
    String? id,
    required this.userId,
    required this.userEmail,
    required this.module,
    required this.action,
    DateTime? timestamp,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userEmail': userEmail,
    'module': module,
    'action': action,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) => ActivityLogEntry(
    id: json['id'] as String?,
    userId: (json['userId'] as String?) ?? '',
    userEmail: (json['userEmail'] as String?) ?? '',
    module: (json['module'] as String?) ?? '',
    action: (json['action'] as String?) ?? '',
    timestamp: json['timestamp'] != null
        ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
        : DateTime.now(),
  );
}
