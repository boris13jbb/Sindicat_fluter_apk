/// Tipo de reunión (compatible con Firestore).
enum TipoReunion {
  ordinaria('ORDINARIA'),
  extraordinaria('EXTRAORDINARIA');

  const TipoReunion(this.value);
  final String value;

  static TipoReunion fromString(String v) {
    return TipoReunion.values.firstWhere(
      (e) => e.value == v.toUpperCase(),
      orElse: () => TipoReunion.ordinaria,
    );
  }
}

/// Evento de asistencia (compatible con Firestore eventos).
class EventoAsistencia {
  const EventoAsistencia({
    required this.id,
    required this.nombre,
    required this.fecha,
    required this.tipoReunion,
    this.descripcion,
    this.fechaCreacion,
  });

  final String id;
  final String nombre;
  final int fecha;
  final TipoReunion tipoReunion;
  final String? descripcion;
  final int? fechaCreacion;

  factory EventoAsistencia.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id']?.toString() ?? '';
    return EventoAsistencia(
      id: docId,
      nombre: map['nombre'] as String? ?? '',
      fecha: (map['fecha'] as num?)?.toInt() ?? 0,
      tipoReunion: TipoReunion.fromString(
        (map['tipoReunion'] as String?) ?? 'ORDINARIA',
      ),
      descripcion: map['descripcion'] as String?,
      fechaCreacion: (map['fechaCreacion'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'fecha': fecha,
      'tipoReunion': tipoReunion.value,
      'descripcion': descripcion ?? '',
      'fechaCreacion': fechaCreacion ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
