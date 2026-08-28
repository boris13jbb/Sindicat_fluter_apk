import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/asistencia/member_attendance_summary.dart';

void main() {
  group('MemberAttendanceSummary', () {
    test('empty summary has zero counters', () {
      const summary = MemberAttendanceSummary.empty;
      expect(summary.totalConvocados, 0);
      expect(summary.totalAsistencias, 0);
      expect(summary.totalFaltas, 0);
      expect(summary.detalles, isEmpty);
    });

    test('aggregates detail rows', () {
      const summary = MemberAttendanceSummary(
        totalConvocados: 3,
        totalAsistencias: 2,
        totalFaltas: 1,
        totalNoConvocado: 0,
        detalles: [
          AsistenciaDetalle(
            eventId: 'ev-1',
            eventName: 'Asamblea',
            fecha: 1000,
            estado: 'presente',
          ),
          AsistenciaDetalle(
            eventId: 'ev-0',
            eventName: 'Legacy',
            fecha: 500,
            estado: 'ausente',
            isLegacy: true,
          ),
        ],
      );

      expect(summary.detalles.length, 2);
      expect(summary.detalles.last.isLegacy, isTrue);
    });
  });
}
