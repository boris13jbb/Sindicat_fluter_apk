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
      creadoPor: creadoPor ?? this.creadoPor,
      createdAt: createdAt ?? this.createdAt,
      estado: estado ?? this.estado,
    );
  }
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
              .map(
                (doc) => AttendanceEvent.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
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
      return AttendanceEvent.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('Error obteniendo evento: $e');
      return null;
    }
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

  /// Registrar asistencia manual
  Future<void> registerAttendance({
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

      final attendanceRef = _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .doc();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await attendanceRef.set({
        'id': attendanceRef.id,
        'eventoId': eventId,
        'personaId': personaId,
        'asistio': asistio,
        'metodoRegistro': metodo.value,
        'fechaRegistro': timestamp,
        'registradoPor': userId,
        if (observaciones != null) 'observaciones': observaciones,
      });

      await _audit.logAction(
        action: AuditAction.attendance,
        entityType: AuditEntityType.attendanceRecord,
        entityId: attendanceRef.id,
        description:
            'Asistencia registrada: ${asistio ? "Presente" : "Ausente"} - Persona: $personaId',
        platform: 'flutter',
      );
    } catch (e) {
      debugPrint('Error registrando asistencia: $e');
      rethrow;
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
              .map(
                (doc) => AsistenciaRegistro.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // ==================== CÁLCULO DE FALTAS AUTOMÁTICAS ====================

  /// Obtener reporte completo de asistencia con faltas calculadas
  Future<AttendanceReport> generateAttendanceReport(String eventId) async {
    try {
      // 1. Obtener evento
      final event = await getEventById(eventId);
      if (event == null) {
        throw Exception('Evento no encontrado');
      }

      // 2. Obtener miembros convocados (padrón)
      final membersConvoked = <Member>[];
      if (event.miembrosConvocados.isNotEmpty) {
        final membersSnapshot = await _firestore
            .collection('members')
            .where('id', whereIn: event.miembrosConvocados)
            .where('status', isEqualTo: MemberStatus.active.name)
            .get();

        for (final doc in membersSnapshot.docs) {
          membersConvoked.add(
            Member.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          );
        }
      } else {
        // Si no hay miembros específicos, tomar todos los activos
        final allMembersSnapshot = await _firestore
            .collection('members')
            .where('status', isEqualTo: MemberStatus.active.name)
            .get();

        for (final doc in allMembersSnapshot.docs) {
          membersConvoked.add(
            Member.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          );
        }
      }

      // 3. Obtener asistencias reales
      final attendancesSnapshot = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('asistencias')
          .get();

      final attendances = attendancesSnapshot.docs
          .map(
            (doc) => AsistenciaRegistro.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();

      // 4. Calcular presentes y faltantes
      final attendedMemberIds = attendances
          .where((a) => a.asistio)
          .map((a) => a.personaId)
          .toSet();

      final presentMembers = <Member>[];
      final absentMembers = <Member>[];

      for (final member in membersConvoked) {
        if (attendedMemberIds.contains(member.id)) {
          presentMembers.add(member);
        } else {
          absentMembers.add(member);
        }
      }

      // 5. Calcular estadísticas
      final totalConvoked = membersConvoked.length;
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
        attendanceRate: attendanceRate,
        presentMembers: presentMembers,
        absentMembers: absentMembers,
        attendances: attendances,
      );
    } catch (e) {
      debugPrint('Error generando reporte: $e');
      rethrow;
    }
  }
}

/// Reporte de asistencia con cálculo de faltas
class AttendanceReport {
  final AttendanceEvent event;
  final int totalConvoked;
  final int totalPresent;
  final int totalAbsent;
  final double attendanceRate;
  final List<Member> presentMembers;
  final List<Member> absentMembers;
  final List<AsistenciaRegistro> attendances;

  AttendanceReport({
    required this.event,
    required this.totalConvoked,
    required this.totalPresent,
    required this.totalAbsent,
    required this.attendanceRate,
    required this.presentMembers,
    required this.absentMembers,
    required this.attendances,
  });

  double get absenceRate => 100 - attendanceRate;
}
