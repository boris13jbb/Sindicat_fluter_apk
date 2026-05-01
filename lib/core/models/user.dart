import 'user_role.dart';

/// Usuario del sistema (compatible con Firestore users).
/// Se llama AppUser para no chocar con firebase_auth.User.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.employeeNumber,
    this.memberId,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final String? employeeNumber;
  final String? memberId;
  final int? createdAt;

  factory AppUser.fromMap(Map<String, dynamic> map, [String? id]) {
    final uid = id ?? map['id'] as String? ?? '';
    return AppUser(
      id: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      role: UserRole.fromString((map['role'] as String?) ?? 'VOTER'),
      employeeNumber: map['employeeNumber'] as String?,
      memberId: map['memberId'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt(),
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    String? employeeNumber,
    String? memberId,
    int? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'employeeNumber': employeeNumber,
      'memberId': memberId,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    };
  }
}
