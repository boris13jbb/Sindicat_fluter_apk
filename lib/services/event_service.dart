import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/voto_event.dart';

/// Servicio de eventos de auditoría (colección Firestore "events").
class EventService {
  EventService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'events';

  Stream<List<VotoEvent>> getAllEvents({int limit = 100}) {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VotoEvent.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<VotoEvent>> getEventsByEntityType(VotoEntityType entityType, {int limit = 100}) {
    return getAllEvents(limit: limit * 2).map((list) =>
        list.where((e) => e.entityType == entityType).take(limit).toList());
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
    await _firestore.collection(_collection).add({
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
}
