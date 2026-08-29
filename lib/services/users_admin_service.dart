import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/models/audit_log.dart';
import '../core/models/member.dart';
import '../core/models/user.dart';
import '../core/models/user_role.dart';
import '../core/security/voter_member_policy.dart';
import 'audit_service.dart';

/// Resultado paginado del listado administrativo de usuarios.
class UsersPage {
  const UsersPage({
    required this.users,
    required this.lastDocument,
    required this.hasMore,
    required this.rawCount,
  });

  final List<AppUser> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
  final int rawCount;
}

/// Excepción de negocio para operaciones de administración de usuarios.
class UsersAdminException implements Exception {
  UsersAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reglas puras reutilizables en tests para cambios sensibles de usuarios.
class UsersAdminPolicy {
  const UsersAdminPolicy._();

  static void ensureCanChangeRole({
    required String actorUserId,
    required String targetUserId,
    required UserRole newRole,
    required int activeSuperAdminCount,
    required UserRole currentTargetRole,
  }) {
    if (actorUserId == targetUserId) {
      throw UsersAdminException('No puedes cambiar tu propio rol.');
    }

    if (currentTargetRole == UserRole.superadmin &&
        newRole != UserRole.superadmin &&
        activeSuperAdminCount <= 1) {
      throw UsersAdminException(
        'No se puede quitar el rol al único superadministrador activo.',
      );
    }
  }

  static void ensureCanChangeActive({
    required String actorUserId,
    required String targetUserId,
    required bool newActive,
    required UserRole targetRole,
    required int activeSuperAdminCount,
  }) {
    if (actorUserId == targetUserId && !newActive) {
      throw UsersAdminException('No puedes desactivar tu propia cuenta.');
    }

    if (!newActive &&
        targetRole == UserRole.superadmin &&
        activeSuperAdminCount <= 1) {
      throw UsersAdminException(
        'No se puede desactivar al único superadministrador activo.',
      );
    }
  }

  /// Valida vinculación defensiva socio ↔ usuario (lógica pura, testeable).
  static void ensureCanLinkMember({
    required UserRole targetRole,
    required MemberStatus memberStatus,
    required String memberId,
    String? existingOwnerUserId,
    required String targetUserId,
  }) {
    try {
      VoterMemberPolicy.ensureCanLinkMember(
        targetRole: targetRole,
        memberStatus: memberStatus,
        memberId: memberId,
        existingOwnerUserId: existingOwnerUserId,
        targetUserId: targetUserId,
      );
    } on VoterMemberPolicyException catch (error) {
      throw UsersAdminException(error.message);
    }
  }
}

/// Resultado de invitación/creación de usuario por superadmin.
class UserInviteResult {
  const UserInviteResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.emailSent,
    this.temporaryPassword,
  });

  final String uid;
  final String email;
  final UserRole role;
  final bool emailSent;
  final String? temporaryPassword;
}

/// Resultado del envío de recuperación de contraseña por superadmin.
class AdminPasswordResetResult {
  const AdminPasswordResetResult({required this.email, required this.message});

  final String email;
  final String message;
}

/// Servicio de administración de usuarios (solo superadmin en UI y reglas).
class UsersAdminService {
  UsersAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditService? audit,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditService _audit;

