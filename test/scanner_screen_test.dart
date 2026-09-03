import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fluter_apk/core/models/asistencia/asistencia.dart';
import 'package:fluter_apk/core/models/asistencia/registro_asistencia_result.dart';
import 'package:fluter_apk/core/models/member.dart';
import 'package:fluter_apk/features/asistencia/scanner_screen.dart';
import 'package:fluter_apk/providers/auth_provider.dart';
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

Member _member({required Modalidad? modalidad}) {
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
  testWidgets('rechaza JSON legacy en override manual (camino separado)', (
    WidgetTester tester,
  ) async {
    final service = _FakeAsistenciaService(
      RegistroAsistenciaResult(
        asistenciaId: 'a1',
        member: _member(modalidad: Modalidad.A),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: ScannerAsistenciaScreen(evento: _evento(), service: service),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('scanner_manual_codigo')),
      '{"identificador":"123"}',
    );
    await tester.enterText(
      find.byKey(const Key('scanner_manual_motivo')),
      'motivo de prueba largo',
    );
    await tester.ensureVisible(find.text('Registrar override manual'));
    await tester.tap(find.text('Registrar override manual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('no acepta QR'), findsOneWidget);
    expect(find.text('Asistencia registrada'), findsNothing);
  });

  testWidgets('exige motivo obligatorio en override manual', (
    WidgetTester tester,
  ) async {
    final service = _FakeAsistenciaService(
      RegistroAsistenciaResult(
        asistenciaId: 'a1',
        member: _member(modalidad: null),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: ScannerAsistenciaScreen(evento: _evento(), service: service),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('scanner_manual_codigo')),
      '123',
    );
    await tester.ensureVisible(find.text('Registrar override manual'));
    await tester.tap(find.text('Registrar override manual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('motivo'), findsWidgets);
    expect(find.text('Asistencia registrada'), findsNothing);
  });

  testWidgets('expone botón Secure QR V2 separado del override', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: ScannerAsistenciaScreen(
            evento: _evento(),
            service: _FakeAsistenciaService(
              RegistroAsistenciaResult(
                asistenciaId: 'a1',
                member: _member(modalidad: Modalidad.A),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('scanner_secure_qr_v2')), findsOneWidget);
    expect(find.text('Registro manual excepcional'), findsOneWidget);
  });
}
