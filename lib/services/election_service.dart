import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/candidate.dart';
import '../core/models/election.dart';
import '../core/models/election_result.dart';
import '../core/models/audit_log.dart';
import '../core/models/member.dart';
import '../core/security/election_visibility.dart';
import 'audit_service.dart';
import 'asistencia_service.dart';
import 'members_service.dart';
import 'auth_service.dart';
import 'dart:async';

/// Modo de elegibilidad para votación
enum EligibilityMode {
  // ignore: constant_identifier_names
  all_active_members('Todos los socios activos'),
  // ignore: constant_identifier_names
  only_attendees('Solo asistentes a evento');

  const EligibilityMode(this.displayName);
  final String displayName;

  static EligibilityMode fromString(String value) {
    switch (value.toLowerCase()) {
      case 'all_active_members':
      case 'todos':
        return EligibilityMode.all_active_members;
      case 'only_attendees':
      case 'solo_asistentes':
        return EligibilityMode.only_attendees;
      default:
        return EligibilityMode.all_active_members;
    }
  }
}

/// Documento de elección + si Firestore aún confirma caché o escrituras locales.
class ElectionLiveState {
  const ElectionLiveState({required this.election, required this.isSyncing});

  final Election? election;

  /// `true` si el snapshot viene solo de caché local o hay escrituras pendientes de confirmar.
  final bool isSyncing;
}

/// Lista de candidatos + estado de sincronización del snapshot de consulta.
class CandidatesLiveState {
  const CandidatesLiveState({
    required this.candidates,
    required this.isSyncing,
  });

  final List<Candidate> candidates;
  final bool isSyncing;
}

/// Datos de una lectura puntual para pintar la pantalla antes del primer `.snapshots()`.
class ResultsBootstrap {
  const ResultsBootstrap({required this.election, required this.candidates});

  final Election? election;
  final List<Candidate> candidates;
}

class ElectionService {
  ElectionService({FirebaseFirestore? firestore, AuditService? audit})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  /// Un listener Firestore por elección; [getCandidates] reutiliza el mismo `.map()` por id.
  final Map<String, Stream<CandidatesLiveState>> _candidatesLiveCache = {};
  final Map<String, Stream<List<Candidate>>> _candidatesListCache = {};

  Stream<List<Election>> getAllElections() {
    return _firestore
        .collection('elections')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) =>
              snap.docs.map((d) => Election.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<List<Election>> getActiveElections() {
    return _firestore
        .collection('elections')
        .where('isVisibleToVoters', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .map((d) => Election.fromMap(d.data(), d.id))
              .where(
                (e) => !e.isArchived && canVoteInElection(election: e, now: now),
              )
              .toList();
        });
  }

