import '../member.dart';
import 'attendance_event.dart';

// Importación directa: `asistencia.dart` no re-exporta este archivo (evita ciclo).
import 'asistencia.dart' show AsistenciaRegistro;

/// Resumen numérico para tarjeta de dashboard del hub de asistencia.
class AttendanceHubDashboardData {
  const AttendanceHubDashboardData({
    required this.eventId,
    required this.nombre,
    required this.fechaMillis,
    required this.lugar,
    required this.totalConvocados,
    required this.presentes,
    required this.ausentes,
    required this.noConvocadosModalidad,
    required this.porcentajePresentes,
    required this.totalRegistrosSubcoleccion,
  });

  final String eventId;
  final String nombre;
  final int fechaMillis;
  final String lugar;
  final int totalConvocados;
  final int presentes;
  final int ausentes;
  final int noConvocadosModalidad;
  final double porcentajePresentes;
  final int totalRegistrosSubcoleccion;

  factory AttendanceHubDashboardData.fromReport(
    AttendanceReport report,
    AttendanceEvent ev,
  ) {
    return AttendanceHubDashboardData(
      eventId: ev.id,
      nombre: ev.nombre,
      fechaMillis: ev.fecha,
      lugar: ev.lugar,
      totalConvocados: report.totalConvoked,
      presentes: report.totalPresent,
      ausentes: report.totalAbsent,
      noConvocadosModalidad: report.totalNotConvoked,
      porcentajePresentes: report.attendanceRate,
      totalRegistrosSubcoleccion: report.attendances.length,
    );
  }
}

/// Reporte de asistencia con cálculo de faltas.
class AttendanceReport {
  AttendanceReport({
    required this.event,
    required this.totalConvoked,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalNotConvoked,
    required this.attendanceRate,
    required this.presentMembers,
    required this.absentMembers,
    required this.notConvokedMembers,
    required this.attendances,
  });

  final AttendanceEvent event;
  final int totalConvoked;
  final int totalPresent;
  final int totalAbsent;
  final int totalNotConvoked;
  final double attendanceRate;
  final List<Member> presentMembers;
  final List<Member> absentMembers;
  final List<Member> notConvokedMembers;
  final List<AsistenciaRegistro> attendances;

  double get absenceRate => totalConvoked == 0 ? 0 : 100 - attendanceRate;
}
