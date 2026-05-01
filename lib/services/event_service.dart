import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/audit_log.dart';
import '../core/models/voto_event.dart';

/// Servicio de eventos para la pantalla de historial.
///
/// La fuente activa de auditoría es `audit_logs`; `events` se conserva solo
/// para compatibilidad con registros legacy del módulo de voto.
class EventService {
  EventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _legacyEventsCollection = 'events';
  static const String _auditLogsCollection = 'audit_logs';

  Stream<List<VotoEvent>> getAllEvents({int limit = 100}) {
    try {
      return _firestore
          .collection(_auditLogsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snap) => snap.docs
                .map(
                  (d) => _eventFromAuditLog(AuditLog.fromMap(d.data(), d.id)),
                )
                .toList(),
          )
          .handleError((error, stackTrace) {
            debugPrint('❌ Error en stream de eventos: $error');
            debugPrint('StackTrace: $stackTrace');
            // No relanzar el error aquí para evitar cerrar el stream
            // El StreamBuilder manejará el error
          });
    } catch (e) {
      debugPrint('❌ Error al obtener eventos: $e');
      rethrow;
    }
  }

  Stream<List<VotoEvent>> getEventsByEntityType(
    VotoEntityType entityType, {
    int limit = 100,
  }) {
    return getAllEvents(limit: limit * 2).map(
      (list) =>
          list.where((e) => e.entityType == entityType).take(limit).toList(),
    );
  }

  Future<void> logEvent({
    required VotoEventType type,
    required VotoEntityType entityType,
    required String entityId,
    required String userId,
    String? userName,
    String? userRole,
    required String description,
    VotoEventResult result = VotoEventResult.success,
    String? errorMessage,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection(_legacyEventsCollection).add({
      'timestamp': now,
      'type': type.value,
      'entityType': entityType.value,
      'entityId': entityId,
      'userId': userId,
      'userName': userName,
      'userRole': userRole ?? '',
      'description': description,
      'result': result.value,
      'errorMessage': errorMessage,
    });
  }

  VotoEvent _eventFromAuditLog(AuditLog log) {
    final description = log.description?.trim().isNotEmpty == true
        ? log.description!
        : '${log.action.displayName} - ${log.entityType.displayName}';
    final lowerDescription = description.toLowerCase();

    return VotoEvent(
      id: log.id,
      timestamp: log.timestamp.millisecondsSinceEpoch,
      type: _eventTypeFromAudit(log.action, log.entityType),
      entityType: _entityTypeFromAudit(log.entityType),
      entityId: log.entityId,
      userId: log.userId,
      userName: log.userName,
      userRole: null,
      description: description,
      result:
          lowerDescription.contains('fallid') ||
              lowerDescription.contains('error')
          ? VotoEventResult.failure
          : VotoEventResult.success,
      errorMessage: null,
    );
  }

  VotoEventType _eventTypeFromAudit(
    AuditAction action,
    AuditEntityType entityType,
  ) {
    if (action == AuditAction.vote) return VotoEventType.voteCast;
    if (action == AuditAction.login) return VotoEventType.userLogin;
    if (action == AuditAction.logout) return VotoEventType.userLogout;

    if (entityType == AuditEntityType.election) {
      switch (action) {
        case AuditAction.create:
          return VotoEventType.electionCreated;
        case AuditAction.update:
          return VotoEventType.electionUpdated;
        case AuditAction.delete:
          return VotoEventType.electionDeleted;
        default:
          return VotoEventType.systemAction;
      }
    }

    if (entityType == AuditEntityType.candidate) {
      switch (action) {
        case AuditAction.create:
          return VotoEventType.candidateCreated;
        case AuditAction.update:
          return VotoEventType.candidateUpdated;
        case AuditAction.delete:
          return VotoEventType.candidateDeleted;
        default:
          return VotoEventType.systemAction;
      }
    }

    return VotoEventType.systemAction;
  }

  VotoEntityType _entityTypeFromAudit(AuditEntityType entityType) {
    switch (entityType) {
      case AuditEntityType.member:
        return VotoEntityType.member;
      case AuditEntityType.election:
        return VotoEntityType.election;
      case AuditEntityType.candidate:
        return VotoEntityType.candidate;
      case AuditEntityType.vote:
        return VotoEntityType.vote;
      case AuditEntityType.attendanceEvent:
      case AuditEntityType.attendanceRecord:
        return VotoEntityType.attendance;
      case AuditEntityType.user:
        return VotoEntityType.user;
      case AuditEntityType.import_:
        return VotoEntityType.import_;
    }
  }
}
