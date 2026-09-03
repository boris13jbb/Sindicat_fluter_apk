import '../../utils/date_time_ms.dart';

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

  /// Optional geofence (backward compatible — defaults preserve existing events).
  final bool geofenceEnabled;
  final double? latitude;
  final double? longitude;
  final double geofenceRadiusMeters;
  final bool requireScannerLocation;
  final bool requireMemberLocation;

  /// Secure QR mode: `dynamic_member_qr` (default) or `challenge_response`.
  final String secureQrMode;

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
    this.geofenceEnabled = false,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters = 150,
    this.requireScannerLocation = false,
    this.requireMemberLocation = false,
    this.secureQrMode = 'dynamic_member_qr',
  });

  factory AttendanceEvent.fromMap(Map<String, dynamic> map, String id) {
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
    );
  }

  int get fechaFinVigenciaMs => fechaFin ?? endOfLocalDayMs(fecha);

  Map<String, dynamic> toMap() {
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
    int? fechaFin,
    String? lugar,
    String? tipo,
    bool? activo,
    List<String>? miembrosConvocados,
    List<String>? modalidadesNoConvocadas,
    String? creadoPor,
    int? createdAt,
    String? estado,
    bool? geofenceEnabled,
    double? latitude,
    double? longitude,
    double? geofenceRadiusMeters,
    bool? requireScannerLocation,
    bool? requireMemberLocation,
    String? secureQrMode,
  }) {
    return AttendanceEvent(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      fechaFin: fechaFin ?? this.fechaFin,
      lugar: lugar ?? this.lugar,
      tipo: tipo ?? this.tipo,
      activo: activo ?? this.activo,
      miembrosConvocados: miembrosConvocados ?? this.miembrosConvocados,
      modalidadesNoConvocadas:
          modalidadesNoConvocadas ?? this.modalidadesNoConvocadas,
      creadoPor: creadoPor ?? this.creadoPor,
      createdAt: createdAt ?? this.createdAt,
      estado: estado ?? this.estado,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      requireScannerLocation:
          requireScannerLocation ?? this.requireScannerLocation,
      requireMemberLocation:
          requireMemberLocation ?? this.requireMemberLocation,
      secureQrMode: secureQrMode ?? this.secureQrMode,
    );
  }
}
