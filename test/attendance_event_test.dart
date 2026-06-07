import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/features/asistencia/route_args.dart';
import 'package:fluter_apk/services/attendance_service.dart';

AttendanceEvent _event({
  required String id,
  required int fecha,
  bool activo = true,
  String estado = 'programado',
  int? fechaFin,
}) {
  return AttendanceEvent(
    id: id,
    nombre: id,
    descripcion: '',
    fecha: fecha,
    fechaFin: fechaFin,
    lugar: '',
    tipo: 'asamblea',
    activo: activo,
    miembrosConvocados: const [],
    creadoPor: 'admin',
    createdAt: fecha,
    estado: estado,
  );
}

void main() {
  group('AttendanceEvent', () {
    test('serializes operational event fields and exclusions', () {
      final event = AttendanceEvent(
        id: 'event-1',
        nombre: 'Asamblea',
        descripcion: 'General',
        fecha: 1000,
        fechaFin: 2000,
        lugar: 'Sede',
        tipo: 'asamblea',
        activo: true,
        miembrosConvocados: const ['member-1'],
        modalidadesNoConvocadas: const ['N'],
        creadoPor: 'admin',
        createdAt: 900,
        estado: 'programado',
      );

      final map = event.toMap();
      final restored = AttendanceEvent.fromMap(map, event.id);

      expect(restored.id, 'event-1');
      expect(restored.fechaFin, 2000);
      expect(restored.miembrosConvocados, ['member-1']);
      expect(restored.modalidadesNoConvocadas, ['N']);
      expect(restored.estado, 'programado');
    });

    test('copyWith preserves fields and updates requested values', () {
      final original = _event(id: 'event-1', fecha: 1000);
      final updated = original.copyWith(
        estado: 'en_curso',
        modalidadesNoConvocadas: const ['D'],
      );

      expect(updated.id, original.id);
      expect(updated.fecha, original.fecha);
      expect(updated.estado, 'en_curso');
      expect(updated.modalidadesNoConvocadas, ['D']);
    });
  });

  group('operational attendance selection', () {
    test('prioritizes the most recent active in-progress event', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final selected = AttendanceService.pickHighlightedOperationalEventId([
        _event(id: 'inactive', fecha: now, activo: false),
        _event(id: 'older', fecha: now - 2000, estado: 'en_curso'),
        _event(id: 'newer', fecha: now - 1000, estado: 'en_curso'),
      ]);

      expect(selected, 'newer');
    });

    test('chooses nearest upcoming event when none has started', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final selected = AttendanceService.pickHighlightedOperationalEventId([
        _event(id: 'later', fecha: now + 20_000),
        _event(id: 'next', fecha: now + 10_000),
      ]);

      expect(selected, 'next');
    });

    test('returns null when no active operational event exists', () {
      final selected = AttendanceService.pickHighlightedOperationalEventId([
        _event(id: 'inactive', fecha: 1000, activo: false),
      ]);

      expect(selected, isNull);
    });
  });

  group('AsistenciaEventRouteArgs', () {
    test('detects attendance_events route arguments', () {
      const args = AsistenciaEventRouteArgs.attendance(
        'attendance-1',
        openScannerDirectly: true,
      );

      expect(args.isAttendanceReport, isTrue);
      expect(args.attendanceEventId, 'attendance-1');
      expect(args.evento, isNull);
      expect(args.openScannerDirectly, isTrue);
    });

    test('rejects an empty attendance event id', () {
      const args = AsistenciaEventRouteArgs.attendance('');

      expect(args.isAttendanceReport, isFalse);
    });
  });
}
