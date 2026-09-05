import '../../core/models/asistencia/attendance_event.dart';

enum AttendanceArchiveListFilter { activos, archivados, todos }

List<AttendanceEvent> applyAttendanceArchiveFilter(
  List<AttendanceEvent> events,
  AttendanceArchiveListFilter filter,
) {
  switch (filter) {
    case AttendanceArchiveListFilter.activos:
      return events.where((e) => !e.archivado).toList();
    case AttendanceArchiveListFilter.archivados:
      return events.where((e) => e.archivado).toList();
    case AttendanceArchiveListFilter.todos:
      return List<AttendanceEvent>.from(events);
  }
}

int countAttendanceEventsHoy(List<AttendanceEvent> events, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final startToday = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).millisecondsSinceEpoch;
  final endToday = DateTime(
    clock.year,
    clock.month,
    clock.day,
    23,
    59,
    59,
    999,
  ).millisecondsSinceEpoch;
  return events
      .where(
        (e) =>
            !e.archivado &&
            e.fecha <= endToday &&
            e.fechaFinVigenciaMs >= startToday,
      )
      .length;
}

int countAttendanceEventsActivos(
  List<AttendanceEvent> events, {
  DateTime? now,
}) {
  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return events
      .where(
        (e) =>
            !e.archivado &&
            e.activo &&
            e.estado.toLowerCase().trim() != 'finalizado' &&
            e.fechaFinVigenciaMs >= ms,
      )
      .length;
}

int countAttendanceEventsFinalizados(List<AttendanceEvent> events) {
  return events
      .where(
        (e) => !e.archivado && e.estado.toLowerCase().trim() == 'finalizado',
      )
      .length;
}

/// Visual badge priority: archivado > borrador > finalizado > en curso > programado.
String attendanceEventBadgeLabel(AttendanceEvent e) {
  if (e.archivado) return 'Archivado';
  final st = e.estado.toLowerCase().trim();
  if (!e.activo) return 'Borrador';
  if (st == 'finalizado') return 'Finalizado';
  if (st == 'en_curso') return 'En curso';
  return 'Programado';
}

/// Fields that must not change once attendance records exist.
bool isAttendanceHistoricalFieldLocked(String field) {
  const locked = {
    'fecha',
    'fechaFin',
    'miembrosConvocados',
    'modalidadesNoConvocadas',
    'secureQrMode',
    'geofenceEnabled',
    'latitude',
    'longitude',
    'geofenceRadiusMeters',
    'requireScannerLocation',
    'requireMemberLocation',
  };
  return locked.contains(field);
}
