/// Tipos de acción para auditoría
enum AuditAction {
  create('Creación'),
  update('Actualización'),
  delete('Eliminación'),
  vote('Voto'),
  import_('Importación'),
  login('Inicio de sesión'),
  logout('Cierre de sesión'),
  attendance('Asistencia');

  const AuditAction(this.displayName);

  final String displayName;

  static AuditAction fromString(String value) {
    switch (value.toLowerCase()) {
      case 'create':
        return AuditAction.create;
      case 'update':
        return AuditAction.update;
      case 'delete':
        return AuditAction.delete;
      case 'vote':
        return AuditAction.vote;
      case 'import':
      case 'import_':
        return AuditAction.import_;
      case 'login':
        return AuditAction.login;
      case 'logout':
        return AuditAction.logout;
      case 'attendance':
        return AuditAction.attendance;
      default:
        return AuditAction.create;
    }
  }
}

/// Tipos de entidad para auditoría
enum AuditEntityType {
  member('Socio'),
  election('Elección'),
  candidate('Candidato'),
  vote('Voto'),
  attendanceEvent('Evento de asistencia'),
  attendanceRecord('Registro de asistencia'),
  user('Usuario'),
  import_('Importación');

  const AuditEntityType(this.displayName);

  final String displayName;

  static AuditEntityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'member':
        return AuditEntityType.member;
      case 'election':
        return AuditEntityType.election;
      case 'candidate':
        return AuditEntityType.candidate;
      case 'vote':
        return AuditEntityType.vote;
      case 'attendanceevent':
      case 'attendance_event':
        return AuditEntityType.attendanceEvent;
      case 'attendancerecord':
      case 'attendance_record':
        return AuditEntityType.attendanceRecord;
      case 'user':
        return AuditEntityType.user;
      case 'import':
      case 'import_':
        return AuditEntityType.import_;
      default:
        return AuditEntityType.member;
    }
  }
}

/// Registro de auditoría para tracking de acciones críticas
class AuditLog {
  final String id;
  final AuditAction action; // Qué acción se realizó
  final AuditEntityType entityType; // Qué tipo de entidad
  final String entityId; // ID de la entidad afectada
  final String userId; // Quién realizó la acción
  final String? userName; // Nombre del usuario (para display)
  final DateTime timestamp; // Cuándo ocurrió
  final Map<String, dynamic>? changes; // Qué cambió (antes/después)
  final String? description; // Descripción legible
  final String? platform; // web, android, ios, windows
  final String? ipAddress; // IP del usuario (si aplica)

  AuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.userId,
    this.userName,
    required this.timestamp,
    this.changes,
    this.description,
    this.platform,
    this.ipAddress,
  });

  /// Crear instancia desde mapa de Firestore
  factory AuditLog.fromMap(Map<String, dynamic> map, String id) {
    return AuditLog(
      id: id,
      action: AuditAction.fromString(map['action'] ?? ''),
      entityType: AuditEntityType.fromString(map['entityType'] ?? ''),
      entityId: map['entityId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      changes: map['changes'],
      description: map['description'],
      platform: map['platform'],
      ipAddress: map['ipAddress'],
    );
  }

  /// Convertir a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'action': action.name,
      'entityType': entityType.name,
      'entityId': entityId,
      'userId': userId,
      if (userName != null) 'userName': userName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (changes != null) 'changes': changes,
      if (description != null) 'description': description,
      if (platform != null) 'platform': platform,
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }

  @override
  String toString() {
    return 'AuditLog(id: $id, action: $action, entityType: $entityType, userId: $userId, timestamp: $timestamp)';
  }
}
