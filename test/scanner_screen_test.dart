import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/asistencia/asistencia.dart';
import 'package:fluter_apk/core/models/asistencia/registro_asistencia_result.dart';
import 'package:fluter_apk/core/models/member.dart';
import 'package:fluter_apk/features/asistencia/scanner_screen.dart';
import 'package:fluter_apk/services/asistencia_registro_api.dart';

class _FakeAsistenciaService implements AsistenciaRegistroApi {
  _FakeAsistenciaService(this._result);

  final RegistroAsistenciaResult _result;

  @override
  Stream<List<EventoAsistencia>> getAllEventos() {
    return const Stream.empty();
  }

  @override
  Future<Map<String, int>> sincronizarMiembrosConPersonas() async {
    return {
      'sincronizados': 0,
      'omitidos': 0,
      'errores': 0,
      'total_procesados': 0,
    };
  }

  @override
  Future<RegistroAsistenciaResult> registrarAsistenciaDesdeEscaneo(
    String codigoEscaneado,
    String eventoId,
    MetodoRegistro metodo, {
    bool registrosAttendanceEvents = false,
  }) async {
    return _result;
  }
}

Member _member({
  required Modalidad? modalidad,
}) {
  final now = DateTime(2026, 1, 1);
  return Member(
    id: 'm1',
    memberNumber: '1',
    firstName: 'Juan',
    lastName: 'Pérez',
    fullName: 'Juan Pérez',
    workerCode: '123',
    documentId: '9999999',
    modalidad: modalidad,
    status: MemberStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

EventoAsistencia _evento() => EventoAsistencia(
      id: 'evento-1',
      nombre: 'Asamblea',
      fecha: 1,
      tipoReunion: TipoReunion.ordinaria,
    );

void main() {
  testWidgets('muestra nombre y modalidad al registrar por código', (
    WidgetTester tester,
  ) async {
    final service = _FakeAsistenciaService(
      RegistroAsistenciaResult(
        asistenciaId: 'a1',
        member: _member(modalidad: Modalidad.A),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScannerAsistenciaScreen(evento: _evento(), service: service),
      ),
    );

    await tester.enterText(find.byType(TextField), '{"identificador":"123"}');
    await tester.tap(find.text('Registrar asistencia'));
    await tester.pump(); // inicia el Future / animación del diálogo
    await tester.pump(const Duration(milliseconds: 300)); // termina transición

    expect(find.text('✅ Asistencia registrada'), findsOneWidget);
    expect(find.textContaining('Nombre: Juan Pérez'), findsOneWidget);
    expect(find.textContaining('Modalidad:'), findsOneWidget);
    expect(find.textContaining('Modalidad A'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('si modalidad es null, muestra "Sin asignar" sin bloquear registro', (
    WidgetTester tester,
  ) async {
    final service = _FakeAsistenciaService(
      RegistroAsistenciaResult(
        asistenciaId: 'a1',
        member: _member(modalidad: null),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScannerAsistenciaScreen(evento: _evento(), service: service),
      ),
    );

    await tester.enterText(find.byType(TextField), '{"identificador":"123"}');
    await tester.tap(find.text('Registrar asistencia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('✅ Asistencia registrada'), findsOneWidget);
    expect(find.textContaining('Nombre: Juan Pérez'), findsOneWidget);
    expect(find.textContaining('Sin asignar'), findsOneWidget);
  });
}

