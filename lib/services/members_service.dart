import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/models/member.dart';
import '../core/models/audit_log.dart';
import 'audit_service.dart';

/// Servicio para gestión de socios/miembros de la organización
class MembersService {
  MembersService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditService? audit,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditService _audit;

  /// Obtener stream de todos los socios
  Stream<List<Member>> getAllMembers({
    MemberStatus? status,
    String? searchQuery,
  }) {
    Query query = _firestore.collection('members');

    // Nota: No aplicamos where en Firestore para evitar índices compuestos
    // El filtrado se hace en cliente para mayor flexibilidad

    return query
        .orderBy('lastName', descending: false)
        .orderBy('firstName', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Member.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList(),
        )
        .map((members) {
          // Filtrado en cliente por estado
          if (status != null) {
            members = members.where((m) => m.status == status).toList();
          }
          // Filtrado en cliente por búsqueda
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            members = members.where((m) {
              return m.fullName.toLowerCase().contains(query) ||
                  m.memberNumber.toLowerCase().contains(query) ||
                  (m.documentId?.toLowerCase().contains(query) ?? false) ||
                  (m.email?.toLowerCase().contains(query) ?? false);
            }).toList();
          }
          return members;
        });
  }

  /// Obtener stream de socios activos
  Stream<List<Member>> getActiveMembers() {
    return getAllMembers(status: MemberStatus.active);
  }

  /// Obtener un socio específico por ID
  Future<Member?> getMemberById(String memberId) async {
    try {
      final doc = await _firestore.collection('members').doc(memberId).get();
      if (!doc.exists) return null;
      return Member.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('Error obteniendo socio: $e');
      return null;
    }
  }

  /// Buscar socios por número de socio
  Future<Member?> getMemberByNumber(String memberNumber) async {
    try {
      final snapshot = await _firestore
          .collection('members')
          .where('memberNumber', isEqualTo: memberNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Member.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('Error buscando socio por número: $e');
      return null;
    }
  }

  /// Buscar socios por documento/cédula
  Future<Member?> getMemberByDocument(String documentId) async {
    try {
      final snapshot = await _firestore
          .collection('members')
          .where('documentId', isEqualTo: documentId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Member.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('Error buscando socio por documento: $e');
      return null;
    }
  }

  /// Crear un nuevo socio
  Future<String> createMember(Member member) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que no exista un socio con el mismo número
      final existingMember = await getMemberByNumber(member.memberNumber);
      if (existingMember != null) {
        throw Exception(
          'Ya existe un socio con el número ${member.memberNumber}',
        );
      }

      // Verificar duplicado por documento si existe
      if (member.documentId != null && member.documentId!.isNotEmpty) {
        final existingByDoc = await getMemberByDocument(member.documentId!);
        if (existingByDoc != null) {
          throw Exception(
            'Ya existe un socio con el documento ${member.documentId}',
          );
        }
      }

      final memberRef = _firestore.collection('members').doc();
      final newMember = member.copyWith(
        id: memberRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
      );

      await memberRef.set(newMember.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.create,
        entityType: AuditEntityType.member,
        entityId: memberRef.id,
        description:
            'Socio creado: ${newMember.fullName} (${newMember.memberNumber})',
        platform: 'flutter',
      );

      return memberRef.id;
    } catch (e) {
      debugPrint('Error creando socio: $e');
      rethrow;
    }
  }

  /// Actualizar un socio existente
  Future<void> updateMember(Member member) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener datos anteriores para auditoría
      final oldMember = await getMemberById(member.id);
      final changes = <String, dynamic>{};

      if (oldMember != null) {
        if (oldMember.status != member.status) {
          changes['status'] = {
            'before': oldMember.status.name,
            'after': member.status.name,
          };
        }
        if (oldMember.firstName != member.firstName) {
          changes['firstName'] = {
            'before': oldMember.firstName,
            'after': member.firstName,
          };
        }
        if (oldMember.lastName != member.lastName) {
          changes['lastName'] = {
            'before': oldMember.lastName,
            'after': member.lastName,
          };
        }
      }

      final updatedMember = member.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection('members')
          .doc(member.id)
          .update(updatedMember.toMap());

      // Registrar en auditoría si hubo cambios
      if (changes.isNotEmpty) {
        await _audit.logAction(
          action: AuditAction.update,
          entityType: AuditEntityType.member,
          entityId: member.id,
          changes: changes,
          description: 'Socio actualizado: ${member.fullName}',
          platform: 'flutter',
        );
      }
    } catch (e) {
      debugPrint('Error actualizando socio: $e');
      rethrow;
    }
  }

  /// Desactivar un socio (soft delete)
  Future<void> deactivateMember(String memberId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final member = await getMemberById(memberId);
      if (member == null) {
        throw Exception('Socio no encontrado');
      }

      final updatedMember = member.copyWith(
        status: MemberStatus.inactive,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('members')
          .doc(memberId)
          .update(updatedMember.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.member,
        entityId: memberId,
        description: 'Socio desactivado: ${member.fullName}',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error desactivando socio: $e');
      rethrow;
    }
  }

  /// Reactivar un socio
  Future<void> reactivateMember(String memberId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final member = await getMemberById(memberId);
      if (member == null) {
        throw Exception('Socio no encontrado');
      }

      final updatedMember = member.copyWith(
        status: MemberStatus.active,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('members')
          .doc(memberId)
          .update(updatedMember.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.member,
        entityId: memberId,
        description: 'Socio reactivado: ${member.fullName}',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error reactivando socio: $e');
      rethrow;
    }
  }

  /// Eliminar un socio permanentemente (solo superadmin)
  Future<void> deleteMember(String memberId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final member = await getMemberById(memberId);
      if (member == null) {
        throw Exception('Socio no encontrado');
      }

      await _firestore.collection('members').doc(memberId).delete();

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.delete,
        entityType: AuditEntityType.member,
        entityId: memberId,
        description: 'Socio eliminado permanentemente: ${member.fullName}',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error eliminando socio: $e');
      rethrow;
    }
  }

  /// Obtener contador de socios por estado
  Future<Map<String, int>> getMembersCount() async {
    try {
      final activeSnapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: MemberStatus.active.name)
          .count()
          .get();

      final inactiveSnapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: MemberStatus.inactive.name)
          .count()
          .get();

      return {
        'active': activeSnapshot.count ?? 0,
        'inactive': inactiveSnapshot.count ?? 0,
        'total': (activeSnapshot.count ?? 0) + (inactiveSnapshot.count ?? 0),
      };
    } catch (e) {
      debugPrint('Error obteniendo contadores: $e');
      return {'active': 0, 'inactive': 0, 'total': 0};
    }
  }

  /// Verificar si un socio existe por número
  Future<bool> memberNumberExists(String memberNumber) async {
    final member = await getMemberByNumber(memberNumber);
    return member != null;
  }

  /// Buscar socios (búsqueda en cliente)
  Future<List<Member>> searchMembers(String query) async {
    if (query.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: MemberStatus.active.name)
          .get();

      final queryLower = query.toLowerCase();
      return snapshot.docs
          .map((doc) => Member.fromMap(doc.data(), doc.id))
          .where(
            (member) =>
                member.fullName.toLowerCase().contains(queryLower) ||
                member.memberNumber.toLowerCase().contains(queryLower) ||
                (member.documentId?.toLowerCase().contains(queryLower) ??
                    false) ||
                (member.email?.toLowerCase().contains(queryLower) ?? false),
          )
          .toList();
    } catch (e) {
      debugPrint('Error buscando socios: $e');
      return [];
    }
  }
}