  /// Elecciones con [isArchived] == true (orden por [createdAt] descendente).
  Stream<List<Election>> getArchivedElections() {
    return _firestore
        .collection('elections')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => snap.docs
              .map((d) => Election.fromMap(d.data(), d.id))
              .where((e) => e.isArchived)
              .toList(),
        );
  }

  Future<void> setElectionArchived({
    required String electionId,
    required bool archived,
  }) async {
    final ref = _firestore.collection('elections').doc(electionId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (archived) {
      await ref.update({
        'isArchived': true,
        'archivedAt': nowMs,
        'updatedAt': nowMs,
      });
      await _audit.logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.election,
        entityId: electionId,
        description: 'Elección archivada',
        platform: 'flutter',
      );
    } else {
      await ref.update({
        'isArchived': false,
        'updatedAt': nowMs,
        'archivedAt': FieldValue.delete(),
      });
      await _audit.logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.election,
        entityId: electionId,
        description: 'Elección desarchivada',
        platform: 'flutter',
      );
    }
  }

  Future<Election?> getElection(String electionId) async {
    final doc = await _firestore.collection('elections').doc(electionId).get();
    return doc.exists ? Election.fromMap(doc.data()!, doc.id) : null;
  }

  /// Lectura puntual (documento + candidatos). Suele completar desde caché local aunque el stream tarde en el servidor.
  Future<ResultsBootstrap> loadResultsBootstrap(String electionId) async {
    final electionDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .get();
    final election = electionDoc.exists
        ? Election.fromMap(electionDoc.data()!, electionDoc.id)
        : null;
    if (election == null) {
      return const ResultsBootstrap(election: null, candidates: []);
    }
    final candSnap = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .orderBy('order', descending: false)
        .get();
    final candidates = candSnap.docs
        .map(
          (d) =>
              Candidate.fromMap({...d.data(), 'electionId': electionId}, d.id),
        )
        .toList();
    return ResultsBootstrap(election: election, candidates: candidates);
  }

  /// Snapshots del documento de elección con [SnapshotMetadata] para indicadores de sync.
  Stream<ElectionLiveState> watchElectionLive(String electionId) {
    return _firestore
        .collection('elections')
        .doc(electionId)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final m = snap.metadata;
          final syncing = m.isFromCache || m.hasPendingWrites;
          if (!snap.exists) {
            return const ElectionLiveState(election: null, isSyncing: false);
          }
          return ElectionLiveState(
            election: Election.fromMap(snap.data()!, snap.id),
            isSyncing: syncing,
          );
        });
  }

  Future<String> createElection(Election election) async {
    _validateElectionForWrite(election);
    final ref = _firestore.collection('elections').doc();
    final data = election.toMap()..['id'] = ref.id;
    await ref.set(data);

    // Registrar en auditoría
    await _audit.logAction(
      action: AuditAction.create,
      entityType: AuditEntityType.election,
      entityId: ref.id,
      description: 'Elección creada: ${election.title}',
      platform: 'flutter',
    );

    return ref.id;
  }

  Future<void> updateElection(Election election) async {
    _validateElectionForWrite(election);
    await _firestore
        .collection('elections')
        .doc(election.id)
        .update(election.toMap());

    // Registrar en auditoría
    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.election,
      entityId: election.id,
      description: 'Elección actualizada: ${election.title}',
      platform: 'flutter',
    );
  }

  void _validateElectionForWrite(Election election) {
    final scheduleError = validateElectionTimestampRange(
      startDate: election.startDate,
      endDate: election.endDate,
    );
    if (scheduleError != null) {
      throw ArgumentError(scheduleError);
    }
    if (election.requireAttendance &&
        (election.eventoAsistenciaId == null ||
            election.eventoAsistenciaId!.trim().isEmpty)) {
      throw ArgumentError(
        'Selecciona un evento de asistencia cuando requieras asistencia',
      );
    }
  }

  Future<void> deleteElection(String electionId) async {
    // Obtener título antes de eliminar para auditoría
    final election = await getElection(electionId);
    await _firestore.collection('elections').doc(electionId).delete();

    // Registrar en auditoría
    await _audit.logAction(
      action: AuditAction.delete,
      entityType: AuditEntityType.election,
      entityId: electionId,
      description: 'Elección eliminada: ${election?.title ?? electionId}',
      platform: 'flutter',
    );
  }

  Stream<CandidatesLiveState> watchCandidatesLive(String electionId) {
    if (_candidatesLiveCache.containsKey(electionId)) {
      return _candidatesLiveCache[electionId]!;
    }

    try {
      final stream = _firestore
          .collection('elections')
          .doc(electionId)
          .collection('candidates')
          .orderBy('order', descending: false)
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
            final syncing =
                snap.metadata.isFromCache || snap.metadata.hasPendingWrites;
            final candidates = snap.docs
                .map(
                  (d) => Candidate.fromMap({
                    ...d.data(),
                    'electionId': electionId,
                  }, d.id),
                )
                .toList();
            return CandidatesLiveState(
              candidates: candidates,
              isSyncing: syncing,
            );
          })
          .handleError((error, stackTrace) {
            debugPrint('Candidate stream error: $error');
          });

      _candidatesLiveCache[electionId] = stream;
      return stream;
    } catch (e) {
      debugPrint('Failed to create candidate stream: $e');
      rethrow;
    }
  }

  Stream<List<Candidate>> getCandidates(String electionId) {
    return _candidatesListCache.putIfAbsent(
      electionId,
      () => watchCandidatesLive(electionId).map((s) => s.candidates),
    );
  }

  Future<void> addCandidate(Candidate candidate) async {
    try {
      await _ensureUniqueCandidateName(candidate);
      final candRef = candidate.id.trim().isNotEmpty
          ? _firestore
              .collection('elections')
              .doc(candidate.electionId)
              .collection('candidates')
              .doc(candidate.id.trim())
          : _firestore
              .collection('elections')
              .doc(candidate.electionId)
              .collection('candidates')
              .doc();
      final data = candidate.toMap()..['id'] = candRef.id;
      // Ensure required fields are present
      data['electionId'] = candidate.electionId;
      // Ensure order field exists (default to 0 if not set)
      if (!data.containsKey('order')) {
        data['order'] = candidate.order;
      }
      await candRef.set(data);

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.create,
        entityType: AuditEntityType.candidate,
        entityId: candRef.id,
        description:
            'Candidato creado: ${candidate.name} (Elección: ${candidate.electionId})',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Failed to add candidate: $e');
      rethrow;
    }
  }

  Future<void> updateCandidate(Candidate candidate) async {
    await _ensureUniqueCandidateName(candidate);
    await _firestore
        .collection('elections')
        .doc(candidate.electionId)
        .collection('candidates')
        .doc(candidate.id)
        .update(candidate.toMap());

    // Registrar en auditoría
    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.candidate,
      entityId: candidate.id,
      description: 'Candidato actualizado: ${candidate.name}',
      platform: 'flutter',
    );
  }

  Future<void> _ensureUniqueCandidateName(Candidate candidate) async {
    final candidates = await _loadCandidatesOnce(candidate.electionId);
    if (hasCandidateNameConflict(
      candidate: candidate,
      existingCandidates: candidates,
    )) {
      throw ArgumentError(
        'Ya existe un candidato con ese nombre en esta elección',
      );
    }
  }

  Future<List<Candidate>> _loadCandidatesOnce(String electionId) async {
    final snapshot = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .get();
    return snapshot.docs
        .map(
          (doc) => Candidate.fromMap({
            ...doc.data(),
            'electionId': electionId,
          }, doc.id),
        )
        .toList();
  }

  Future<void> deleteCandidate(String electionId, String candidateId) async {
    // Obtener nombre del candidato antes de eliminar para auditoría
    final candidateDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .doc(candidateId)
        .get();
    final candidateData = candidateDoc.data();
    if (candidateData == null) {
      throw Exception('Candidato no encontrado');
    }

    final voteCount = (candidateData['voteCount'] as num?)?.toInt() ?? 0;
    final voteCountError = validateCandidateDeletion(voteCount: voteCount);
    if (voteCountError != null) {
      throw Exception(voteCountError);
    }

    final existingVote = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .where('candidateId', isEqualTo: candidateId)
        .limit(1)
        .get();
    final voteDocumentsError = validateCandidateDeletion(
      voteCount: voteCount,
      hasVoteDocuments: existingVote.docs.isNotEmpty,
    );
    if (voteDocumentsError != null) {
      throw Exception(voteDocumentsError);
    }

    await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .doc(candidateId)
        .delete();

    // Registrar en auditoría
    await _audit.logAction(
      action: AuditAction.delete,
      entityType: AuditEntityType.candidate,
      entityId: candidateId,
      description:
          'Candidato eliminado: ${candidateData['name'] ?? candidateId}',
      platform: 'flutter',
    );
  }
}

