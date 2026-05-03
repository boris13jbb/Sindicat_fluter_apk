import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/asistencia/evento.dart';
import 'package:fluter_apk/core/models/member.dart';
import 'package:fluter_apk/services/members_service.dart';

void main() {
  group('MembersService export helpers', () {
    test('builds CSV with every member, modalidad and attendance totals', () {
      final csv = MembersService.buildMembersExportCsv(
        [
          _member(
            id: '1',
            memberNumber: '200',
            firstName: 'Ana',
            lastName: 'Perez',
            modalidad: Modalidad.A,
          ),
          _member(
            id: '2',
            memberNumber: '100',
            firstName: 'Luis',
            lastName: 'Rojas',
            modalidad: Modalidad.N1,
          ),
        ],
        attendanceData: const {
          '1': MemberAttendanceExportData(
            totalConvocados: 5,
            totalAsistencias: 3,
            totalFaltas: 1,
            totalAusenciasJustificadas: 1,
            totalNoConvocado: 2,
            ultimoEvento: 'Asamblea General',
            ultimoEstado: 'Ausente justificado',
          ),
        },
      );

      expect(
        csv.split('\n').first,
        contains('numero_socio,nombres,apellidos,worker_code,modalidad'),
      );
      expect(
        csv.split('\n').first,
        contains(
          'eventos_convocados,asistencias,faltas,ausencias_justificadas,no_convocado',
        ),
      );
      expect(
        csv,
        contains(
          '200,Ana,Perez,W-200,A,D-200,,,Activo,5,3,1,1,2,60.0,Asamblea General,Ausente justificado',
        ),
      );
      expect(csv, contains('100,Luis,Rojas,W-100,N1,D-100,,,Activo,,,,,,,'));
    });

    test('sorts and filters export data independently from visible page', () {
      final members = [
        _member(
          id: '1',
          memberNumber: '200',
          firstName: 'Zoe',
          lastName: 'Mora',
          modalidad: Modalidad.B,
        ),
        _member(
          id: '2',
          memberNumber: '100',
          firstName: 'Ana',
          lastName: 'Alvarez',
          modalidad: Modalidad.A,
        ),
        _member(
          id: '3',
          memberNumber: '300',
          firstName: 'Luis',
          lastName: 'Brito',
          modalidad: Modalidad.N,
          status: MemberStatus.inactive,
        ),
      ];

      final sorted = MembersService.filterAndSortMembersForDisplay(members);
      expect(sorted.map((m) => m.memberNumber), ['100', '300', '200']);

      final active = MembersService.filterAndSortMembersForDisplay(
        members,
        status: MemberStatus.active,
      );
      expect(active.map((m) => m.memberNumber), ['100', '200']);

      final search = MembersService.filterAndSortMembersForDisplay(
        members,
        searchQuery: '300',
      );
      expect(search.map((m) => m.memberNumber), ['300']);
    });
  });
}

Member _member({
  required String id,
  required String memberNumber,
  required String firstName,
  required String lastName,
  required Modalidad modalidad,
  MemberStatus status = MemberStatus.active,
}) {
  final now = DateTime(2026, 1, 1);
  return Member(
    id: id,
    memberNumber: memberNumber,
    firstName: firstName,
    lastName: lastName,
    fullName: '$firstName $lastName',
    workerCode: 'W-$memberNumber',
    documentId: 'D-$memberNumber',
    modalidad: modalidad,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}
