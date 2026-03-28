/// Tipo de evento del sistema (compatible con Firestore events).
enum VotoEventType {
  voteCast('VOTE_CAST'),
  voteAttempt('VOTE_ATTEMPT'),
  electionCreated('ELECTION_CREATED'),
  electionUpdated('ELECTION_UPDATED'),
  electionDeleted('ELECTION_DELETED'),
  candidateCreated('CANDIDATE_CREATED'),
  candidateUpdated('CANDIDATE_UPDATED'),
  candidateDeleted('CANDIDATE_DELETED'),
  userLogin('USER_LOGIN'),
  userLogout('USER_LOGOUT'),
  exportExcel('EXPORT_EXCEL'),
  exportPdf('EXPORT_PDF'),
  permissionDenied('PERMISSION_DENIED');

  const VotoEventType(this.value);
  final String value;

  static VotoEventType fromString(String v) {
    return VotoEventType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => VotoEventType.voteAttempt,
    );
  }

  String get shortLabel {
    switch (this) {
      case VotoEventType.voteCast: return 'Voto emitido';
      case VotoEventType.voteAttempt: return 'Intento de voto';
      case VotoEventType.electionCreated: return 'Elección creada';
      case VotoEventType.electionUpdated: return 'Elección actualizada';
      case VotoEventType.electionDeleted: return 'Elección eliminada';
      case VotoEventType.candidateCreated: return 'Candidato creado';
      case VotoEventType.candidateUpdated: return 'Candidato actualizado';
      case VotoEventType.candidateDeleted: return 'Candidato eliminado';
      case VotoEventType.userLogin: return 'Inicio de sesión';
      case VotoEventType.userLogout: return 'Cierre de sesión';
      case VotoEventType.exportExcel: return 'Exportación Excel';
      case VotoEventType.exportPdf: return 'Exportación PDF';
      case VotoEventType.permissionDenied: return 'Acceso denegado';
    }
  }
}

/// Tipo de entidad.
enum VotoEntityType {
  user('USER'),
  election('ELECTION'),
  candidate('CANDIDATE'),
  vote('VOTE'),
  system('SYSTEM');

  const VotoEntityType(this.value);
  final String value;

  static VotoEntityType fromString(String v) {
    return VotoEntityType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => VotoEntityType.system,
    );
  }
}

/// Resultado del evento.
enum VotoEventResult {
  success('SUCCESS'),
  failure('FAILURE'),
  blocked('BLOCKED');

  const VotoEventResult(this.value);
  final String value;

  static VotoEventResult fromString(String v) {
    return VotoEventResult.values.firstWhere(
      (e) => e.value == v,
      orElse: () => VotoEventResult.failure,
    );
  }
}

/// Evento de auditoría del módulo voto (compatible con Firestore events).
class VotoEvent {
  const VotoEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.userId,
    this.userName,
    this.userRole,
    required this.description,
    required this.result,
    this.errorMessage,
  });

  final String id;
  final int timestamp;
  final VotoEventType type;
  final VotoEntityType entityType;
  final String entityId;
  final String userId;
  final String? userName;
  final String? userRole;
  final String description;
  final VotoEventResult result;
  final String? errorMessage;

  String get formattedDate {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  static int _timestampFromMap(Map<String, dynamic> map) {
    final t = map['timestamp'];
    if (t == null) return 0;
    if (t is int) return t;
    if (t is num) return t.toInt();
    if (t is DateTime) return t.millisecondsSinceEpoch;
    // Firestore Timestamp
    try {
      final ms = (t as dynamic).millisecondsSinceEpoch as int?;
      if (ms != null) return ms;
    } catch (_) {}
    return 0;
  }

  factory VotoEvent.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id'] as String? ?? '';
    return VotoEvent(
      id: docId,
      timestamp: _timestampFromMap(map),
      type: VotoEventType.fromString(map['type'] as String? ?? ''),
      entityType: VotoEntityType.fromString(map['entityType'] as String? ?? ''),
      entityId: map['entityId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String?,
      userRole: map['userRole'] as String?,
      description: map['description'] as String? ?? '',
      result: VotoEventResult.fromString(map['result'] as String? ?? ''),
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
