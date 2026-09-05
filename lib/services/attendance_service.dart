import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models/asistencia/asistencia.dart';
import '../core/models/asistencia/attendance_report_models.dart';
import '../core/models/member.dart';
import '../core/models/audit_log.dart';
import 'audit_service.dart';
import 'secure_attendance_qr_service.dart';

export '../core/models/asistencia/attendance_event.dart';
export '../core/models/asistencia/attendance_report_models.dart';
export '../core/models/asistencia/member_attendance_summary.dart';

/// Hard-delete blocked because the event still has attendance subdocs.
class AttendanceEventHasRecordsException implements Exception {
  AttendanceEventHasRecordsException([
    this.message =
        'No se puede eliminar este evento porque ya contiene registros '
        'de asistencia. Archívalo para conservar el historial.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Backend refused hard-delete (role, App Check, or concurrent records).
class AttendanceEventDeleteException implements Exception {
  AttendanceEventDeleteException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'AttendanceEventDeleteException($code)';
}

/// Legacy event without confirmed `asistenciaCount` — fail-closed for writes.
class AttendanceLegacyCountException implements Exception {
  AttendanceLegacyCountException([
    this.message =
        'Este evento legacy no tiene asistenciaCount confirmado. '
        'No se puede registrar asistencia hasta un backfill controlado.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class _AttendanceReportEvent {
  const _AttendanceReportEvent({required this.event, required this.isLegacy});

  final AttendanceEvent event;
  final bool isLegacy;
}

/// Servicio para gestión de asistencia con cálculo automático de faltas
class AttendanceService {
  AttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditService? audit,
    http.Client? httpClient,
    String? deleteApiBaseUrl,
    Future<String?> Function()? appCheckTokenProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audit = audit ?? AuditService(),
       _http = httpClient ?? http.Client(),
       _deleteApiBase =
           deleteApiBaseUrl ?? SecureAttendanceQrService.resolveApiBaseUrl(),
       _appCheckTokenProvider =
           appCheckTokenProvider ??
           (() async {
             try {
               return await FirebaseAppCheck.instance.getToken();
             } catch (_) {
               return null;
             }
           });

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditService _audit;
  final http.Client _http;
  final String _deleteApiBase;
  final Future<String?> Function() _appCheckTokenProvider;

  // ==================== EVENTOS ====================

  /// Obtener todos los eventos
  Stream<List<AttendanceEvent>> getAllEvents() {
    return _firestore
        .collection('attendance_events')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceEvent.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Stream reactivo de un evento operativo por ID.
  Stream<AttendanceEvent?> watchEventById(String eventId) {
    if (eventId.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('attendance_events')
        .doc(eventId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return AttendanceEvent.fromMap(doc.data()!, doc.id);
        });
  }

  /// Obtener evento por ID
  Future<AttendanceEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .get();
      if (!doc.exists) return null;
      return AttendanceEvent.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error obteniendo evento: $e');
      return null;
    }
  }

  Future<_AttendanceReportEvent?> _getEventForReport(String eventId) async {
    final event = await getEventById(eventId);
    if (event != null) {
      return _AttendanceReportEvent(event: event, isLegacy: false);
    }

    final legacyDoc = await _firestore.collection('eventos').doc(eventId).get();
    final legacyData = legacyDoc.data();
    if (legacyData == null) return null;

    final legacyEvent = EventoAsistencia.fromMap(legacyData, legacyDoc.id);
    return _AttendanceReportEvent(
      event: AttendanceEvent(
        id: legacyEvent.id,
        nombre: legacyEvent.nombre,
        descripcion: legacyEvent.descripcion ?? '',
        fecha: legacyEvent.fecha,
        fechaFin: legacyEvent.fechaFin,
        lugar: 'No identificado',
        tipo: legacyEvent.tipoReunion.value.toLowerCase(),
        activo: true,
        miembrosConvocados: const [],
        modalidadesNoConvocadas: legacyEvent.modalidadesNoConvocadas
            .map((m) => m.value)
            .toList(),
        creadoPor: '',
        createdAt: legacyEvent.fechaCreacion ?? legacyEvent.fecha,
        estado: 'programado',
      ),
      isLegacy: true,
    );
  }

  /// Crear nuevo evento
  Future<String> createEvent(AttendanceEvent event) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final eventRef = _firestore.collection('attendance_events').doc();
      final newEvent = event.copyWith(
        id: eventRef.id,
        creadoPor: userId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final payload = {...newEvent.toMap(), 'asistenciaCount': 0};
      await eventRef.set(payload);

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.create,
        entityType: AuditEntityType.attendanceEvent,
        entityId: eventRef.id,
        description: 'Evento de asistencia creado: ${event.nombre}',
        platform: 'flutter',
      );

      return eventRef.id;
    } catch (e) {
      debugPrint('Error creando evento: $e');
      rethrow;
    }
  }

  /// Actualizar evento
  Future<void> updateEvent(AttendanceEvent event) async {
    try {
      await _firestore
          .collection('attendance_events')
          .doc(event.id)
          .update(event.toMap());

      await _audit.logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.attendanceEvent,
        entityId: event.id,
        description: 'Evento actualizado: ${event.nombre}',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error actualizando evento: $e');
      rethrow;
    }
  }

  /// True if `attendance_events/{id}/asistencias` has at least one document.
  Future<bool> hasAttendanceRecords(String eventId) async {
    if (eventId.isEmpty) return false;
    try {
      final snap = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error comprobando registros de asistencia: $e');
      // Fail closed: treat as having records so destructive ops stay blocked.
      return true;
    }
  }

  /// Soft-archive; preserves attendance subcollection and operational fields.
  Future<void> archiveEvent(String eventId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }
    final event = await getEventById(eventId);
    if (event == null) {
      throw Exception('Evento no encontrado');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Soft-keys only — never rewrite historical / identity fields.
    await _firestore.collection('attendance_events').doc(eventId).update({
      'archivado': true,
      'archivadoAt': now,
      'archivadoPor': userId,
    });
    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.attendanceEvent,
      entityId: eventId,
      description: 'Evento archivado: ${event.nombre}',
      platform: 'flutter',
    );
  }

  /// Restore soft-archived event without recreating the document.
  Future<void> unarchiveEvent(String eventId) async {
    final event = await getEventById(eventId);
    if (event == null) {
      throw Exception('Evento no encontrado');
    }
    await _firestore.collection('attendance_events').doc(eventId).update({
      'archivado': false,
      'archivadoAt': FieldValue.delete(),
      'archivadoPor': FieldValue.delete(),
    });
    await _audit.logAction(
      action: AuditAction.update,
      entityType: AuditEntityType.attendanceEvent,
      entityId: eventId,
      description: 'Evento desarchivado: ${event.nombre}',
      platform: 'flutter',
    );
  }

  /// Hard-delete via Cloud Function (Auth + App Check + SUPERADMIN).
  ///
  /// Client pre-check reduces UX friction; backend re-validates emptiness
  /// to close TOCTOU. Does not delete subcollections recursively.
  Future<void> deleteEventSafely(String eventId) async {
    if (await hasAttendanceRecords(eventId)) {
      throw AttendanceEventHasRecordsException();
    }
    await _deleteEventViaFunction(eventId);
  }

  /// Legacy entry point — redirects to [deleteEventSafely].
  Future<void> deleteEvent(String eventId) => deleteEventSafely(eventId);

  Future<void> _deleteEventViaFunction(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AttendanceEventDeleteException('unauthenticated');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw AttendanceEventDeleteException('unauthenticated');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
      'Accept': 'application/json',
    };
    try {
      final appCheck = (await _appCheckTokenProvider())?.trim() ?? '';
      if (appCheck.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheck;
      }
    } catch (_) {
      // Backend decides if missing token is fatal.
    }

    final endpoint = '$_deleteApiBase/api/attendance-delete-event';
    late final http.Response response;
    try {
      response = await _http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode({'eventId': eventId}),
      );
    } catch (e) {
      debugPrint('Error llamando attendance-delete-event: $e');
      throw AttendanceEventDeleteException('network-error');
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }
    final code = body?['code']?.toString() ?? 'delete-failed';

