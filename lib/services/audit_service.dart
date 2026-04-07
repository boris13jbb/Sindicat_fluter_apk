import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/models/audit_log.dart';

/// Servicio de auditoría para tracking de acciones críticas en el sistema
class AuditService {
  AuditService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Registrar una acción en el log de auditoría
  Future<String> logAction({
    required AuditAction action,
    required AuditEntityType entityType,
    required String entityId,
    Map<String, dynamic>? changes,
    String? description,
    String? platform,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception(
          'Usuario no autenticado - no se puede registrar auditoría',
        );
      }

      final logRef = _firestore.collection('audit_logs').doc();
      final log = AuditLog(
        id: logRef.id,
        action: action,
        entityType: entityType,
        entityId: entityId,
        userId: userId,
        userName: _auth.currentUser?.displayName,
        timestamp: DateTime.now(),
        changes: changes,
        description: description,
        platform: platform,
      );

      await logRef.set(log.toMap());
      return logRef.id;
    } catch (e) {
      // No lanzar error para no interrumpir el flujo principal
      debugPrint('Error registrando auditoría: $e');
      return '';
    }
  }

  /// Obtener logs de auditoría con filtros opcionales
  Stream<List<AuditLog>> getAuditLogs({
    AuditAction? action,
    AuditEntityType? entityType,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query query = _firestore.collection('audit_logs');

    // Aplicar filtros
    if (action != null) {
      query = query.where('action', isEqualTo: action.name);
    }

    if (entityType != null) {
      query = query.where('entityType', isEqualTo: entityType.name);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch,
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: endDate.millisecondsSinceEpoch,
      );
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AuditLog.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Obtener logs de auditoría para una entidad específica
  Stream<List<AuditLog>> getEntityAuditLogs({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 20,
  }) {
    return _firestore
        .collection('audit_logs')
        .where('entityType', isEqualTo: entityType.name)
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AuditLog.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Obtener logs de auditoría de un usuario específico
  Stream<List<AuditLog>> getUserAuditLogs({
    required String userId,
    int limit = 50,
  }) {
    return _firestore
        .collection('audit_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AuditLog.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Limpiar logs antiguos (solo superadmin)
  Future<void> cleanOldLogs({required DateTime olderThan}) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('timestamp', isLessThan: olderThan.millisecondsSinceEpoch)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error limpiando logs antiguos: $e');
      rethrow;
    }
  }
}