class VoteService {
  VoteService({FirebaseFirestore? firestore, AuditService? audit})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  /// Caché local: usuario ya votó en esta elección (bloquea al volver a entrar en la misma sesión).
  static final Map<String, Set<String>> _votedElectionsByUser =
      <String, Set<String>>{};

  static String _voteId(String electionId, String userId) =>
      '${electionId}_$userId'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  bool hasVotedLocally(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return false;
    return _votedElectionsByUser[userId]?.contains(electionId) ?? false;
  }

  void recordLocalVote(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return;
    _votedElectionsByUser.putIfAbsent(userId, () => <String>{}).add(electionId);
  }

  Stream<bool> userVotedStream(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return Stream.value(false);
    // Si ya tenemos en caché local, emitir true de inmediato y seguir escuchando Firestore
    if (hasVotedLocally(electionId, userId)) {
      return Stream.value(true).asyncExpand(
        (_) => _firestore
            .collection('elections')
            .doc(electionId)
            .collection('votes')
            .doc(_voteId(electionId, userId))
            .snapshots()
            .map((doc) => true),
      );
    }
    return _firestore
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .doc(_voteId(electionId, userId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Recalcula elegibilidad cuando cambia asistencia legacy o reporte.
  ///
  /// Cubre elecciones vinculadas tanto a `eventos/{id}` como a
  /// `attendance_events/{id}`. La validación final sigue en
  /// [isUserEligibleToVote] y se repite en [castVote].
  Stream<bool> watchUserEligibilityForElection({
    required String electionId,
    required String attendanceEventId,
    required String userId,
    required String memberId,
  }) {
    if (electionId.isEmpty ||
        attendanceEventId.isEmpty ||
        userId.isEmpty ||
        memberId.isEmpty) {
      return Stream.value(false);
    }

    late final StreamController<bool> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    var emission = 0;

    Future<void> emitEligibility() async {
      final token = ++emission;
      try {
        final isEligible = await isUserEligibleToVote(
          electionId: electionId,
          userId: userId,
          memberId: memberId,
        );
        if (!controller.isClosed && token == emission) {
          controller.add(isEligible);
        }
      } catch (e, stackTrace) {
        if (!controller.isClosed && token == emission) {
          controller.addError(e, stackTrace);
        }
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        scheduleMicrotask(emitEligibility);
        subscriptions.add(
          _firestore
              .collection('asistencias')
              .where('eventoId', isEqualTo: attendanceEventId)
              .snapshots(includeMetadataChanges: true)
              .listen((_) => emitEligibility(), onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collection('attendance_events')
              .doc(attendanceEventId)
              .collection('asistencias')
              .snapshots(includeMetadataChanges: true)
              .listen((_) => emitEligibility(), onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream.distinct();
  }

  /// Verificar si un usuario es elegible para votar en una elección
  /// ESTRATEGIA: Usa búsqueda inteligente por múltiples identificadores
  /// (workerCode, email, userId) similar a asistencia_service.dart
  Future<bool> isUserEligibleToVote({
    required String electionId,
    required String userId,
    required String memberId,
  }) async {
    try {
      // Obtener configuración de la elección
      final electionDoc = await _firestore
          .collection('elections')
          .doc(electionId)
          .get();

      if (!electionDoc.exists) {
        debugPrint('❌ Elección no encontrada: $electionId');
        return false;
      }

      final electionData = electionDoc.data()!;
      final requireAttendance =
          electionData['requireAttendance'] as bool? ?? false;

      // Si no requiere asistencia, todos los socios activos pueden votar
      if (!requireAttendance) {
        debugPrint('✅ Elección sin requisito de asistencia - Votante elegible');
        return true;
      }

      // Si requiere asistencia, verificar que tenga asistencia en el evento
      final eventoAsistenciaId = electionData['eventoAsistenciaId'] as String?;

      if (eventoAsistenciaId == null || eventoAsistenciaId.isEmpty) {
        debugPrint(
          '❌ Elección requiere asistencia pero no tiene evento configurado',
        );
        return false;
      }

      debugPrint('\n🗳️  Verificando elegibilidad para votación:');
      debugPrint('   Election: $electionId');
      debugPrint('   Evento requerido: $eventoAsistenciaId');
      debugPrint('   UserId: $userId');
      debugPrint('   MemberId recibido: $memberId');

      // ESTRATEGIA DE BÚSQUEDA INTELIGENTE:
      // Intentar múltiples identificadores (workerCode, email, userId)
      // Similar a isUserRegisteredInEvent en asistencia_service.dart

      // 1. Obtener datos completos del usuario para tener su número de empleado
      final fullUser = await AuthService().getCurrentUser();
      final employeeNum = fullUser?.employeeNumber;
      final userEmail = fullUser?.email;

      // Lista de posibles identificadores del usuario
      // PRIORIDAD: employeeNumber (workerCode) primero, luego memberId, luego userId
      final idsParaProbar = <String>[];

      if (employeeNum != null && employeeNum.isNotEmpty) {
        idsParaProbar.add(employeeNum);
        debugPrint('   📋 Agregado employeeNumber: $employeeNum');
      }

      if (memberId.isNotEmpty && !idsParaProbar.contains(memberId)) {
        idsParaProbar.add(memberId);
        debugPrint('   📋 Agregado memberId: $memberId');
      }

      if (userId.isNotEmpty && !idsParaProbar.contains(userId)) {
        idsParaProbar.add(userId);
        debugPrint('   📋 Agregado userId: $userId');
      }

      if (userEmail != null &&
          userEmail.isNotEmpty &&
          !idsParaProbar.contains(userEmail)) {
        idsParaProbar.add(userEmail);
        debugPrint('   📋 Agregado email: $userEmail');
      }

      if (idsParaProbar.isEmpty) {
        debugPrint('❌ No hay identificadores disponibles para buscar');
        return false;
      }

      debugPrint(
        '   🔍 Identificadores a probar (${idsParaProbar.length}): ${idsParaProbar.join(", ")}',
      );

      // 2. Buscar en miembros (members) por cada identificador
      final membersService = MembersService();
      for (final identifier in idsParaProbar) {
        debugPrint('   \n   🔎 Probando identifier: "$identifier"');

        final member = await membersService.getMemberByWorkerCode(identifier);
        if (member != null) {
          debugPrint('   ✅ Miembro encontrado:');
          debugPrint('      - workerCode: ${member.workerCode}');
          debugPrint('      - Nombre: ${member.fullName}');
          debugPrint('      - Status: ${member.status.displayName}');

          // Verificar estado activo
          if (member.status != MemberStatus.active) {
            debugPrint(
              '      ⚠️ Miembro no está activo (status: ${member.status.displayName})',
            );
            continue;
          }

          // Verificar si este miembro tiene asistencia registrada en el evento
          final asistenciaService = AsistenciaService();
          final persona = await asistenciaService.getPersonaPorIdentificador(
            member.workerCode!,
          );
          if (persona != null) {
            debugPrint(
              '      👤 Persona encontrada en sistema de asistencia: ${persona.id}',
            );
            final asistencia = await asistenciaService
                .getAsistenciaPorEventoYPersona(eventoAsistenciaId, persona.id);
            if (asistencia != null && asistencia.asistio == true) {
              debugPrint('      ✅ ASISTENCIA ENCONTRADA - Usuario ELEGIBLE');
              return true;
            } else {
              debugPrint(
                '      ❌ No tiene asistencia registrada en este evento',
              );
            }
          } else {
            debugPrint(
              '      ⚠️ Persona no encontrada en sistema de asistencia con workerCode: ${member.workerCode}',
            );
          }
        } else {
          debugPrint(
            '   ❌ No se encontró miembro con identifier: "$identifier"',
          );
        }
      }

      // 3. Fallback: buscar directamente en asistencias por el memberId original
      debugPrint('\n   🔄 Intentando búsqueda directa en asistencias...');
      final attendanceSnapshot = await _firestore
          .collection('attendance_events')
          .doc(eventoAsistenciaId)
          .collection('asistencias')
          .where('personaId', isEqualTo: memberId)
          .where('asistio', isEqualTo: true)
          .limit(1)
          .get();

      final hasAttendance = attendanceSnapshot.docs.isNotEmpty;

      if (hasAttendance) {
        debugPrint('   ✅ Asistencia encontrada por búsqueda directa');
        debugPrint('   🎉 Usuario ELEGIBLE para votar');
      } else {
        debugPrint('   ❌ No se encontró asistencia por búsqueda directa');
        debugPrint(
          '   💡 Sugerencia: Verificar que el socio tenga registro de asistencia en el evento $eventoAsistenciaId',
        );
      }

      return hasAttendance;
    } catch (e, stackTrace) {
      debugPrint('❌ Error verificando elegibilidad: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> castVote({
    required String electionId,
    required String userId,
    required String candidateId,
    String? memberId, // 🆕 ID del socio para validación de elegibilidad
  }) async {
    debugPrint('\n🗳️ === INICIANDO PROCESO DE VOTACIÓN ===');
    debugPrint('   Election: $electionId');
    debugPrint('   UserId: $userId');
    debugPrint('   CandidateId: $candidateId');
    debugPrint('   MemberId: ${memberId ?? "null"}');

    final electionDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .get();
    if (!electionDoc.exists) {
      throw Exception('La elección no existe.');
    }
    final election = Election.fromMap(electionDoc.data()!, electionDoc.id);
    final votingStatus = getElectionVotingStatus(election: election);
    if (votingStatus != ElectionVotingStatus.open) {
      throw Exception(electionVotingStatusMessage(votingStatus));
    }

    // 🆕 Validar elegibilidad antes de permitir el voto
    if (memberId != null && memberId.isNotEmpty) {
      debugPrint('   🔍 Validando elegibilidad...');
      try {
        final isEligible = await isUserEligibleToVote(
          electionId: electionId,
          userId: userId,
          memberId: memberId,
        );

        if (!isEligible) {
          debugPrint('   ❌ Usuario NO es elegible para votar');
          throw Exception(
            'No tienes permiso para votar en esta elección. '
            'Verifica que cumplas con los requisitos de elegibilidad.',
          );
        }
        debugPrint('   ✅ Usuario es elegible - Continuando con votación');
      } catch (e) {
        debugPrint('   ❌ Error durante validación de elegibilidad: $e');
        rethrow;
      }
    } else {
      debugPrint(
        '   ⚠️ MemberId no proporcionado - omitiendo validación de elegibilidad',
      );
    }

    final batch = _firestore.batch();
    final voteRef = _firestore
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .doc(_voteId(electionId, userId));
    final candidateRef = _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .doc(candidateId);
    final electionRef = _firestore.collection('elections').doc(electionId);

    debugPrint('   📝 Preparando batch de escritura...');

    // Registrar el voto
    batch.set(voteRef, {
      'electionId': electionId,
      'userId': userId,
      'candidateId': candidateId,
      'votedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));

    // Incrementar contadores (Batch funciona offline)
    batch.update(candidateRef, {'voteCount': FieldValue.increment(1)});
    batch.update(electionRef, {
      'totalVotes': FieldValue.increment(1),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      debugPrint('   💾 Ejecutando commit del batch...');
      debugPrint('   📊 Detalles del batch:');
      debugPrint(
        '      - Vote Ref: elections/$electionId/votes/${_voteId(electionId, userId)}',
      );
      debugPrint(
        '      - Candidate Ref: elections/$electionId/candidates/$candidateId',
      );
      debugPrint('      - Election Ref: elections/$electionId');

      await batch.commit();
      debugPrint('   ✅ Batch commit exitoso');

      // Registrar emisión de voto en auditoría (después de commit exitoso)
      debugPrint('   📋 Registrando auditoría...');
      await _audit.logAction(
        action: AuditAction.vote,
        entityType: AuditEntityType.election,
        entityId: electionId,
        description: 'Voto emitido por usuario $userId en elección $electionId',
        platform: 'flutter',
      );
      debugPrint('   ✅ Auditoría registrada');
      debugPrint('🗳️ === VOTACIÓN COMPLETADA EXITOSAMENTE ===\n');
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error al ejecutar batch: $e');
      debugPrint('   Stack trace: $stackTrace');

      // Clasificar el tipo de error
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('permission-denied') ||
          errorMsg.contains('permission')) {
        debugPrint('   🔒 ERROR DE PERMISOS - Verifica firestore.rules');
        debugPrint(
          '   💡 Posible causa: Las reglas no permiten esta operación',
        );
      } else if (errorMsg.contains('not-found') ||
          errorMsg.contains('does not exist')) {
        debugPrint(
          '   🔍 DOCUMENTO NO ENCONTRADO - Verifica que la elección y candidato existan',
        );
        debugPrint('   💡 Posible causa: electionId o candidateId incorrectos');
      } else if (errorMsg.contains('already') || errorMsg.contains('exists')) {
        debugPrint('   ⚠️ El voto ya existe - tratando como éxito');
        debugPrint('🗳️ === VOTO YA REGISTRADO (DUPLICADO) ===\n');
        return; // No relanzar, tratar como éxito
      }

      debugPrint('🗳️ === ERROR EN VOTACIÓN ===\n');
      rethrow;
    }
  }

  Future<ElectionResults?> getElectionResults(String electionId) async {
    final electionDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .get();
    if (!electionDoc.exists) return null;

    final totalVotes =
        (electionDoc.data()?['totalVotes'] as num?)?.toInt() ?? 0;
    final candidatesSnap = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .orderBy('voteCount', descending: true)
        .get();

    final results = candidatesSnap.docs.asMap().entries.map((entry) {
      final data = {...entry.value.data(), 'electionId': electionId};
      final c = Candidate.fromMap(data, entry.value.id);
      return ElectionResultItem(
        candidateId: c.id,
        candidateName: c.name,
        candidateImageUrl: c.imageUrl,
        voteCount: c.voteCount,
        rank: entry.key + 1,
      );
    }).toList();

    return ElectionResults(
      electionId: electionId,
      results: results,
      totalVotes: totalVotes,
    );
  }
}
