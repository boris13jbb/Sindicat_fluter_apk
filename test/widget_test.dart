import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fluter_apk/main.dart';

void main() {
  testWidgets('shows login screen when there is no active session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Sistema Integrado Sindicato'), findsOneWidget);
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });

  testWidgets('shows Firebase init error and retries successfully', (
    WidgetTester tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap(
        firebaseInitializer: () async {
          attempts++;
          if (attempts == 1) {
            throw Exception('fallo firebase de prueba');
          }
        },
        readyApp: const MaterialApp(home: Text('App lista')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error de conexión'), findsOneWidget);
    expect(
      find.text('No se pudieron inicializar los servicios de Firebase.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('App lista'), findsOneWidget);
    expect(attempts, 2);
  });
}
