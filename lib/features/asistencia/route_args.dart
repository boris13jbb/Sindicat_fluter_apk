import '../../core/models/asistencia/evento.dart';

/// Enruta registro/scanner entre evento histórico **`eventos`** y evento actual **`attendance_events`**.
///
/// Compatible con llamadas viejas que pasaban solo [`EventoAsistencia`] en rutas nombradas.
class AsistenciaEventRouteArgs {
  const AsistenciaEventRouteArgs.legacy(
    this.evento, {
    this.openScannerDirectly = false,
  }) : attendanceEventId = null;

  const AsistenciaEventRouteArgs.attendance(
    String id, {
    this.openScannerDirectly = false,
  })  : evento = null,
        attendanceEventId = id;

  final EventoAsistencia? evento;

  /// Id del documento en `attendance_events`.
  final String? attendanceEventId;

  /// Si es true, [ScannerAsistenciaScreen] abre al vuelo la cámara (no web).
  final bool openScannerDirectly;

  bool get isAttendanceReport =>
      attendanceEventId != null && attendanceEventId!.isNotEmpty;
}
