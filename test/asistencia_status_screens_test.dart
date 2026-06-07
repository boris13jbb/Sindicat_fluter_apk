import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fluter_apk/features/asistencia/asistencia_acceso_restringido_screen.dart';
import 'package:fluter_apk/features/asistencia/asistencia_confirmada_screen.dart';
import 'package:fluter_apk/providers/auth_provider.dart';

Widget _app(Widget home) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('restricted attendance screen explains denied access', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AsistenciaAccesoRestringidoScreen()));
    await tester.pump();

    expect(find.text('No tienes permisos'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets('attendance confirmation screen exposes continue action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AsistenciaConfirmadaScreen()));
    await tester.pump();

    expect(find.text('¡Registro confirmado!'), findsOneWidget);
    expect(find.text('Continuar escaneando'), findsOneWidget);
  });
}
