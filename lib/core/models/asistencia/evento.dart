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

/// Modalidad de turno/turno de trabajo.
enum Modalidad {
  A('A'),
  B('B'),
  C('C'),
  D('D'),
  E('E'),
  N('N'),
  // ignore: constant_identifier_names
  N1('N1'),
  // ignore: constant_identifier_names
  N2('N2'),
  X('X'),
  Y('Y'),
  Z('Z');

  const Modalidad(this.value);
  final String value;

  static Modalidad fromString(String v) {
    if (v.isEmpty) return Modalidad.A;
    return Modalidad.values.firstWhere(
      (e) => e.value == v.toUpperCase(),
      orElse: () => Modalidad.A,
    );
  }

  /// Solo valores exactos de [Modalidad.value]; `null` si vacío o inválido.
  static Modalidad? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toUpperCase();
    if (v.isEmpty) return null;
    for (final e in Modalidad.values) {
      if (e.value == v) return e;
    }
    return null;
  }

  /// Turnos válidos para **eventos legacy** y justificación operativa de asistencia (mañana/tarde/noche).
  /// No incluye X, Y, Z (solo selector de modalidad para convocatorias).
  static const List<Modalidad> valoresParaJustificacionAsistencia = [
    Modalidad.A,
    Modalidad.B,
    Modalidad.C,
    Modalidad.D,
    Modalidad.E,
    Modalidad.N,
    Modalidad.N1,
    Modalidad.N2,
  ];
}

/// Utilidad para generar justificación automática basada en la modalidad.
class JustificacionHelper {
  /// Mapeo de modalidad a texto de justificación.
  static String obtenerJustificacion(Modalidad modalidad) {
    switch (modalidad) {
      case Modalidad.A:
        return 'Turno mañana - Justificado por asistencia en turno A';
      case Modalidad.B:
        return 'Turno mañana tardía - Justificado por asistencia en turno B';
      case Modalidad.C:
        return 'Turno tarde - Justificado por asistencia en turno C';
      case Modalidad.D:
        return 'Turno tarde tardía - Justificado por asistencia en turno D';
      case Modalidad.E:
        return 'Turno noche - Justificado por asistencia en turno E';
      case Modalidad.N:
        return 'Turno nocturno - Justificado por asistencia en turno nocturno';
      case Modalidad.N1:
        return 'Turno nocturno variante 1 - Justificado por asistencia en turno N1';
      case Modalidad.N2:
        return 'Turno nocturno variante 2 - Justificado por asistencia en turno N2';
      case Modalidad.X:
        return 'Turno especial X - Justificado por asistencia en turno especial';
      case Modalidad.Y:
        return 'Turno especial Y - Justificado por asistencia en turno especial';
      case Modalidad.Z:
        return 'Turno especial Z - Justificado por asistencia en turno especial';
    }
  }

  /// Etiqueta compacta tipo **Modalidad A** (selector de convocatorias).
  static String etiquetaModalidad(Modalidad m) => 'Modalidad ${m.value}';

  /// Obtener descripción de la modalidad para UI.
  static String obtenerDescripcionModalidad(Modalidad modalidad) {
    switch (modalidad) {
      case Modalidad.A:
        return 'Turno Mañana (A)';
      case Modalidad.B:
        return 'Turno Mañana Tardía (B)';
      case Modalidad.C:
        return 'Turno Tarde (C)';
      case Modalidad.D:
        return 'Turno Tarde Tardía (D)';
      case Modalidad.E:
        return 'Turno Noche (E)';
      case Modalidad.N:
        return 'Turno Nocturno (N)';
      case Modalidad.N1:
        return 'Turno Nocturno Var. 1 (N1)';
      case Modalidad.N2:
        return 'Turno Nocturno Var. 2 (N2)';
      case Modalidad.X:
        return 'Turno Especial X';
      case Modalidad.Y:
        return 'Turno Especial Y';
      case Modalidad.Z:
        return 'Turno Especial Z';
    }
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
    this.modalidad,
    this.modalidadesNoConvocadas = const [],
  });

  final String id;
  final String nombre;
  final int fecha;
  final TipoReunion tipoReunion;
  final String? descripcion;
  final int? fechaCreacion;

  /// Campo legacy. Se mantiene solo para leer documentos antiguos.
  final Modalidad? modalidad;
  final List<Modalidad> modalidadesNoConvocadas;

  static List<Modalidad> _parseModalidadesNoConvocadas(
    dynamic raw,
    Modalidad? legacyModalidad,
  ) {
    final parsed = <Modalidad>[];
    if (raw is Iterable) {
      for (final item in raw) {
        final modalidad = Modalidad.tryParse(item?.toString());
        if (modalidad != null && !parsed.contains(modalidad)) {
          parsed.add(modalidad);
        }
      }
    }
    if (parsed.isEmpty && legacyModalidad != null) {
      parsed.add(legacyModalidad);
    }
    return parsed;
  }

  factory EventoAsistencia.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id']?.toString() ?? '';
    final modalidadStr = (map['modalidad'] as String?);
    final legacyModalidad = modalidadStr != null && modalidadStr.isNotEmpty
        ? Modalidad.fromString(modalidadStr)
        : null;
    return EventoAsistencia(
      id: docId,
      nombre: map['nombre'] as String? ?? '',
      fecha: (map['fecha'] as num?)?.toInt() ?? 0,
      tipoReunion: TipoReunion.fromString(
        (map['tipoReunion'] as String?) ?? 'ORDINARIA',
      ),
      descripcion: map['descripcion'] as String?,
      fechaCreacion: (map['fechaCreacion'] as num?)?.toInt(),
      modalidad: legacyModalidad,
      modalidadesNoConvocadas: _parseModalidadesNoConvocadas(
        map['modalidadesNoConvocadas'],
        legacyModalidad,
      ),
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
      'modalidadesNoConvocadas': modalidadesNoConvocadas
          .map((m) => m.value)
          .toList(),
    };
  }

  /// Retorna una copia del evento con cambios puntuales.
  EventoAsistencia copyWith({
    Modalidad? modalidad,
    bool clearModalidad = false,
    List<Modalidad>? modalidadesNoConvocadas,
  }) {
    return EventoAsistencia(
      id: id,
      nombre: nombre,
      fecha: fecha,
      tipoReunion: tipoReunion,
      descripcion: descripcion,
      fechaCreacion: fechaCreacion,
      modalidad: clearModalidad ? null : (modalidad ?? this.modalidad),
      modalidadesNoConvocadas:
          modalidadesNoConvocadas ?? this.modalidadesNoConvocadas,
    );
  }
}
