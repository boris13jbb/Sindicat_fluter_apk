import 'package:flutter_test/flutter_test.dart';

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
}
