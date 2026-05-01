import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
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

  /// CSV alineado a la importación (columna `modalidad` con código A, B, C, …).
  static String buildMembersExportCsv(List<Member> members) {
    const converter = ListToCsvConverter();
    final rows = <List<dynamic>>[
      [
        'numero_socio',
        'nombres',
        'apellidos',
        'worker_code',
        'modalidad',
        'documento',
        'email',
        'telefono',
        'estado',
      ],
    ];
    for (final m in members) {
      rows.add([
        m.memberNumber,
        m.firstName,
        m.lastName,
        m.workerCode ?? '',
        m.modalidad?.value ?? '',
        m.documentId ?? '',
        m.email ?? '',
        m.phone ?? '',
        m.status.displayName,
      ]);
    }
    return converter.convert(rows);
  }

  void _ensureModalidadObligatoria(Member member) {
    if (member.modalidad == null) {
      throw Exception(
        'La modalidad del socio es obligatoria. Seleccione un turno válido (A–Z/N1/N2).',
      );
    }
  }

  /// Obtener stream de todos los socios
  Stream<List<Member>> getAllMembers({
    MemberStatus? status,
    String? searchQuery,
  }) {
    debugPrint(
      '📊 MembersService: getAllMembers() llamado - status filter: $status',
    );

    Query query = _firestore.collection('members');

    // Nota: No aplicamos where ni orderBy en Firestore para evitar índices compuestos
    // El filtrado y ordenamiento se hacen en cliente para mayor flexibilidad

    return query
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '📦 Snapshot recibido: ${snapshot.docs.length} documentos totales',
          );

          // Mostrar diagnóstico de los primeros documentos si hay muchos
          if (snapshot.docs.isNotEmpty) {
            debugPrint('   📋 Muestra de miembros (primeros 3):');
            final sampleSize = snapshot.docs.length < 3
                ? snapshot.docs.length
                : 3;
            for (var i = 0; i < sampleSize; i++) {
              final doc = snapshot.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final statusValue = data['status'];
              final fullName = data['fullName'] ?? data['firstName'] ?? 'N/A';

              if (statusValue == null) {
                debugPrint('      [$i] $fullName - ⚠️ status: AUSENTE');
              } else {
                debugPrint('      [$i] $fullName - status: "$statusValue"');
              }
            }

            // Contar únicos valores de status
            final statusCounts = <String, int>{};
            for (final doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final statusValue = data['status']?.toString() ?? 'AUSENTE';
              statusCounts[statusValue] = (statusCounts[statusValue] ?? 0) + 1;
            }

            debugPrint('   📊 Distribución de status en Firestore:');
            statusCounts.forEach((statusVal, total) {
              debugPrint('      - "$statusVal": $total miembros');
            });
          }

          return snapshot.docs
              .map(
                (doc) =>
                    Member.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();
        })
        .map((members) {
          // Filtrado en cliente por estado
          if (status != null) {
            final beforeFilter = members.length;
            members = members.where((m) => m.status == status).toList();
            final afterFilter = members.length;
            debugPrint(
              '   🔽 Filtrado por status=${status.name}: $beforeFilter → $afterFilter miembros',
            );

            // Si no hay resultados pero sí había miembros, explicar por qué
            if (afterFilter == 0 && beforeFilter > 0) {
              debugPrint(
                '   ⚠️ ADVERTENCIA: Se encontraron $beforeFilter miembros pero NINGUNO tiene status="${status.name}"',
              );
              debugPrint(
                '   💡 SOLUCIÓN: Actualiza el campo status en Firestore a "${status.name}" o re-importa los socios',
              );
            }
          }

          // Ordenamiento en cliente por apellido y nombre
          members.sort((a, b) {
            final lastNameCompare = a.lastName.toLowerCase().compareTo(
              b.lastName.toLowerCase(),
            );
            if (lastNameCompare != 0) return lastNameCompare;
            return a.firstName.toLowerCase().compareTo(
              b.firstName.toLowerCase(),
            );
          });

          // Filtrado en cliente por búsqueda
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            members = members.where((m) {
              return m.fullName.toLowerCase().contains(query) ||
                  m.memberNumber.toLowerCase().contains(query) ||
                  (m.workerCode?.toLowerCase().contains(query) ?? false) ||
                  (m.documentId?.toLowerCase().contains(query) ?? false) ||
                  (m.email?.toLowerCase().contains(query) ?? false);
            }).toList();
          }

          debugPrint('✅ Members procesados: ${members.length}');
          return members;
        });
  }

  /// Obtener stream de socios activos
  Stream<List<Member>> getActiveMembers() {
    debugPrint('\n🔍 MembersService: getActiveMembers() llamado');
    debugPrint('   Filtrando por status: MemberStatus.active');
    debugPrint('   Valor esperado en Firestore: "${MemberStatus.active.name}"');
    return getAllMembers(status: MemberStatus.active);
  }

  /// Obtener un socio específico por ID
  Future<Member?> getMemberById(String memberId) async {
    try {
      final doc = await _firestore.collection('members').doc(memberId).get();
      if (!doc.exists) return null;
      return Member.fromMap(doc.data()!, doc.id);
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

  /// Buscar socios por workerCode (Número de Trabajador) - CLAVE PRINCIPAL para asistencia
  Future<Member?> getMemberByWorkerCode(String workerCode) async {
    try {
      if (workerCode.isEmpty) return null;

      final snapshot = await _firestore
          .collection('members')
          .where('workerCode', isEqualTo: workerCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Member.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('Error buscando socio por workerCode: $e');
      return null;
    }
  }

  bool _isDifferentMember(Member? existingMember, String? excludingId) {
    return existingMember != null && existingMember.id != excludingId;
  }

  Future<void> _ensureUniqueMemberFields(
    Member member, {
    String? excludingId,
  }) async {
    final existingMember = await getMemberByNumber(member.memberNumber);
    if (_isDifferentMember(existingMember, excludingId)) {
      throw Exception(
        'Ya existe un socio con el número ${member.memberNumber}',
      );
    }

    final documentId = member.documentId?.trim();
    if (documentId != null && documentId.isNotEmpty) {
      final existingByDoc = await getMemberByDocument(documentId);
      if (_isDifferentMember(existingByDoc, excludingId)) {
        throw Exception('Ya existe un socio con el documento $documentId');
      }
    }

    final workerCode = member.workerCode?.trim();
    if (workerCode != null && workerCode.isNotEmpty) {
      final existingByWorkerCode = await getMemberByWorkerCode(workerCode);
      if (_isDifferentMember(existingByWorkerCode, excludingId)) {
        throw Exception(
          'Ya existe un socio con el código de trabajador $workerCode',
        );
      }
    }
  }

  /// Crear un nuevo socio
  Future<String> createMember(Member member) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      await _ensureUniqueMemberFields(member);
      _ensureModalidadObligatoria(member);

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
        final oldMod = oldMember.modalidad?.value;
        final newMod = member.modalidad?.value;
        if (oldMod != newMod) {
          changes['modalidad'] = {'before': oldMod, 'after': newMod};
        }
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
        if (oldMember.memberNumber != member.memberNumber) {
          changes['memberNumber'] = {
            'before': oldMember.memberNumber,
            'after': member.memberNumber,
          };
        }
        if (oldMember.workerCode != member.workerCode) {
          changes['workerCode'] = {
            'before': oldMember.workerCode,
            'after': member.workerCode,
          };
        }
        if (oldMember.documentId != member.documentId) {
          changes['documentId'] = {
            'before': oldMember.documentId,
            'after': member.documentId,
          };
        }
      }

      await _ensureUniqueMemberFields(member, excludingId: member.id);
      _ensureModalidadObligatoria(member);

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
