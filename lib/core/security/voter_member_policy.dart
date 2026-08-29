import '../models/member.dart';
import '../models/user_role.dart';

/// Reglas puras para vinculación socio-usuario y elegibilidad electoral de VOTER.
class VoterMemberPolicy {
  const VoterMemberPolicy._();

  /// Un socio existe y está activo para fines electorales.
  static bool isMemberActiveForVoting(MemberStatus? status) {
    return status == MemberStatus.active;
  }

  /// Evalúa elegibilidad electoral base (socio activo) y asistencia opcional.
  static bool evaluateElectionEligibility({
    required bool memberExists,
    required MemberStatus? memberStatus,
    required bool requireAttendance,
    required bool hasAttendance,
  }) {
    if (!memberExists || !isMemberActiveForVoting(memberStatus)) {
      return false;
    }
    if (!requireAttendance) {
      return true;
    }
    return hasAttendance;
  }

  /// Valida si un `memberId` puede vincularse a un usuario según rol y estado.
  static void ensureCanLinkMember({
    required UserRole targetRole,
    required MemberStatus memberStatus,
    required String memberId,
    String? existingOwnerUserId,
    required String targetUserId,
  }) {
    if (memberId.trim().isEmpty) {
      throw VoterMemberPolicyException('Debe seleccionar un socio del padrón.');
    }

    final owner = existingOwnerUserId?.trim();
    if (owner != null && owner.isNotEmpty && owner != targetUserId) {
      throw VoterMemberPolicyException(
        'Este socio ya está vinculado a otro usuario.',
      );
    }

    if (targetRole == UserRole.voter && memberStatus != MemberStatus.active) {
      throw VoterMemberPolicyException(
        'No se puede vincular un usuario votante a un socio inactivo.',
      );
    }
  }
}

/// Excepción de negocio para reglas de vinculación socio-usuario.
class VoterMemberPolicyException implements Exception {
  VoterMemberPolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}
