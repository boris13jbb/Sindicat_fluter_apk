import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/features/asistencia/attendance_event_actions.dart';
import 'package:fluter_apk/features/asistencia/attendance_event_list_filters.dart';
import 'package:fluter_apk/features/asistencia/route_args.dart';
import 'package:fluter_apk/services/attendance_service.dart';

AttendanceEvent _event({
  required String id,
  required int fecha,
  bool activo = true,
  String estado = 'programado',
  int? fechaFin,
  bool archivado = false,
  String? creadoPor,
  int? createdAt,
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
    creadoPor: creadoPor ?? 'admin',
    createdAt: createdAt ?? fecha,
    estado: estado,
    archivado: archivado,
  );
}

void main() {
  group('AttendanceEvent archive fields', () {
    test('archived defaults false for historical maps', () {
      final restored = AttendanceEvent.fromMap({
        'nombre': 'A',
        'descripcion': '',
        'fecha': 1000,
        'lugar': 'Sede',
        'tipo': 'asamblea',
        'activo': true,
        'miembrosConvocados': <String>[],
        'creadoPor': 'admin',
        'createdAt': 900,
      }, 'event-1');
      expect(restored.archivado, isFalse);
      expect(restored.archivadoAt, isNull);
      expect(restored.archivadoPor, isNull);
      expect(restored.asistenciaCount, isNull);
      expect(restored.allowsHistoricalFieldEdit, isFalse);
      expect(restored.historicalFieldsLocked, isTrue);
    });

    test('asistenciaCount null is not coerced to 0; 0 unlocks historical', () {
      final legacy = AttendanceEvent.fromMap({
        'nombre': 'L',
        'descripcion': '',
        'fecha': 1000,
        'lugar': '',
        'tipo': 'asamblea',
        'activo': true,
        'miembrosConvocados': <String>[],
        'creadoPor': 'a',
        'createdAt': 1,
      }, 'legacy');
      expect(legacy.asistenciaCount, isNull);
      expect(legacy.toMap().containsKey('asistenciaCount'), isFalse);

      final zero = AttendanceEvent.fromMap({
        'nombre': 'N',
        'descripcion': '',
        'fecha': 1000,
        'lugar': '',
        'tipo': 'asamblea',
        'activo': true,
        'miembrosConvocados': <String>[],
        'creadoPor': 'a',
        'createdAt': 1,
        'asistenciaCount': 0,
      }, 'new');
      expect(zero.asistenciaCount, 0);
      expect(zero.allowsHistoricalFieldEdit, isTrue);
      expect(zero.historicalFieldsLocked, isFalse);

      final withRecords = zero.copyWith(asistenciaCount: 2);
      expect(withRecords.historicalFieldsLocked, isTrue);
    });

    test('parse archived true with metadata', () {
      final restored = AttendanceEvent.fromMap({
        'nombre': 'A',
        'descripcion': '',
        'fecha': 1000,
        'lugar': 'Sede',
        'tipo': 'asamblea',
        'activo': true,
        'miembrosConvocados': <String>[],
        'creadoPor': 'admin',
        'createdAt': 900,
        'archivado': true,
        'archivadoAt': 12345,
        'archivadoPor': 'uid-1',
      }, 'event-1');
      expect(restored.archivado, isTrue);
      expect(restored.archivadoAt, 12345);
      expect(restored.archivadoPor, 'uid-1');
    });

    test('archive persistence round-trip', () {
      final event = _event(
        id: 'e1',
        fecha: 1000,
      ).copyWith(archivado: true, archivadoAt: 50, archivadoPor: 'uid');
      final map = event.toMap();
      expect(map['archivado'], isTrue);
      expect(map['archivadoAt'], 50);
      expect(map['archivadoPor'], 'uid');
      final restored = AttendanceEvent.fromMap(map, event.id);
      expect(restored.archivado, isTrue);
      expect(restored.archivadoAt, 50);
      expect(restored.archivadoPor, 'uid');
    });

    test('unarchive persistence clears nullable metadata via copyWith', () {
      final archived = _event(
        id: 'e1',
        fecha: 1000,
      ).copyWith(archivado: true, archivadoAt: 50, archivadoPor: 'uid');
      final restored = archived.copyWith(
        archivado: false,
        archivadoAt: null,
        archivadoPor: null,
      );
      expect(restored.archivado, isFalse);
      expect(restored.archivadoAt, isNull);
      expect(restored.archivadoPor, isNull);
      final map = restored.toMap();
      expect(map['archivado'], isFalse);
      expect(map.containsKey('archivadoAt'), isFalse);
      expect(map.containsKey('archivadoPor'), isFalse);
    });

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

    test('edit preserves id createdAt creadoPor', () {
      final original = _event(
        id: 'keep-id',
        fecha: 1000,
        creadoPor: 'creator',
        createdAt: 111,
      );
      final edited = original.copyWith(nombre: 'Nuevo nombre', lugar: 'Sala');
      expect(edited.id, 'keep-id');
      expect(edited.creadoPor, 'creator');
      expect(edited.createdAt, 111);
      expect(edited.nombre, 'Nuevo nombre');
    });
  });

  group('archive list filters and stats', () {
    test('active filter excludes archived', () {
      final list = [
        _event(id: 'a', fecha: 1),
        _event(id: 'b', fecha: 2, archivado: true),
      ];
      final filtered = applyAttendanceArchiveFilter(
        list,
        AttendanceArchiveListFilter.activos,
      );
      expect(filtered.map((e) => e.id), ['a']);
    });

    test('archived filter includes archived', () {
      final list = [
        _event(id: 'a', fecha: 1),
        _event(id: 'b', fecha: 2, archivado: true),
      ];
      final filtered = applyAttendanceArchiveFilter(
        list,
        AttendanceArchiveListFilter.archivados,
      );
      expect(filtered.map((e) => e.id), ['b']);
    });

    test('stats ignore archived', () {
      final now = DateTime(2026, 9, 5, 12);
      final todayStart = DateTime(2026, 9, 5).millisecondsSinceEpoch;
      final list = [
        _event(id: 'live', fecha: todayStart, estado: 'en_curso'),
        _event(
          id: 'arch',
          fecha: todayStart,
          estado: 'en_curso',
          archivado: true,
        ),
        _event(id: 'done', fecha: todayStart - 86400000, estado: 'finalizado'),
        _event(
          id: 'done-arch',
          fecha: todayStart - 86400000,
          estado: 'finalizado',
          archivado: true,
        ),
      ];
      expect(countAttendanceEventsHoy(list, now: now), 1);
      expect(countAttendanceEventsActivos(list, now: now), 1);
      expect(countAttendanceEventsFinalizados(list), 1);
    });

    test('archived badge wins over en_curso', () {
      final e = _event(id: 'x', fecha: 1, estado: 'en_curso', archivado: true);
      expect(attendanceEventBadgeLabel(e), 'Archivado');
    });
  });

  group('historical field lock', () {
    test('blocks destructive edit fields', () {
      expect(isAttendanceHistoricalFieldLocked('fecha'), isTrue);
      expect(isAttendanceHistoricalFieldLocked('fechaFin'), isTrue);
      expect(isAttendanceHistoricalFieldLocked('miembrosConvocados'), isTrue);
      expect(isAttendanceHistoricalFieldLocked('secureQrMode'), isTrue);
      expect(isAttendanceHistoricalFieldLocked('geofenceEnabled'), isTrue);
      expect(isAttendanceHistoricalFieldLocked('nombre'), isFalse);
      expect(isAttendanceHistoricalFieldLocked('descripcion'), isFalse);
      expect(isAttendanceHistoricalFieldLocked('lugar'), isFalse);
    });
  });

  group('RBAC visibility', () {
    test('delete hidden for unauthorized roles', () {
      expect(AttendanceEventActions.canDelete(UserRole.admin), isFalse);
      expect(
        AttendanceEventActions.canDelete(UserRole.operadorAsistencia),
        isFalse,
      );
      expect(AttendanceEventActions.canDelete(UserRole.superadmin), isTrue);
    });

    test('edit and archive allowed for attendance operators', () {
      expect(
        AttendanceEventActions.canEdit(UserRole.operadorAsistencia),
        isTrue,
      );
      expect(
        AttendanceEventActions.canArchive(UserRole.operadorAsistencia),
        isTrue,
      );
      expect(AttendanceEventActions.canEdit(UserRole.voter), isFalse);
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

    test('excludes archived from highlight', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final selected = AttendanceService.pickHighlightedOperationalEventId([
        _event(
          id: 'archived-curso',
          fecha: now,
          estado: 'en_curso',
          archivado: true,
        ),
        _event(id: 'live', fecha: now - 1000, estado: 'programado'),
      ]);
      expect(selected, 'live');
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
