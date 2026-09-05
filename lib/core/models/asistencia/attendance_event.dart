import '../../utils/date_time_ms.dart';

/// Sentinel for [AttendanceEvent.copyWith] nullable fields:
/// omit → keep; pass `null` → clear.
const Object attendanceEventFieldUnset = Object();

/// Evento operativo de asistencia (`attendance_events`).
class AttendanceEvent {
  final String id;
  final String nombre;
  final String descripcion;
  final int fecha;
  final int? fechaFin;
  final String lugar;
  final String tipo;
  final bool activo;
  final List<String> miembrosConvocados;
  final List<String> modalidadesNoConvocadas;
  final String creadoPor;
  final int createdAt;
  final String estado;

  /// Soft-archive flag (independent of [activo] / draft semantics).
  final bool archivado;
  final int? archivadoAt;
  final String? archivadoPor;

  /// Optional geofence (backward compatible — defaults preserve existing events).
  final bool geofenceEnabled;
  final double? latitude;
  final double? longitude;
  final double geofenceRadiusMeters;
  final bool requireScannerLocation;
  final bool requireMemberLocation;

  /// Secure QR mode: `dynamic_member_qr` (default) or `challenge_response`.
  final String secureQrMode;

  /// Backend counter of asistencias. `null` = legacy / unknown (never coerce to 0).
  final int? asistenciaCount;

  AttendanceEvent({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fecha,
    this.fechaFin,
    required this.lugar,
    required this.tipo,
    required this.activo,
    required this.miembrosConvocados,
    this.modalidadesNoConvocadas = const [],
    required this.creadoPor,
    required this.createdAt,
    this.estado = 'programado',
    this.archivado = false,
    this.archivadoAt,
    this.archivadoPor,
    this.geofenceEnabled = false,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters = 150,
    this.requireScannerLocation = false,
    this.requireMemberLocation = false,
    this.secureQrMode = 'dynamic_member_qr',
    this.asistenciaCount,
  });

  /// Historical edits only when count is explicitly confirmed zero.
  bool get allowsHistoricalFieldEdit => asistenciaCount == 0;

  /// Fail-closed lock: missing or positive count blocks historical UX edits.
  bool get historicalFieldsLocked => asistenciaCount != 0;

  factory AttendanceEvent.fromMap(Map<String, dynamic> map, String id) {
    final rawCount = map['asistenciaCount'];
    final int? parsedCount = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : null);
    return AttendanceEvent(
      id: id,
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      fecha: (map['fecha'] as num?)?.toInt() ?? 0,
      fechaFin: (map['fechaFin'] as num?)?.toInt(),
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
      archivado: map['archivado'] == true,
      archivadoAt: (map['archivadoAt'] as num?)?.toInt(),
      archivadoPor: map['archivadoPor']?.toString(),
      geofenceEnabled: map['geofenceEnabled'] == true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters:
          (map['geofenceRadiusMeters'] as num?)?.toDouble() ?? 150,
      requireScannerLocation: map['requireScannerLocation'] == true,
      requireMemberLocation: map['requireMemberLocation'] == true,
      secureQrMode: (map['secureQrMode']?.toString().trim().isNotEmpty == true)
          ? map['secureQrMode'].toString().trim()
          : 'dynamic_member_qr',
      // Never coerce missing → 0 (legacy integrity).
      asistenciaCount: parsedCount,
    );
  }

  int get fechaFinVigenciaMs => fechaFin ?? endOfLocalDayMs(fecha);

  Map<String, dynamic> toMap() {
    // asistenciaCount is backend-authoritative — never written via client toMap.
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha': fecha,
      if (fechaFin != null) 'fechaFin': fechaFin,
      'lugar': lugar,
      'tipo': tipo,
      'activo': activo,
      'miembrosConvocados': miembrosConvocados,
      'modalidadesNoConvocadas': modalidadesNoConvocadas,
      'creadoPor': creadoPor,
      'createdAt': createdAt,
      'estado': estado,
      'archivado': archivado,
      if (archivadoAt != null) 'archivadoAt': archivadoAt,
      if (archivadoPor != null) 'archivadoPor': archivadoPor,
      'geofenceEnabled': geofenceEnabled,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'geofenceRadiusMeters': geofenceRadiusMeters,
      'requireScannerLocation': requireScannerLocation,
      'requireMemberLocation': requireMemberLocation,
      'secureQrMode': secureQrMode,
    };
  }

  AttendanceEvent copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    int? fecha,
    Object? fechaFin = attendanceEventFieldUnset,
    String? lugar,
    String? tipo,
    bool? activo,
    List<String>? miembrosConvocados,
    List<String>? modalidadesNoConvocadas,
    String? creadoPor,
    int? createdAt,
    String? estado,
    bool? archivado,
    Object? archivadoAt = attendanceEventFieldUnset,
    Object? archivadoPor = attendanceEventFieldUnset,
    bool? geofenceEnabled,
    Object? latitude = attendanceEventFieldUnset,
    Object? longitude = attendanceEventFieldUnset,
    double? geofenceRadiusMeters,
    bool? requireScannerLocation,
    bool? requireMemberLocation,
    String? secureQrMode,
    Object? asistenciaCount = attendanceEventFieldUnset,
  }) {
    return AttendanceEvent(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      fechaFin: identical(fechaFin, attendanceEventFieldUnset)
          ? this.fechaFin
          : fechaFin as int?,
      lugar: lugar ?? this.lugar,
      tipo: tipo ?? this.tipo,
      activo: activo ?? this.activo,
      miembrosConvocados: miembrosConvocados ?? this.miembrosConvocados,
      modalidadesNoConvocadas:
          modalidadesNoConvocadas ?? this.modalidadesNoConvocadas,
      creadoPor: creadoPor ?? this.creadoPor,
      createdAt: createdAt ?? this.createdAt,
      estado: estado ?? this.estado,
      archivado: archivado ?? this.archivado,
      archivadoAt: identical(archivadoAt, attendanceEventFieldUnset)
          ? this.archivadoAt
          : archivadoAt as int?,
      archivadoPor: identical(archivadoPor, attendanceEventFieldUnset)
          ? this.archivadoPor
          : archivadoPor as String?,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      latitude: identical(latitude, attendanceEventFieldUnset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, attendanceEventFieldUnset)
          ? this.longitude
          : longitude as double?,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      requireScannerLocation:
          requireScannerLocation ?? this.requireScannerLocation,
      requireMemberLocation:
          requireMemberLocation ?? this.requireMemberLocation,
      secureQrMode: secureQrMode ?? this.secureQrMode,
      asistenciaCount: identical(asistenciaCount, attendanceEventFieldUnset)
          ? this.asistenciaCount
          : asistenciaCount as int?,
    );
  }
}
