/// Reglas puras para validar elegibilidad antes de emitir un voto.
class VoteEligibilityPolicy {
  const VoteEligibilityPolicy._();

  /// Devuelve mensaje de error si el voto no puede proceder; `null` si es válido.
  static String? memberIdRequiredMessage({
    required bool requireAttendance,
    String? memberId,
  }) {
    if (!requireAttendance) return null;

    final canonical = memberId?.trim();
    if (canonical == null || canonical.isEmpty) {
      return 'Tu cuenta no está vinculada al padrón de socios. '
          'Contacta al administrador o completa tu perfil antes de votar.';
    }
    return null;
  }
}

/// Usuario deshabilitado en Firestore (`users.isActive == false`).
class AccountInactiveException implements Exception {
  AccountInactiveException([
    this.message =
        'Tu cuenta está desactivada. Contacta al administrador del sindicato.',
  ]);

  final String message;

  @override
  String toString() => message;
}
