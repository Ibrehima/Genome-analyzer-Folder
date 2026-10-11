import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Occupation status collected at registration.
enum OccupationType { professional, student }

/// Application-level role. `superAdmin` is reserved for the hardcoded
/// super-administrator account (guindo50@gmail.com) and is never assigned
/// through the normal registration flow.
enum UserRole { user, superAdmin }

/// Email address of the one and only super-administrator account.
/// This account automatically receives [UserRole.superAdmin] privileges
/// (full activity visibility + statistics dashboard) regardless of how
/// it was registered.
const String kSuperAdminEmail = 'guindo50@gmail.com';

/// A registered Genome Analyzer user account. Access to the whole app is
/// conditioned on having one of these created locally (device/browser
/// storage via Hive — see the HONESTY NOTE in [AuthService] about the
/// absence of a cloud backend in this build).
class UserAccount {
  final String id;
  final String email;
  final String passwordHash;
  final String country;
  final String city;
  final String institution;
  final OccupationType occupation;
  final String specialty;
  final String phoneNumber;
  final UserRole role;
  final DateTime createdAt;

  UserAccount({
    String? id,
    required this.email,
    required this.passwordHash,
    required this.country,
    required this.city,
    required this.institution,
    required this.occupation,
    required this.specialty,
    required this.phoneNumber,
    UserRole? role,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       role = role ?? (email.trim().toLowerCase() == kSuperAdminEmail ? UserRole.superAdmin : UserRole.user),
       createdAt = createdAt ?? DateTime.now();

  bool get isSuperAdmin =>
      role == UserRole.superAdmin || email.trim().toLowerCase() == kSuperAdminEmail;

  static String hashPassword(String plain) {
    final bytes = utf8.encode(plain);
    return sha256.convert(bytes).toString();
  }

  bool checkPassword(String plain) => passwordHash == hashPassword(plain);

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'passwordHash': passwordHash,
    'country': country,
    'city': city,
    'institution': institution,
    'occupation': occupation.name,
    'specialty': specialty,
    'phoneNumber': phoneNumber,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'] as String?,
    email: (json['email'] as String?) ?? '',
    passwordHash: (json['passwordHash'] as String?) ?? '',
    country: (json['country'] as String?) ?? '',
    city: (json['city'] as String?) ?? '',
    institution: (json['institution'] as String?) ?? '',
    occupation: OccupationType.values.firstWhere(
      (o) => o.name == json['occupation'],
      orElse: () => OccupationType.professional,
    ),
    specialty: (json['specialty'] as String?) ?? '',
    phoneNumber: (json['phoneNumber'] as String?) ?? '',
    role: UserRole.values.firstWhere((r) => r.name == json['role'], orElse: () => UserRole.user),
    createdAt: json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
        : DateTime.now(),
  );
}
