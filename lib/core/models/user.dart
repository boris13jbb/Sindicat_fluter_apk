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
    this.gender,
    this.avatarUrl,
    this.avatarMode,
    this.phoneNumber,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final String? employeeNumber;
  final String? memberId;
  final int? createdAt;
  /// `male` | `female` | `neutral` u omitido; usado para avatar por defecto.
  final String? gender;
  /// URL de foto personalizada (Storage) cuando [avatarMode] es `custom`.
  final String? avatarUrl;
  /// `custom` | `default_male` | `default_female` | `default_neutral`.
  final String? avatarMode;
  /// Teléfono de contacto del usuario (Firestore `phoneNumber`), editable por el propio usuario.
  final String? phoneNumber;

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
      gender: map['gender'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      avatarMode: map['avatarMode'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
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
    String? gender,
    String? avatarUrl,
    String? avatarMode,
    String? phoneNumber,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt ?? this.createdAt,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarMode: avatarMode ?? this.avatarMode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'employeeNumber': employeeNumber,
      'memberId': memberId,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    };
    if (gender != null) map['gender'] = gender;
    if (avatarUrl != null) map['avatarUrl'] = avatarUrl;
    if (avatarMode != null) map['avatarMode'] = avatarMode;
    if (phoneNumber != null) map['phoneNumber'] = phoneNumber;
    return map;
  }
}
