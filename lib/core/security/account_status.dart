import '../models/member.dart';

import 'voter_member_policy.dart';

/// Reglas puras para validar elegibilidad antes de emitir un voto.
class VoteEligibilityPolicy {
  const VoteEligibilityPolicy._();

  /// Devuelve mensaje de error si falta `memberId`; `null` si está presente.
  static String? memberIdRequiredMessage({String? memberId}) {
    final canonical = memberId?.trim();
    if (canonical == null || canonical.isEmpty) {
      return 'Tu cuenta no está vinculada al padrón de socios. '
          'Contacta al administrador o completa tu perfil antes de votar.';
    }
    return null;
  }

  /// Devuelve mensaje de error si el socio vinculado no es elegible; `null` si ok.
  static String? memberActiveRequiredMessage({
    required bool memberExists,
    MemberStatus? memberStatus,
  }) {
    if (!memberExists) {
      return 'El socio vinculado a tu cuenta no existe en el padrón. '
          'Contacta al administrador.';
    }
    if (!VoterMemberPolicy.isMemberActiveForVoting(memberStatus)) {
      return 'El socio vinculado a tu cuenta no está activo. '
          'Contacta al administrador del sindicato.';
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
