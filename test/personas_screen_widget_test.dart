import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fluter_apk/core/models/user.dart';
import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/features/asistencia/personas_screen.dart';
import 'package:fluter_apk/providers/auth_provider.dart';
import 'package:fluter_apk/services/auth_service.dart';

class _RoleAuthProvider extends AuthProvider {
  _RoleAuthProvider(UserRole role)
    : _user = AppUser(
        id: 'uid-${role.value}',
        email: '${role.value}@test.local',
        role: role,
      ),
      super(authService: AuthService());

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isLoading => false;

  @override
  bool get isSignedIn => true;
}

Widget _appForRole(UserRole role) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => _RoleAuthProvider(role),
    child: MaterialApp(
      routes: {
        '/members': (_) => const SizedBox.shrink(),
        '/asistencia/importar_personas': (_) => const SizedBox.shrink(),
      },
      home: PersonasAsistenciaScreen(
        combinedItemsLoader: () => Stream.value(const []),
      ),
    ),
  );
}

Future<void> _pumpForRole(WidgetTester tester, UserRole role) async {
  await tester.binding.setSurfaceSize(const Size(1024, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(_appForRole(role));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('OPERADOR_ASISTENCIA does not see /members actions', (
    tester,
  ) async {
    await _pumpForRole(tester, UserRole.operadorAsistencia);

    expect(find.byIcon(Icons.group_add_outlined), findsNothing);
    expect(find.text('Nueva persona'), findsNothing);
    expect(find.text('Importar lista'), findsOneWidget);
  });

  testWidgets('ADMIN sees /members actions', (tester) async {
    await _pumpForRole(tester, UserRole.admin);

    expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
    expect(find.text('Nueva persona'), findsOneWidget);
  });

  testWidgets('SUPERADMIN sees /members actions', (tester) async {
    await _pumpForRole(tester, UserRole.superadmin);

    expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
    expect(find.text('Nueva persona'), findsOneWidget);
  });
}
