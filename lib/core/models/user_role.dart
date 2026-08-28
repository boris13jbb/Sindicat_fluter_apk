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

  /// Descripción operativa mostrada al asignar roles.
  String get assignmentDescription {
    switch (this) {
      case UserRole.superadmin:
        return 'Control total: usuarios, configuración global y todos los módulos.';
      case UserRole.admin:
        return 'Gestiona elecciones, socios, auditoría y asistencia.';
      case UserRole.operadorAsistencia:
        return 'Opera eventos, registros y reportes de asistencia.';
      case UserRole.voter:
        return 'Participa en votaciones y consulta su perfil.';
      case UserRole.user:
        return 'Acceso básico sin privilegios administrativos.';
    }
  }

  /// Roles que un superadmin puede asignar desde la app.
  static const assignableBySuperAdmin = UserRole.values;
}
