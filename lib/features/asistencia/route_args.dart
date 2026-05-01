import '../../core/models/asistencia/evento.dart';

/// Enruta registro/scanner entre evento **`eventos` (legacy)** y **`attendance_events`** (reporte nuevo).
///
/// Compatible con llamadas viejas que pasaban solo [`EventoAsistencia`] en rutas nombradas.
class AsistenciaEventRouteArgs {
  const AsistenciaEventRouteArgs.legacy(EventoAsistencia ev)
    : evento = ev,
      attendanceEventId = null;

  const AsistenciaEventRouteArgs.attendance(String id)
    : evento = null,
      attendanceEventId = id;

  final EventoAsistencia? evento;

  /// Id del documento en `attendance_events`.
  final String? attendanceEventId;

  bool get isAttendanceReport =>
      attendanceEventId != null && attendanceEventId!.isNotEmpty;
}
