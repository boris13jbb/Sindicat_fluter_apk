import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/elections/elections_screen.dart';
import 'features/elections/create_election_screen.dart';
import 'features/elections/edit_election_screen.dart';
import 'features/elections/add_candidate_screen.dart';
import 'features/voting/voting_screen.dart';
import 'features/results/election_results_screen.dart';
import 'features/voto/event_history_screen.dart';
import 'features/asistencia/asistencia_home_screen.dart';
import 'features/asistencia/crear_evento_screen.dart';
import 'features/asistencia/evento_detail_screen.dart';
import 'features/asistencia/personas_screen.dart';
import 'features/asistencia/registro_manual_screen.dart';
import 'features/asistencia/asistencias_list_screen.dart';
import 'features/asistencia/exportar_screen.dart';
import 'features/asistencia/scanner_screen.dart';
import 'features/asistencia/importar_personas_screen.dart';
import 'features/asistencia/qr_codes_screen.dart';
// 🆕 Nuevas pantallas de gestión sindical
import 'features/members/members_list_screen.dart';
import 'features/members/import_members_screen.dart';
import 'features/attendance/attendance_report_screen.dart';
import 'features/audit/audit_logs_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'core/models/asistencia/evento.dart';
import 'core/models/user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with timeout to prevent hanging
    debugPrint('🔄 Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ Timeout inicializando Firebase (10s)');
        throw Exception(
          'Firebase initialization timeout - check network and Firebase config',
        );
      },
    );

    // Configuración de Firestore: solo activamos persistencia fuera de la Web
    // o de forma controlada para evitar el timeout del arranque.
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ Firestore persistencia habilitada');
      } catch (firestoreError) {
        debugPrint('⚠️ Error configurando Firestore: $firestoreError');
        debugPrint('Continuando sin persistencia...');
        // Fallback a configuración básica sin persistencia
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      }
    }
    debugPrint('✅ Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error inicializando Firebase: $e');
    debugPrint('Verifica que:');
    debugPrint('1. Las credenciales en firebase_options.dart sean correctas');
    debugPrint('2. Firebase Auth esté habilitado en Firebase Console');
    debugPrint('3. Tengas conexión a internet');
    debugPrint(
      '4. El appId para Windows sea correcto (debe ser el mismo que Web)',
    );
    debugPrint(
      '\nLa aplicación continuará pero Firebase no estará disponible.',
    );
  }

  runApp(const MyApp());
}

const _adminRoles = {UserRole.superadmin, UserRole.admin};
const _attendanceRoles = {
  UserRole.superadmin,
  UserRole.admin,
  UserRole.operadorAsistencia,
};

Widget _authGuard(Widget child) => _RouteGuard(child: child);

Widget _roleGuard(Widget child, Set<UserRole> allowedRoles) {
  return _RouteGuard(allowedRoles: allowedRoles, child: child);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: MaterialApp(
        title: 'Sistema Integrado Sindicato',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return auth.isSignedIn ? const HomeScreen() : const LoginScreen();
          },
        ),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignUpScreen(),
          '/home': (_) => _authGuard(const HomeScreen()),
          '/voto/elections': (_) => _authGuard(const ElectionsScreen()),
          '/voto/create_election': (_) =>
              _roleGuard(const CreateElectionScreen(), _adminRoles),
          '/voto/voting': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return _authGuard(VotingScreen(electionId: id));
          },
          '/voto/results': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return _authGuard(ElectionResultsScreen(electionId: id));
          },
          '/voto/add_candidate': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return _roleGuard(AddCandidateScreen(electionId: id), _adminRoles);
          },
          '/voto/edit_election': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return _roleGuard(EditElectionScreen(electionId: id), _adminRoles);
          },
          '/voto/event_history': (_) =>
              _roleGuard(const EventHistoryScreen(), _adminRoles),
          '/asistencia': (_) =>
              _roleGuard(const AsistenciaHomeScreen(), _attendanceRoles),
          '/asistencia/crear_evento': (_) =>
              _roleGuard(const CrearEventoAsistenciaScreen(), _attendanceRoles),
          '/asistencia/evento_detail': (ctx) {
            final evento =
                ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            if (evento == null) {
              return _roleGuard(const AsistenciaHomeScreen(), _attendanceRoles);
            }
            return _roleGuard(
              EventoDetailScreen(evento: evento),
              _attendanceRoles,
            );
          },
          '/asistencia/personas': (_) =>
              _roleGuard(const PersonasAsistenciaScreen(), _attendanceRoles),
          '/asistencia/registro_manual': (ctx) {
            final evento =
                ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            if (evento == null) {
              return _roleGuard(const AsistenciaHomeScreen(), _attendanceRoles);
            }
            return _roleGuard(
              RegistroManualScreen(evento: evento),
              _attendanceRoles,
            );
          },
          '/asistencia/asistencias': (_) =>
              _roleGuard(const AsistenciasListScreen(), _attendanceRoles),
          '/asistencia/exportar': (_) =>
              _roleGuard(const ExportarAsistenciaScreen(), _attendanceRoles),
          '/asistencia/scanner': (ctx) {
            final evento =
                ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            return _roleGuard(
              ScannerAsistenciaScreen(evento: evento),
              _attendanceRoles,
            );
          },
          '/asistencia/importar_personas': (_) =>
              _roleGuard(const ImportarPersonasScreen(), _attendanceRoles),
          '/asistencia/qr_codes': (_) =>
              _roleGuard(const QRCodesScreen(), _attendanceRoles),
          // 🆕 Rutas de gestión sindical
          '/members': (_) => _roleGuard(const MembersListScreen(), _adminRoles),
          '/members/import': (_) =>
              _roleGuard(const ImportMembersScreen(), _adminRoles),
          '/attendance/report': (ctx) {
            final eventId =
                ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            if (eventId.isEmpty) {
              return _roleGuard(const AsistenciaHomeScreen(), _attendanceRoles);
            }
            return _roleGuard(
              AttendanceReportScreen(eventId: eventId),
              _attendanceRoles,
            );
          },
          '/audit/logs': (_) =>
              _roleGuard(const AuditLogsScreen(), _adminRoles),
          '/profile': (_) => _authGuard(const UserProfileScreen()),
        },
      ),
    );
  }
}

class _RouteGuard extends StatelessWidget {
  const _RouteGuard({required this.child, this.allowedRoles});

  final Widget child;
  final Set<UserRole>? allowedRoles;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = auth.user;
        if (!auth.isSignedIn || user == null) {
          return const LoginScreen();
        }

        final roles = allowedRoles;
        if (roles == null || roles.contains(user.role)) {
          return child;
        }

        return const _AccessDeniedScreen();
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sin permisos')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'No tienes permisos para acceder a esta pantalla.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Si necesitas acceso, solicita la actualización de tu rol a un administrador.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
