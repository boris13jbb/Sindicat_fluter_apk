/// Rol del usuario (compatible con backend Android/Firestore).
enum UserRole {
  admin('ADMIN'),
  voter('VOTER');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String v) {
    return UserRole.values.firstWhere(
      (e) => e.value == v.toUpperCase(),
      orElse: () => UserRole.voter,
    );
  }

  String get displayName => value == 'ADMIN' ? 'Administrador' : 'Votante';
}
