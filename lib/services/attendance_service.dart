import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/models/asistencia/asistencia.dart';
import '../core/models/member.dart';
import '../core/models/audit_log.dart';
import 'audit_service.dart';

/// Modelo para evento de asistencia
class AttendanceEvent {
  final String id;
  final String nombre;
  final String descripcion;
  final int fecha; // Timestamp
  final String lugar;
  final String tipo; // reunion, asamblea, capacitacion, etc.
  final bool activo;
  final List<String> miembrosConvocados; // IDs de socios convocados
  final List<String> modalidadesNoConvocadas;
  final String creadoPor;
  final int createdAt;
  final String estado; // programado, en_curso, finalizado

  AttendanceEvent({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fecha,
    required this.lugar,
    required this.tipo,
    required this.activo,
    required this.miembrosConvocados,
    this.modalidadesNoConvocadas = const [],
    required this.creadoPor,
    required this.createdAt,
    this.estado = 'programado',
  });

  factory AttendanceEvent.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceEvent(
      id: id,
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      fecha: (map['fecha'] as num?)?.toInt() ?? 0,
      lugar: map['lugar'] ?? '',
      tipo: map['tipo'] ?? 'reunion',
      activo: map['activo'] ?? true,
      miembrosConvocados: List<String>.from(map['miembrosConvocados'] ?? []),
      modalidadesNoConvocadas: List<String>.from(
        map['modalidadesNoConvocadas'] ?? [],
      ),
      creadoPor: map['creadoPor'] ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      estado: map['estado'] ?? 'programado',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha': fecha,
      'lugar': lugar,
      'tipo': tipo,
      'activo': activo,
      'miembrosConvocados': miembrosConvocados,
      'modalidadesNoConvocadas': modalidadesNoConvocadas,
      'creadoPor': creadoPor,
      'createdAt': createdAt,
      'estado': estado,
    };
  }

  AttendanceEvent copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    int? fecha,
    String? lugar,
    String? tipo,
    bool? activo,
    List<String>? miembrosConvocados,
    List<String>? modalidadesNoConvocadas,
    String? creadoPor,
    int? createdAt,
    String? estado,
  }) {
    return AttendanceEvent(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      lugar: lugar ?? this.lugar,
      tipo: tipo ?? this.tipo,
      activo: activo ?? this.activo,
      miembrosConvocados: miembrosConvocados ?? this.miembrosConvocados,
      modalidadesNoConvocadas:
          modalidadesNoConvocadas ?? this.modalidadesNoConvocadas,
      creadoPor: creadoPor ?? this.creadoPor,
      createdAt: createdAt ?? this.createdAt,
      estado: estado ?? this.estado,
    );
  }
}

class _AttendanceReportEvent {
  const _AttendanceReportEvent({required this.event, required this.isLegacy});

  final AttendanceEvent event;
  final bool isLegacy;
}

/// Estado resumido de un socio frente a un evento de asistencia.
class AsistenciaDetalle {
  const AsistenciaDetalle({
    required this.eventId,
    required this.eventName,
    required this.fecha,
    required this.estado,
    this.justificacion,
    this.isLegacy = false,
  });

  final String eventId;
  final String eventName;
  final int fecha;
  final String estado;
  final String? justificacion;
  final bool isLegacy;
}

/// Resumen global de asistencia del socio autenticado o consultado por admin.
class MemberAttendanceSummary {
  const MemberAttendanceSummary({
    required this.totalConvocados,
    required this.totalAsistencias,
    required this.totalFaltas,
    this.totalNoConvocado = 0,
    this.detalles = const [],
  });

  final int totalConvocados;
  final int totalAsistencias;
  final int totalFaltas;
  final int totalNoConvocado;
  final List<AsistenciaDetalle> detalles;

  static const empty = MemberAttendanceSummary(
    totalConvocados: 0,
    totalAsistencias: 0,
    totalFaltas: 0,
  );
}

/// Servicio para gestión de asistencia con cálculo automático de faltas
class AttendanceService {
  AttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditService? audit,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditService _audit;

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

      await eventRef.set(newEvent.toMap());

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