    if (response.statusCode == 200 && body?['ok'] == true) {
      await _audit.logAction(
        action: AuditAction.delete,
        entityType: AuditEntityType.attendanceEvent,
        entityId: eventId,
        description: 'Evento eliminado (seguro): $eventId',
        platform: 'flutter',
      );
      return;
    }
    if (code == 'event-has-attendance' || response.statusCode == 409) {
      throw AttendanceEventHasRecordsException();
    }
    throw AttendanceEventDeleteException(code, statusCode: response.statusCode);
  }

  // ==================== ASISTENCIAS ====================
  String _safeDocSegment(String raw) {
    final encoded = base64Url
        .encode(utf8.encode(raw.trim()))
        .replaceAll('=', '');
    return encoded.isEmpty ? '_' : encoded;
  }

  /// Registrar asistencia (cliente).
  ///
  /// [MetodoRegistro.secureQrV2] está prohibido aquí — solo Cloud Functions.
  /// [MetodoRegistro.manualOverride] exige justificación no vacía y memberId
  /// de padrón (no crea socios).
  Future<String> registerAttendance({
    required String eventId,
    required String personaId,
    required bool asistio,
    MetodoRegistro metodo = MetodoRegistro.manual,
    String? observaciones,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      if (eventId.isEmpty || personaId.isEmpty) {
        throw Exception('Evento o persona no proporcionados');
      }
      if (metodo == MetodoRegistro.secureQrV2) {
        throw Exception(
          'SECURE_QR_V2 solo puede registrarse vía Cloud Functions',
        );
      }

      final nota = (observaciones ?? '').trim();
      if (metodo == MetodoRegistro.manualOverride && nota.length < 3) {
        throw Exception(
          'El registro manual excepcional requiere un motivo (mín. 3 caracteres)',
        );
      }

      // Override: el personaId debe existir en members (padrón).
      if (metodo == MetodoRegistro.manualOverride) {
        final memberSnap = await _firestore
            .collection('members')
            .doc(personaId)
            .get();
        if (!memberSnap.exists) {
          throw Exception(
            'Socio no encontrado en padrón. Seleccione un member existente.',
          );
        }
      }

      final existing = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .where('personaId', isEqualTo: personaId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('Ya existe un registro para este socio en este evento');
      }

      final attendanceRef = _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .doc(_safeDocSegment(personaId));

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final data = {
        'id': attendanceRef.id,
        'eventoId': eventId,
        'personaId': personaId,
        'asistio': asistio,
        'metodoRegistro': metodo.value,
        'fechaRegistro': timestamp,
        'registradoPor': userId,
        'justificacion': nota,
        if (nota.isNotEmpty) 'observaciones': nota,
      };

      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(attendanceRef);
        if (current.exists) {
          throw Exception(
            'Ya existe un registro para este socio en este evento',
          );
        }
        final eventRef = _firestore
            .collection('attendance_events')
            .doc(eventId);
        final eventSnap = await transaction.get(eventRef);
        if (!eventSnap.exists) {
          throw Exception('Evento no encontrado');
        }
        final rawCount = eventSnap.data()?['asistenciaCount'];
        // Fail-closed: never invent 0 for legacy missing count (may have orphans).
        if (rawCount is! num || rawCount.toInt() < 0) {
          throw AttendanceLegacyCountException();
        }
        transaction.set(attendanceRef, data);
        transaction.update(eventRef, {
          'asistenciaCount': FieldValue.increment(1),
        });
      });

      await _audit.logAction(
        action: AuditAction.attendance,
        entityType: AuditEntityType.attendanceRecord,
        entityId: attendanceRef.id,
        description: metodo == MetodoRegistro.manualOverride
            ? 'MANUAL_OVERRIDE: ${asistio ? "Presente" : "Ausente"} - '
                  'member=$personaId - motivo=$nota'
            : 'Asistencia registrada: ${asistio ? "Presente" : "Ausente"} - '
                  'Persona: $personaId',
        platform: 'flutter',
      );
      return attendanceRef.id;
    } catch (e) {
      debugPrint('Error registrando asistencia: $e');
      rethrow;
    }
  }

  /// Indica si ya existe un documento para la misma persona (id en `members`) en este evento.
  Future<bool> hasAttendanceRecord(
    String attendanceEventId,
    String personaId,
  ) async {
    if (personaId.isEmpty) return false;
    try {
      final qs = await _firestore
          .collection('attendance_events')
          .doc(attendanceEventId)
          .collection('asistencias')
          .where('personaId', isEqualTo: personaId)
          .limit(1)
          .get();
      return qs.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error consultando duplicados de asistencia: $e');
      return true;
    }
  }

  /// Obtener asistencias de un evento
  Stream<List<AsistenciaRegistro>> getEventAttendances(String eventId) {
    return _firestore
        .collection('attendance_events')
        .doc(eventId)
        .collection('asistencias')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AsistenciaRegistro.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // ==================== CÁLCULO DE FALTAS AUTOMÁTICAS ====================

  /// Stream reactivo del resumen global de asistencia de un socio.
  ///
  /// Combina el modelo nuevo (`attendance_events/{id}/asistencias`) con el
  /// legado (`eventos` + `asistencias` + `personas`). En legacy se cruzan varios
  /// identificadores porque datos antiguos pueden usar `member.id`, número de
  /// socio, `workerCode`, documento o `personas/{id}`.
  ///
  /// No usar `async*` + `yield*` aquí: el stream resultante es de **una sola**
  /// suscripción y un `StreamBuilder` dentro de un `TabBarView` / `PageView`
  /// puede provocar un segundo `listen` (p. ej. al crear hijos adyacentes),
  /// lanzando `Bad state: Stream has already been listened to`.
  Stream<MemberAttendanceSummary> watchMemberAttendanceSummary(
    String memberId,
  ) {
    return Stream<void>.fromFuture(_ensureCanReadMemberSummary(memberId))
        .asyncExpand((_) => _watchMemberAttendanceSummaryUnchecked(memberId))
        .asBroadcastStream();
  }

  Stream<MemberAttendanceSummary> _watchMemberAttendanceSummaryUnchecked(
    String memberId,
  ) {
    late final StreamController<MemberAttendanceSummary> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    final attendanceRecordSubscriptions = <StreamSubscription<dynamic>>[];
    final newAttendanceDocsByEvent =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    DocumentSnapshot<Map<String, dynamic>>? memberDoc;
    QuerySnapshot<Map<String, dynamic>>? attendanceEventsSnap;
    QuerySnapshot<Map<String, dynamic>>? legacyEventsSnap;
    QuerySnapshot<Map<String, dynamic>>? legacyAttendancesSnap;
    QuerySnapshot<Map<String, dynamic>>? personasSnap;
    var attendanceRecordListenersReady = false;
    var attendanceListenerGeneration = 0;
    var emission = 0;

    Future<void> emitIfReady() async {
      if (memberDoc == null ||
          attendanceEventsSnap == null ||
          !attendanceRecordListenersReady ||
          legacyEventsSnap == null ||
          legacyAttendancesSnap == null ||
          personasSnap == null) {
        return;
      }

      final currentEmission = ++emission;
      try {
        final summary = _buildMemberAttendanceSummary(
          memberDoc: memberDoc!,
          attendanceEventsSnap: attendanceEventsSnap!,
          newAttendanceDocs: newAttendanceDocsByEvent.values
              .expand((docs) => docs)
              .toList(growable: false),
          legacyEventsSnap: legacyEventsSnap!,
          legacyAttendancesSnap: legacyAttendancesSnap!,
          personasSnap: personasSnap!,
        );
        if (!controller.isClosed && currentEmission == emission) {
          controller.add(summary);
        }
      } catch (e, st) {
        if (!controller.isClosed && currentEmission == emission) {
          controller.addError(e, st);
        }
      }
    }

    void watchAttendanceRecordsForEvents(
      QuerySnapshot<Map<String, dynamic>> eventsSnap,
    ) {
      attendanceListenerGeneration++;
      final generation = attendanceListenerGeneration;
      for (final subscription in attendanceRecordSubscriptions) {
        unawaited(subscription.cancel());
      }
      attendanceRecordSubscriptions.clear();
      newAttendanceDocsByEvent.clear();
      attendanceRecordListenersReady = false;

      final pendingEventIds = eventsSnap.docs.map((doc) => doc.id).toSet();
      if (pendingEventIds.isEmpty) {
        attendanceRecordListenersReady = true;
        unawaited(emitIfReady());
        return;
      }

      for (final eventDoc in eventsSnap.docs) {
        final eventId = eventDoc.id;
        final subscription = eventDoc.reference
            .collection('asistencias')
            .where('personaId', isEqualTo: memberId)
            .snapshots()
            .listen((snap) {
              if (generation != attendanceListenerGeneration) return;
              newAttendanceDocsByEvent[eventId] = snap.docs;
              pendingEventIds.remove(eventId);
              if (pendingEventIds.isEmpty) {
                attendanceRecordListenersReady = true;
              }
              emitIfReady();
            }, onError: controller.addError);
        attendanceRecordSubscriptions.add(subscription);
      }
    }

    controller = StreamController<MemberAttendanceSummary>.broadcast(
      onListen: () {
        subscriptions.add(
          _firestore.collection('members').doc(memberId).snapshots().listen((
            snap,
          ) {
            memberDoc = snap;
            emitIfReady();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore.collection('attendance_events').snapshots().listen((snap) {
            attendanceEventsSnap = snap;
            watchAttendanceRecordsForEvents(snap);
            emitIfReady();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore.collection('eventos').snapshots().listen((snap) {
            legacyEventsSnap = snap;
            emitIfReady();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore.collection('asistencias').snapshots().listen((snap) {
            legacyAttendancesSnap = snap;
            emitIfReady();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore.collection('personas').snapshots().listen((snap) {
            personasSnap = snap;
            emitIfReady();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        for (final subscription in attendanceRecordSubscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
        attendanceRecordSubscriptions.clear();
      },
    );

    return controller.stream;
  }

  /// Obtiene resúmenes de asistencia para un conjunto de socios en una sola
  /// carga. Se usa para exportaciones administrativas del padrón completo.
  Future<Map<String, MemberAttendanceSummary>>
  fetchMemberAttendanceSummariesForExport(List<Member> members) async {
    if (members.isEmpty) return {};

    final attendanceEventsFuture = _firestore
        .collection('attendance_events')
        .get();
    final legacyEventsFuture = _firestore.collection('eventos').get();
    final legacyAttendancesFuture = _firestore.collection('asistencias').get();
    final personasFuture = _firestore.collection('personas').get();

    final attendanceEventsSnap = await attendanceEventsFuture;
    final newAttendanceSnaps = await Future.wait(
      attendanceEventsSnap.docs.map(
        (doc) => doc.reference.collection('asistencias').get(),
      ),
    );
    final newAttendanceDocs = newAttendanceSnaps
        .expand((snapshot) => snapshot.docs)
        .toList();
    final legacyEventsSnap = await legacyEventsFuture;
    final legacyAttendancesSnap = await legacyAttendancesFuture;
    final personasSnap = await personasFuture;

    final summaries = <String, MemberAttendanceSummary>{};
    for (final member in members) {
      summaries[member.id] = _buildMemberAttendanceSummaryForMember(
        member: member,
        attendanceEventDocs: attendanceEventsSnap.docs,
        newAttendanceDocs: newAttendanceDocs,
        legacyEventDocs: legacyEventsSnap.docs,
        legacyAttendanceDocs: legacyAttendancesSnap.docs,
        personaDocs: personasSnap.docs,
      );
    }
    return summaries;
  }

  Future<void> _ensureCanReadMemberSummary(String memberId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Usuario no autenticado');
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final role = ((userData['role'] as String?) ?? 'USER').toUpperCase();
    if (role == 'SUPERADMIN' ||
        role == 'ADMIN' ||
        role == 'OPERADOR_ASISTENCIA') {
      return;
    }

    final canonicalMemberId = userData['memberId'] as String?;
    if (_sameToken(canonicalMemberId, memberId)) {
      return;
    }

    final memberDoc = await _firestore
        .collection('members')
        .doc(memberId)
        .get();
    final memberData = memberDoc.data();
    if (memberData == null) {
      throw Exception('Socio no encontrado');
    }
    final member = Member.fromMap(memberData, memberDoc.id);
    final employeeNumber = (userData['employeeNumber'] as String?) ?? '';
    final email =
        (userData['email'] as String?) ?? _auth.currentUser?.email ?? '';
    final displayName =
        (userData['displayName'] as String?) ??
        _auth.currentUser?.displayName ??
        '';

    final allowed =
        _sameToken(uid, member.id) ||
        _sameToken(uid, member.documentId) ||
        _sameToken(employeeNumber, member.workerCode) ||
        _sameToken(employeeNumber, member.memberNumber) ||
        _sameToken(employeeNumber, member.documentId) ||
        _sameToken(email, member.email) ||
        _sameToken(displayName, member.fullName);

    if (!allowed) {
      throw Exception('No tiene permisos para consultar este resumen');
    }
  }

  bool _sameToken(String? a, String? b) {
    final aa = a?.trim().toLowerCase() ?? '';
    final bb = b?.trim().toLowerCase() ?? '';
    return aa.isNotEmpty && bb.isNotEmpty && aa == bb;
  }

  bool _hasAttendanceJustification(AsistenciaRegistro? asistencia) {
    return asistencia?.justificacion?.trim().isNotEmpty == true;
  }

  MemberAttendanceSummary _buildMemberAttendanceSummary({
    required DocumentSnapshot<Map<String, dynamic>> memberDoc,
    required QuerySnapshot<Map<String, dynamic>> attendanceEventsSnap,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    newAttendanceDocs,
    required QuerySnapshot<Map<String, dynamic>> legacyEventsSnap,
    required QuerySnapshot<Map<String, dynamic>> legacyAttendancesSnap,
    required QuerySnapshot<Map<String, dynamic>> personasSnap,
  }) {
    final memberData = memberDoc.data();
    if (!memberDoc.exists || memberData == null) {
      return MemberAttendanceSummary.empty;
    }

    final member = Member.fromMap(memberData, memberDoc.id);
    return _buildMemberAttendanceSummaryForMember(
      member: member,
      attendanceEventDocs: attendanceEventsSnap.docs,
      newAttendanceDocs: newAttendanceDocs,
      legacyEventDocs: legacyEventsSnap.docs,
      legacyAttendanceDocs: legacyAttendancesSnap.docs,
      personaDocs: personasSnap.docs,
    );
  }

  MemberAttendanceSummary _buildMemberAttendanceSummaryForMember({
    required Member member,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    attendanceEventDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    newAttendanceDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> legacyEventDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    legacyAttendanceDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> personaDocs,
  }) {
    final memberKeys = _memberAttendanceKeys(member);
    final legacyPersonaIds = _legacyPersonaIdsForMember(member, personaDocs);

    final attendanceByEvent = <String, AsistenciaRegistro>{};
    for (final doc in newAttendanceDocs) {
      final data = doc.data();
      final collectionName = doc.reference.parent.parent?.parent.id ?? '';
      if (collectionName != 'attendance_events') {
        continue;
      }
      final eventId =
          doc.reference.parent.parent?.id ?? data['eventoId']?.toString() ?? '';
      if (eventId.isEmpty) continue;
      final registro = AsistenciaRegistro.fromMap(data, doc.id);
      if (!memberKeys.contains(_norm(registro.personaId))) continue;
      attendanceByEvent[eventId] = registro;
    }

    final legacyAttendanceByEvent = <String, AsistenciaRegistro>{};
    for (final doc in legacyAttendanceDocs) {
      final registro = AsistenciaRegistro.fromMap(doc.data(), doc.id);
      if (registro.eventoId.isEmpty) continue;
      final personaKey = _norm(registro.personaId);
      if (legacyPersonaIds.contains(personaKey)) {
        legacyAttendanceByEvent[registro.eventoId] = registro;
      }
    }

    final detalles = <AsistenciaDetalle>[];
    var totalConvocados = 0;
    var totalAsistencias = 0;
    var totalFaltas = 0;
    var totalNoConvocado = 0;

    for (final doc in attendanceEventDocs) {
      final event = AttendanceEvent.fromMap(doc.data(), doc.id);
      if (!event.activo || event.archivado) continue;

      final specificList = event.miembrosConvocados.isNotEmpty;
      final explicitlyConvoked =
          !specificList ||
          event.miembrosConvocados.any((id) => memberKeys.contains(_norm(id)));
      if (!explicitlyConvoked) {
        totalNoConvocado++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: 'No convocado',
            justificacion: 'No incluido en convocatoria',
          ),
        );
        continue;
      }

      final excludedByModalidad =
          member.modalidad != null &&
          event.modalidadesNoConvocadas.any(
            (m) => _norm(m) == _norm(member.modalidad!.value),
          );
      if (excludedByModalidad) {
        totalNoConvocado++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: 'No convocado',
            justificacion: 'Justificado por modalidad',
          ),
        );
        continue;
      }

      totalConvocados++;
      final asistencia = attendanceByEvent[event.id];
      if (asistencia?.asistio == true) {
        totalAsistencias++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: 'Presente',
            justificacion: asistencia?.justificacion,
          ),
        );
      } else {
        final isJustified = _hasAttendanceJustification(asistencia);
        if (!isJustified) totalFaltas++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: isJustified ? 'Ausente justificado' : 'Ausente',
            justificacion: asistencia?.justificacion,
          ),
        );
      }
    }

    for (final doc in legacyEventDocs) {
      final event = EventoAsistencia.fromMap(doc.data(), doc.id);
      if (!event.activo) continue;
      final excludedByModalidad =
          member.modalidad != null &&
          event.modalidadesNoConvocadas.contains(member.modalidad);
      if (excludedByModalidad) {
        totalNoConvocado++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: 'No convocado',
            justificacion: 'Justificado por modalidad',
            isLegacy: true,
          ),
        );
        continue;
      }

      totalConvocados++;
      final asistencia =
          legacyAttendanceByEvent[event.id] ??
          _legacyAttendanceFromNewGroupFallback(
            event.id,
            memberKeys,
            newAttendanceDocs,
          );
      if (asistencia?.asistio == true) {
        totalAsistencias++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: 'Presente',
            justificacion: asistencia?.justificacion,
            isLegacy: true,
          ),
        );
      } else {
        final isJustified = _hasAttendanceJustification(asistencia);
        if (!isJustified) totalFaltas++;
        detalles.add(
          AsistenciaDetalle(
            eventId: event.id,
            eventName: event.nombre,
            fecha: event.fecha,
            estado: isJustified ? 'Ausente justificado' : 'Ausente',
            justificacion: asistencia?.justificacion,
            isLegacy: true,
          ),
        );
      }
    }

    detalles.sort((a, b) => b.fecha.compareTo(a.fecha));
    return MemberAttendanceSummary(
      totalConvocados: totalConvocados,
      totalAsistencias: totalAsistencias,
      totalFaltas: totalFaltas,
      totalNoConvocado: totalNoConvocado,
      detalles: detalles,
    );
  }

  Set<String> _memberAttendanceKeys(Member member) {
    return {
      _norm(member.id),
      _norm(member.memberNumber),
      _norm(member.workerCode),
      _norm(member.documentId),
    }..remove('');
  }

  Set<String> _legacyPersonaIdsForMember(
    Member member,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> personaDocs,
  ) {
    final keys = _memberAttendanceKeys(member);
    final ids = <String>{...keys};
    for (final doc in personaDocs) {
      final persona = PersonaAsistencia.fromMap(doc.data(), doc.id);
      final personaKeys = {
        _norm(persona.id),
        _norm(persona.identificador),
        _norm(persona.codigoQR),
      }..remove('');
      if (personaKeys.any(keys.contains)) {
        ids.add(_norm(persona.id));
      }
    }
    return ids;
  }

  AsistenciaRegistro? _legacyAttendanceFromNewGroupFallback(
    String eventId,
    Set<String> memberKeys,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    for (final doc in docs) {
      final data = doc.data();
      final parentEventId =
          doc.reference.parent.parent?.id ?? data['eventoId']?.toString() ?? '';
      if (parentEventId != eventId) continue;
      final registro = AsistenciaRegistro.fromMap(data, doc.id);
      if (memberKeys.contains(_norm(registro.personaId))) {
        return registro;
      }
    }
    return null;
  }

  String _norm(String? value) => value?.trim().toLowerCase() ?? '';

  /// Elige un evento operativo para mostrar en el dashboard del hub.
  ///
  /// Prioridad: `estado == en_curso` (más reciente por fecha); si no hay, el activo
  /// ya iniciado (`fecha <= ahora`) más reciente; si no, el próximo por comenzar;
  /// si no, el activo más reciente por fecha.
  static String? pickHighlightedOperationalEventId(
    List<AttendanceEvent> events,
  ) {
    final active = events.where((e) => e.activo && !e.archivado).toList();
    if (active.isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final enCurso = active
        .where((e) => e.estado.toLowerCase().trim() == 'en_curso')
        .toList();
    if (enCurso.isNotEmpty) {
      enCurso.sort((a, b) => b.fecha.compareTo(a.fecha));
      return enCurso.first.id;
    }
    final started = active.where((e) => e.fecha <= now).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    if (started.isNotEmpty) return started.first.id;
    final upcoming = active.where((e) => e.fecha > now).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    if (upcoming.isNotEmpty) return upcoming.first.id;
    active.sort((a, b) => b.fecha.compareTo(a.fecha));
    return active.first.id;
  }

  /// Métricas agregadas para dashboard (modelo `attendance_events`).
  Future<AttendanceHubDashboardData?> buildHubDashboardData(
    String eventId,
  ) async {
    try {
      final ev = await getEventById(eventId);
      if (ev == null) return null;
      final report = await generateAttendanceReport(eventId);
      return AttendanceHubDashboardData.fromReport(report, ev);
    } catch (e, st) {
      debugPrint('buildHubDashboardData: $e\n$st');
      return null;
    }
  }

  /// Obtener reporte completo de asistencia con faltas calculadas
  Future<AttendanceReport> generateAttendanceReport(String eventId) async {
    try {
      // 1. Obtener evento
      final reportEvent = await _getEventForReport(eventId);
      if (reportEvent == null) {
        throw Exception('Evento no encontrado');
      }
      final event = reportEvent.event;

      // 2. Obtener miembros convocados (padrón)
      final membersConvoked = await _loadConvokedMembers(
        event.miembrosConvocados,
      );
      final excludedModalidades = event.modalidadesNoConvocadas.toSet();
      final obligatedMembers = <Member>[];
      final notConvokedMembers = <Member>[];

      for (final member in membersConvoked) {
        final modalidad = member.modalidad?.value;
        if (modalidad != null && excludedModalidades.contains(modalidad)) {
          notConvokedMembers.add(member);
        } else {
          obligatedMembers.add(member);
        }
      }

      // 3. Obtener asistencias reales
      final attendances = await _loadAttendancesForReport(
        eventId,
        reportEvent.isLegacy,
      );

      // 4. Calcular presentes y faltantes
      final attendedMemberIds = reportEvent.isLegacy
          ? await _resolveLegacyAttendedMemberIds(attendances, obligatedMembers)
          : attendances.where((a) => a.asistio).map((a) => a.personaId).toSet();

      final presentMembers = <Member>[];
      final absentMembers = <Member>[];

      for (final member in obligatedMembers) {
        if (attendedMemberIds.contains(member.id)) {
          presentMembers.add(member);
        } else {
          absentMembers.add(member);
        }
      }

      // 5. Calcular estadísticas
      final totalConvoked = obligatedMembers.length;
      final totalPresent = presentMembers.length;
      final totalAbsent = absentMembers.length;
      final attendanceRate = totalConvoked > 0
          ? (totalPresent / totalConvoked * 100)
          : 0.0;

      return AttendanceReport(
        event: event,
        totalConvoked: totalConvoked,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
        totalNotConvoked: notConvokedMembers.length,
        attendanceRate: attendanceRate,
        presentMembers: presentMembers,
        absentMembers: absentMembers,
        notConvokedMembers: notConvokedMembers,
        attendances: attendances,
      );
    } catch (e) {
      debugPrint('Error generando reporte: $e');
      rethrow;
    }
  }

  Future<List<Member>> _loadConvokedMembers(List<String> memberIds) async {
    final members = <Member>[];
    if (memberIds.isEmpty) {
      final allMembersSnapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: MemberStatus.active.name)
          .get();

      for (final doc in allMembersSnapshot.docs) {
        members.add(Member.fromMap(doc.data(), doc.id));
      }
      return members;
    }

    const batchSize = 30;
    for (var i = 0; i < memberIds.length; i += batchSize) {
      final end = i + batchSize < memberIds.length
          ? i + batchSize
          : memberIds.length;
      final batch = memberIds.sublist(i, end);
      final snapshot = await _firestore
          .collection('members')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        final member = Member.fromMap(doc.data(), doc.id);
        if (member.status == MemberStatus.active) {
          members.add(member);
        }
      }
    }
    return members;
  }

  Future<List<AsistenciaRegistro>> _loadAttendancesForReport(
    String eventId,
    bool isLegacy,
  ) async {
    if (!isLegacy) {
      final attendancesSnapshot = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      return attendancesSnapshot.docs
          .map((doc) => AsistenciaRegistro.fromMap(doc.data(), doc.id))
          .toList();
    }

    final globalSnapshot = await _firestore
        .collection('asistencias')
        .where('eventoId', isEqualTo: eventId)
        .get();
    if (globalSnapshot.docs.isNotEmpty) {
      return globalSnapshot.docs
          .map((doc) => AsistenciaRegistro.fromMap(doc.data(), doc.id))
          .toList();
    }

    final subcollectionSnapshot = await _firestore
        .collection('eventos')
        .doc(eventId)
        .collection('asistencias')
        .get();
    return subcollectionSnapshot.docs
        .map((doc) => AsistenciaRegistro.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<Set<String>> _resolveLegacyAttendedMemberIds(
    List<AsistenciaRegistro> attendances,
    List<Member> members,
  ) async {
    final presentPersonaIds = attendances
        .where((a) => a.asistio)
        .map((a) => a.personaId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (presentPersonaIds.isEmpty || members.isEmpty) return {};

    final identifiers = <String>{...presentPersonaIds};
    final personaDocs = await Future.wait(
      presentPersonaIds.map(
        (id) => _firestore.collection('personas').doc(id).get(),
      ),
    );

    for (final doc in personaDocs) {
      final data = doc.data();
      if (data == null) continue;
      final persona = PersonaAsistencia.fromMap(data, doc.id);
      final identificador = persona.identificador?.trim();
      if (identificador != null && identificador.isNotEmpty) {
        identifiers.add(identificador);
      }
    }

    return members
        .where((member) {
          final memberIdentifiers = <String>{
            member.id,
            member.memberNumber,
            if (member.workerCode?.isNotEmpty == true) member.workerCode!,
            if (member.documentId?.isNotEmpty == true) member.documentId!,
          };
          return memberIdentifiers.any(identifiers.contains);
        })
        .map((member) => member.id)
        .toSet();
  }

  Future<Map<String, Member?>> _membersByIds(Set<String> ids) async {
    final out = <String, Member?>{};
    if (ids.isEmpty) return out;
    const chunk = 25;
    final list = ids.toList();
    for (var i = 0; i < list.length; i += chunk) {
      final end = i + chunk < list.length ? i + chunk : list.length;
      final part = list.sublist(i, end);
      final snaps = await Future.wait(
        part.map((id) => _firestore.collection('members').doc(id).get()),
      );
      for (var j = 0; j < part.length; j++) {
        final s = snaps[j];
        out[part[j]] = s.exists && s.data() != null
            ? Member.fromMap(s.data()!, s.id)
            : null;
      }
    }
    return out;
  }

  PersonaAsistencia _personaExportDesdeMember(Member? m, String personaId) {
    if (m != null) {
      final ident =
          (m.workerCode?.trim().isNotEmpty == true
              ? m.workerCode!.trim()
              : null) ??
          (m.documentId?.trim().isNotEmpty == true
              ? m.documentId!.trim()
              : null) ??
          (m.memberNumber.trim().isNotEmpty ? m.memberNumber : null);
      return PersonaAsistencia(
        id: m.id,
        nombres: m.firstName,
        apellidos: m.lastName,
        identificador: ident,
      );
    }
    return PersonaAsistencia(
      id: personaId,
      nombres: '(Sin ficha en members)',
      apellidos: personaId,
      identificador: null,
    );
  }

  /// Filas **`AsistenciaConDatos`** para exportación/UI leyendo
  /// `attendance_events` y cada subcolección `asistencias` (persona enlazada a `members`).
  ///
  /// Las lecturas de subcolecciones se lanzan en **paralelo** (`Future.wait`) para
  /// reducir latencia total cuando hay muchos eventos de reporte.
  Future<List<AsistenciaConDatos>> fetchAllAttendanceExportsRows() async {
    final evSnap = await _firestore.collection('attendance_events').get();
    if (evSnap.docs.isEmpty) return [];

    final events = evSnap.docs
        .map((d) => AttendanceEvent.fromMap(d.data(), d.id))
        .toList();

    final subSnaps = await Future.wait(
      events.map(
        (ev) => _firestore
            .collection('attendance_events')
            .doc(ev.id)
            .collection('asistencias')
            .get(),
      ),
    );

    final pendingEv = <AttendanceEvent>[];
    final pendingReg = <AsistenciaRegistro>[];
    final memberIds = <String>{};

    for (var ei = 0; ei < events.length; ei++) {
      final ev = events[ei];
      final sub = subSnaps[ei];
      for (final aDoc in sub.docs) {
        final raw = AsistenciaRegistro.fromMap(aDoc.data(), aDoc.id);
        final reg = AsistenciaRegistro(
          id: raw.id,
          eventoId: ev.id,
          personaId: raw.personaId,
          fechaRegistro: raw.fechaRegistro,
          metodoRegistro: raw.metodoRegistro,
          justificacion: raw.justificacion,
          asistio: raw.asistio,
        );
        pendingEv.add(ev);
        pendingReg.add(reg);
        if (reg.personaId.isNotEmpty) {
          memberIds.add(reg.personaId);
        }
      }
    }

    final membMap = await _membersByIds(memberIds);
    final rows = <AsistenciaConDatos>[];

    for (var i = 0; i < pendingReg.length; i++) {
      final ev = pendingEv[i];
      final reg = pendingReg[i];
      final persona = _personaExportDesdeMember(
        membMap[reg.personaId],
        reg.personaId,
      );
      final eventUi = EventoAsistencia(
        id: ev.id,
        nombre: '[Evento] ${ev.nombre}',
        fecha: ev.fecha,
        tipoReunion: TipoReunion.fromString(ev.tipo),
        descripcion: ev.descripcion,
      );
      rows.add(
        AsistenciaConDatos(asistencia: reg, persona: persona, evento: eventUi),
      );
    }

    rows.sort((a, b) {
      final ta = a.asistencia.fechaRegistro ?? 0;
      final tb = b.asistencia.fechaRegistro ?? 0;
      return tb.compareTo(ta);
    });
    return rows;
  }
}
