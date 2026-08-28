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
    );
  }
}