  static const String _adminInviteEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/admin-invite-user';
  static const String _adminPasswordResetEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/admin-send-password-reset';
  static const String _adminSearchUsersEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/admin-search-users';
  static const String _adminSearchMembersEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/admin-search-members';

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  String get _actorUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw UsersAdminException('Sesión no válida para administrar usuarios.');
    }
    return uid;
  }

  AppUser _userFromMap(Map<String, dynamic> data, String id) {
    return AppUser.fromMap(data, id);
  }

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw UsersAdminException('Usuario no encontrado.');
    }
    return _userFromMap(data, doc.id);
  }

  Future<Map<String, dynamic>> _postSuperAdminApi({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw UsersAdminException('Sesión no válida.');
    }

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload?['message'] as String? ??
          'No se pudo completar la operación administrativa.';
      throw UsersAdminException(message);
    }

    return payload ?? <String, dynamic>{};
  }

  /// Cuenta superadmins activos (para evitar dejar el sistema sin administrador).
  Future<int> countActiveSuperAdmins() async {
    final snapshot = await _usersCol
        .where('role', isEqualTo: UserRole.superadmin.value)
        .get();
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return data['isActive'] as bool? ?? true;
    }).length;
  }

  Future<AppUser?> getUserById(String userId) async {
    if (userId.isEmpty) return null;
    final doc = await _usersCol.doc(userId).get();
    if (!doc.exists) return null;
    return _userFromDoc(doc);
  }

  /// Página de usuarios ordenada por email.
  Future<UsersPage> fetchUsersPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    UserRole? roleFilter,
    bool? activeFilter,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _usersCol.orderBy('email');

    if (roleFilter != null) {
      query = query.where('role', isEqualTo: roleFilter.value);
    } else if (activeFilter != null) {
      query = query.where('isActive', isEqualTo: activeFilter);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    var users = snapshot.docs.map(_userFromDoc).toList();

    if (roleFilter != null && activeFilter != null) {
      users = users.where((user) => user.isActive == activeFilter).toList();
    }

    return UsersPage(
      users: users,
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length >= limit,
      rawCount: snapshot.docs.length,
    );
  }

  /// Búsqueda por prefijo de email (Firestore range query).
  Future<List<AppUser>> searchUsersByEmailPrefix(
    String queryText, {
    int limit = 40,
  }) async {
    final normalized = queryText.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final end = '$normalized\uf8ff';
    final snapshot = await _usersCol
        .orderBy('email')
        .startAt([normalized])
        .endAt([end])
        .limit(limit)
        .get();

    return snapshot.docs.map(_userFromDoc).toList();
  }

  /// Búsqueda unificada vía Cloud Function (superadmin).
  Future<List<AppUser>> searchUsers(String queryText, {int limit = 40}) async {
    final q = queryText.trim();
    if (q.isEmpty) return [];

    final payload = await _postSuperAdminApi(
      endpoint: _adminSearchUsersEndpoint,
      body: {'query': q, 'limit': limit},
    );

    final rawUsers = payload['users'] as List<dynamic>? ?? const [];
    return rawUsers
        .whereType<Map<String, dynamic>>()
        .map((data) => _userFromMap(data, data['id'] as String? ?? ''))
        .where((user) => user.id.isNotEmpty)
        .toList();
  }

  /// Busca socios por nombre, número o código (superadmin, vía backend).
  Future<List<Member>> searchMembersForLink(
    String queryText, {
    int limit = 20,
  }) async {
    final q = queryText.trim();
    if (q.isEmpty) return [];

    final payload = await _postSuperAdminApi(
      endpoint: _adminSearchMembersEndpoint,
      body: {'query': q, 'limit': limit},
    );

    final rawMembers = payload['members'] as List<dynamic>? ?? const [];
    return rawMembers
        .whereType<Map<String, dynamic>>()
        .map((data) {
          final id = data['id'] as String? ?? '';
          return Member.fromMap(data, id);
        })
        .where((member) => member.id.isNotEmpty)
        .toList();
  }

  Future<void> updateUserRole({
    required String targetUserId,
    required UserRole newRole,
  }) async {
    final actorId = _actorUserId;
    final target = await getUserById(targetUserId);
    if (target == null) {
      throw UsersAdminException('Usuario no encontrado.');
    }

    if (target.role == newRole) return;

    final activeSuperAdmins = await countActiveSuperAdmins();
    UsersAdminPolicy.ensureCanChangeRole(
      actorUserId: actorId,
      targetUserId: targetUserId,
      newRole: newRole,
      activeSuperAdminCount: activeSuperAdmins,
      currentTargetRole: target.role,
    );

    await _usersCol.doc(targetUserId).update({
      'role': newRole.value,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.user,
      entityId: targetUserId,
      changes: {
        'role': {'before': target.role.value, 'after': newRole.value},
      },
      description:
          'Cambio de rol: ${target.role.displayName} → ${newRole.displayName}. '
          'La sesión del usuario se renovará automáticamente.',
    );
  }

  Future<void> setUserActive({
    required String targetUserId,
    required bool isActive,
  }) async {
    final actorId = _actorUserId;
    final target = await getUserById(targetUserId);
    if (target == null) {
      throw UsersAdminException('Usuario no encontrado.');
    }

    if (target.isActive == isActive) return;

    final activeSuperAdmins = await countActiveSuperAdmins();
    UsersAdminPolicy.ensureCanChangeActive(
      actorUserId: actorId,
      targetUserId: targetUserId,
      newActive: isActive,
      targetRole: target.role,
      activeSuperAdminCount: activeSuperAdmins,
    );

    await _usersCol.doc(targetUserId).update({
      'isActive': isActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.user,
      entityId: targetUserId,
      changes: {
        'isActive': {'before': target.isActive, 'after': isActive},
      },
      description: isActive
          ? 'Usuario reactivado en Firestore y Firebase Auth'
          : 'Usuario desactivado; sesión revocada en Firebase Auth',
    );
  }

  /// Vincula un socio del padrón al documento `users/{uid}`.
  Future<void> linkMemberToUser({
    required String targetUserId,
    required String memberId,
  }) async {
    if (memberId.trim().isEmpty) {
      throw UsersAdminException('Debe seleccionar un socio del padrón.');
    }

    final target = await getUserById(targetUserId);
    if (target == null) {
      throw UsersAdminException('Usuario no encontrado.');
    }

    final memberDoc = await _firestore
        .collection('members')
        .doc(memberId.trim())
        .get();
    if (!memberDoc.exists) {
      throw UsersAdminException(
        'El socio seleccionado no existe en el padrón.',
      );
    }

    final member = Member.fromMap(memberDoc.data()!, memberDoc.id);

    final duplicateQuery = await _usersCol
        .where('memberId', isEqualTo: member.id)
        .limit(2)
        .get();
    String? existingOwnerUserId;
    for (final doc in duplicateQuery.docs) {
      if (doc.id != targetUserId) {
        existingOwnerUserId = doc.id;
        break;
      }
    }

    UsersAdminPolicy.ensureCanLinkMember(
      targetRole: target.role,
      memberStatus: member.status,
      memberId: member.id,
      existingOwnerUserId: existingOwnerUserId,
      targetUserId: targetUserId,
    );

    final workerCode = member.workerCode?.trim();

    final updates = <String, dynamic>{
      'memberId': member.id,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (workerCode != null && workerCode.isNotEmpty) {
      updates['employeeNumber'] = workerCode;
    }

    await _usersCol.doc(targetUserId).update(updates);

    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.user,
      entityId: targetUserId,
      changes: {
        'memberId': {'before': target.memberId, 'after': member.id},
        if (workerCode != null && workerCode.isNotEmpty)
          'employeeNumber': {
            'before': target.employeeNumber,
            'after': workerCode,
          },
      },
      description:
          'Vinculación con socio ${member.fullName} (${member.memberNumber})',
    );
  }

  Future<void> unlinkMemberFromUser(String targetUserId) async {
    final target = await getUserById(targetUserId);
    if (target == null) {
      throw UsersAdminException('Usuario no encontrado.');
    }

    if (target.memberId == null || target.memberId!.trim().isEmpty) {
      return;
    }

    await _usersCol.doc(targetUserId).update({
      'memberId': null,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.user,
      entityId: targetUserId,
      changes: {
        'memberId': {'before': target.memberId, 'after': null},
      },
      description: 'Desvinculación del padrón de socios',
    );

    debugPrint(
      'Usuario $targetUserId desvinculado del socio ${target.memberId}',
    );
  }

  /// Crea una cuenta real en Firebase Auth + Firestore (solo superadmin vía backend).
  Future<UserInviteResult> inviteUser({
    required String email,
    required UserRole role,
    String? displayName,
    String? employeeNumber,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw UsersAdminException('Sesión no válida para invitar usuarios.');
    }

    final response = await http
        .post(
          Uri.parse(_adminInviteEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'email': email.trim(),
            'role': role.value,
            if (displayName != null && displayName.trim().isNotEmpty)
              'displayName': displayName.trim(),
            if (employeeNumber != null && employeeNumber.trim().isNotEmpty)
              'employeeNumber': employeeNumber.trim(),
          }),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload?['message'] as String? ??
          'No se pudo crear la cuenta. Código ${response.statusCode}.';
      throw UsersAdminException(message);
    }

    final uid = payload?['uid'] as String? ?? '';
    final invitedEmail = payload?['email'] as String? ?? email.trim();
    final invitedRole = UserRole.fromString(
      payload?['role'] as String? ?? role.value,
    );
    final emailSent = payload?['emailSent'] as bool? ?? false;
    final temporaryPassword = payload?['temporaryPassword'] as String?;

    return UserInviteResult(
      uid: uid,
      email: invitedEmail,
      role: invitedRole,
      emailSent: emailSent,
      temporaryPassword: temporaryPassword,
    );
  }

  /// Envía enlace seguro de recuperación de contraseña al correo del usuario.
  Future<AdminPasswordResetResult> sendPasswordResetToUser({
    required String targetUserId,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw UsersAdminException('Sesión no válida.');
    }

    final response = await http
        .post(
          Uri.parse(_adminPasswordResetEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'targetUserId': targetUserId}),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload?['message'] as String? ??
          'No se pudo enviar la recuperación de contraseña.';
      throw UsersAdminException(message);
    }

    return AdminPasswordResetResult(
      email: payload?['email'] as String? ?? '',
      message:
          payload?['message'] as String? ??
          'Se envió el enlace de recuperación.',
    );
  }
}
