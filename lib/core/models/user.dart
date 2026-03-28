import 'user_role.dart';

/// Usuario del sistema (compatible con Firestore users).
/// Se llama AppUser para no chocar con firebase_auth.User.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    required this.employeeNumber,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final String employeeNumber;
  final int? createdAt;

  factory AppUser.fromMap(Map<String, dynamic> map, [String? id]) {
    final uid = id ?? map['id'] as String? ?? '';
    return AppUser(
      id: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      role: UserRole.fromString((map['role'] as String?) ?? 'VOTER'),
      employeeNumber: map['employeeNumber'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'employeeNumber': employeeNumber,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    };
  }
}
