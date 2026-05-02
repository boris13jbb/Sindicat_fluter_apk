/// Origen del documento al vincular una elección con asistencia obligatoria.
enum EventoAsistenciaVinculoFuente {
  /// Colección `attendance_events`.
  operativo,

  /// Colección legacy `eventos`.
  legacy,
}

/// Opción unificada para el selector de evento en creación/edición de elecciones.
class EventoAsistenciaVinculoEleccion {
  const EventoAsistenciaVinculoEleccion({
    required this.id,
    required this.nombre,
    required this.fechaInicioMs,
    required this.fechaFinMs,
    required this.fuente,
  });

  final String id;
  final String nombre;
  final int fechaInicioMs;
  final int fechaFinMs;
  final EventoAsistenciaVinculoFuente fuente;

  bool get esLegacy => fuente == EventoAsistenciaVinculoFuente.legacy;
}