  /// Eliminar evento
  Future<void> deleteEvent(String eventId) async {
    try {
      final event = await getEventById(eventId);
      await _firestore.collection('attendance_events').doc(eventId).delete();

      await _audit.logAction(
        action: AuditAction.delete,
        entityType: AuditEntityType.attendanceEvent,
        entityId: eventId,
        description: 'Evento eliminado: ${event?.nombre}',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      rethrow;
    }
  }

  // ==================== ASISTENCIAS ====================
  String _safeDocSegment(String raw) {
    final encoded = base64Url
        .encode(utf8.encode(raw.trim()))
        .replaceAll('=', '');
    return encoded.isEmpty ? '_' : encoded;
  }

  /// Registrar asistencia manual
  /// `personaId` debe ser normalmente el id del documento en `members` para que cuadre con el reporte.
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
      final nota = observaciones ?? '';

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
        transaction.set(attendanceRef, data);
      });

      await _audit.logAction(
        action: AuditAction.attendance,
        entityType: AuditEntityType.attendanceRecord,
        entityId: attendanceRef.id,
        description:
            'Asistencia registrada: ${asistio ? "Presente" : "Ausente"} - Persona: $personaId',
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
  Stream<MemberAttendanceSummary> watchMemberAttendanceSummary(
    String memberId,
  ) async* {
    await _ensureCanReadMemberSummary(memberId);
    yield* _watchMemberAttendanceSummaryUnchecked(memberId);
  }

  Stream<MemberAttendanceSummary> _watchMemberAttendanceSummaryUnchecked(
    String memberId,
  ) {
    late final StreamController<MemberAttendanceSummary> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? memberDoc;
    QuerySnapshot<Map<String, dynamic>>? attendanceEventsSnap;
    QuerySnapshot<Map<String, dynamic>>? newAttendancesSnap;
    QuerySnapshot<Map<String, dynamic>>? legacyEventsSnap;
    QuerySnapshot<Map<String, dynamic>>? legacyAttendancesSnap;
    QuerySnapshot<Map<String, dynamic>>? personasSnap;
    var emission = 0;

    Future<void> emitIfReady() async {
      if (memberDoc == null ||
          attendanceEventsSnap == null ||
          newAttendancesSnap == null ||
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
          newAttendancesSnap: newAttendancesSnap!,
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
            emitIfReady();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collectionGroup('asistencias')
              .where('personaId', isEqualTo: memberId)
              .snapshots()
              .listen((snap) {
                newAttendancesSnap = snap;
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
        subscriptions.clear();
      },
    );

    return controller.stream;
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
    required QuerySnapshot<Map<String, dynamic>> newAttendancesSnap,
    required QuerySnapshot<Map<String, dynamic>> legacyEventsSnap,
    required QuerySnapshot<Map<String, dynamic>> legacyAttendancesSnap,
    required QuerySnapshot<Map<String, dynamic>> personasSnap,
  }) {
    final memberData = memberDoc.data();
    if (!memberDoc.exists || memberData == null) {
      return MemberAttendanceSummary.empty;
    }

    final member = Member.fromMap(memberData, memberDoc.id);
    final memberKeys = _memberAttendanceKeys(member);
    final legacyPersonaIds = _legacyPersonaIdsForMember(
      member,
      personasSnap.docs,
    );

    final attendanceByEvent = <String, AsistenciaRegistro>{};
    for (final doc in newAttendancesSnap.docs) {
      final data = doc.data();
      final eventId =
          doc.reference.parent.parent?.id ?? data['eventoId']?.toString() ?? '';
      if (eventId.isEmpty) continue;
      attendanceByEvent[eventId] = AsistenciaRegistro.fromMap(data, doc.id);
    }

    final legacyAttendanceByEvent = <String, AsistenciaRegistro>{};
    for (final doc in legacyAttendancesSnap.docs) {
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

    for (final doc in attendanceEventsSnap.docs) {
      final event = AttendanceEvent.fromMap(doc.data(), doc.id);
      if (!event.activo) continue;

      final specificList = event.miembrosConvocados.isNotEmpty;
      final explicitlyConvoked =
          !specificList ||
          event.miembrosConvocados.any((id) => _norm(id) == _norm(member.id));
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
          event.modalidadesNoConvocadas.contains(member.modalidad!.value);
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

    for (final doc in legacyEventsSnap.docs) {
      final event = EventoAsistencia.fromMap(doc.data(), doc.id);
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
            newAttendancesSnap.docs,
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
        nombre: '[Reporte] ${ev.nombre}',
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

/// Reporte de asistencia con cálculo de faltas
class AttendanceReport {
  final AttendanceEvent event;
  final int totalConvoked;
  final int totalPresent;
  final int totalAbsent;
  final int totalNotConvoked;
  final double attendanceRate;
  final List<Member> presentMembers;
  final List<Member> absentMembers;
  final List<Member> notConvokedMembers;
  final List<AsistenciaRegistro> attendances;

  AttendanceReport({
    required this.event,
    required this.totalConvoked,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalNotConvoked,
    required this.attendanceRate,
    required this.presentMembers,
    required this.absentMembers,
    required this.notConvokedMembers,
    required this.attendances,
  });

  double get absenceRate => totalConvoked == 0 ? 0 : 100 - attendanceRate;
}
