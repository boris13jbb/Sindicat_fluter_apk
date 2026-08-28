/// Estado resumido de un socio frente a un evento de asistencia.
class AsistenciaDetalle {
  const AsistenciaDetalle({
    required this.eventId,
    required this.eventName,
    required this.fecha,
    required this.estado,
    this.justificacion,
    this.isLegacy = false,
  });

  final String eventId;
  final String eventName;
  final int fecha;
  final String estado;
  final String? justificacion;
  final bool isLegacy;
}

/// Resumen global de asistencia del socio autenticado o consultado por admin.
class MemberAttendanceSummary {
  const MemberAttendanceSummary({
    required this.totalConvocados,
    required this.totalAsistencias,
    required this.totalFaltas,
    this.totalNoConvocado = 0,
    this.detalles = const [],
  });

  final int totalConvocados;
  final int totalAsistencias;
  final int totalFaltas;
  final int totalNoConvocado;
  final List<AsistenciaDetalle> detalles;

  static const empty = MemberAttendanceSummary(
    totalConvocados: 0,
    totalAsistencias: 0,
    totalFaltas: 0,
  );
}
