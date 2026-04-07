/// Rol del usuario (compatible con backend Android/Firestore).
enum UserRole {
  superadmin('SUPERADMIN'),
  admin('ADMIN'),
  operadorAsistencia('OPERADOR_ASISTENCIA'),
  voter('VOTER'),
  user('USER');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String v) {
    return UserRole.values.firstWhere(
      (e) => e.value == v.toUpperCase(),
      orElse: () => UserRole.user,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.superadmin:
        return 'Super Administrador';
      case UserRole.admin:
        return 'Administrador';
      case UserRole.operadorAsistencia:
        return 'Operador Asistencia';
      case UserRole.voter:
        return 'Votante';
      case UserRole.user:
        return 'Usuario';
    }
  }
}
