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
import 'features/asistencia/crear_attendance_event_screen.dart';
import 'features/asistencia/evento_detail_screen.dart';
import 'features/asistencia/personas_screen.dart';
import 'features/asistencia/registro_manual_screen.dart';
import 'features/asistencia/asistencias_list_screen.dart';
import 'features/asistencia/exportar_screen.dart';
import 'features/asistencia/scanner_screen.dart';
import 'features/asistencia/importar_personas_screen.dart';
import 'features/asistencia/qr_codes_screen.dart';
import 'features/asistencia/route_args.dart';
import 'features/asistencia/attendance_event_detail_screen.dart';
// 🆕 Nuevas pantallas de gestión sindical
import 'features/members/members_list_screen.dart';
import 'features/members/import_members_screen.dart';
import 'features/attendance/attendance_report_screen.dart';
import 'features/audit/audit_logs_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'core/models/asistencia/evento.dart';
import 'core/models/user_role.dart';
import 'core/security/route_access.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
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
  }

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
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }
  }

  debugPrint('✅ Firebase inicializado correctamente');
}

Widget _authGuard(Widget child) => _RouteGuard(child: child);

Widget _roleGuard(Widget child, Set<UserRole> allowedRoles) {
  return _RouteGuard(allowedRoles: allowedRoles, child: child);
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.firebaseInitializer, this.readyApp});

  final Future<void> Function()? firebaseInitializer;
  final Widget? readyApp;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _firebaseInit;

  @override
  void initState() {
    super.initState();
    _firebaseInit = _runFirebaseInitializer();
  }

  void _retry() {
    setState(() {
      _firebaseInit = _runFirebaseInitializer();
    });
  }

  Future<void> _runFirebaseInitializer() {
    return (widget.firebaseInitializer ?? _initializeFirebase)();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'Sistema Integrado Sindicato',
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: const _StartupLoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Sistema Integrado Sindicato',
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: _FirebaseInitErrorScreen(
              error: snapshot.error,
              onRetry: _retry,
            ),
          );
        }

        return widget.readyApp ?? const MyApp();
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Inicializando servicios...'),
          ],
        ),
      ),
    );
  }
}

class _FirebaseInitErrorScreen extends StatelessWidget {
  const _FirebaseInitErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Error de conexión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudieron inicializar los servicios de Firebase.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifica la conexión, credenciales de Firebase y configuración de la plataforma antes de continuar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (kDebugMode && error != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
              _roleGuard(const CreateElectionScreen(), adminRouteRoles),
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
            return _roleGuard(
              AddCandidateScreen(electionId: id),
              adminRouteRoles,
            );
          },
          '/voto/edit_election': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return _roleGuard(
              EditElectionScreen(electionId: id),
              adminRouteRoles,
            );
          },
          '/voto/event_history': (_) =>
              _roleGuard(const EventHistoryScreen(), adminRouteRoles),
          '/asistencia': (_) =>
              _roleGuard(const AsistenciaHomeScreen(), attendanceRouteRoles),
          '/asistencia/crear_evento': (_) => _roleGuard(
            const CrearEventoAsistenciaScreen(),
            attendanceRouteRoles,
          ),
          '/asistencia/crear_attendance_event': (_) => _roleGuard(
            const CrearAttendanceEventScreen(),
            attendanceRouteRoles,
          ),
          '/asistencia/evento_detail': (ctx) {
            final evento =
                ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            if (evento == null) {
              return _roleGuard(
                const AsistenciaHomeScreen(),
                attendanceRouteRoles,
              );
            }
            return _roleGuard(
              EventoDetailScreen(evento: evento),
              attendanceRouteRoles,
            );
          },
          '/asistencia/attendance_event_detail': (ctx) {
            final eventId =
                ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            if (eventId.isEmpty) {
              return _roleGuard(
                const AsistenciaHomeScreen(),
                attendanceRouteRoles,
              );
            }
            return _roleGuard(
              AttendanceEventDetailScreen(eventId: eventId),
              attendanceRouteRoles,
            );
          },
          '/asistencia/personas': (_) => _roleGuard(
            const PersonasAsistenciaScreen(),
            attendanceRouteRoles,
          ),
          '/asistencia/registro_manual': (ctx) {
            final raw = ModalRoute.of(ctx)?.settings.arguments;
            EventoAsistencia? evento;
            String? attendanceEventId;
            if (raw is AsistenciaEventRouteArgs) {
              evento = raw.evento;
              attendanceEventId = raw.attendanceEventId;
            } else if (raw is EventoAsistencia) {
              evento = raw;
            }
            final okAttendance =
                attendanceEventId != null && attendanceEventId.isNotEmpty;
            if (!okAttendance && evento == null) {
              return _roleGuard(
                const AsistenciaHomeScreen(),
                attendanceRouteRoles,
              );
            }
            return _roleGuard(
              RegistroManualScreen(
                evento: evento,
                attendanceEventId: okAttendance ? attendanceEventId : null,
              ),
              attendanceRouteRoles,
            );
          },
          '/asistencia/asistencias': (_) =>
              _roleGuard(const AsistenciasListScreen(), attendanceRouteRoles),
          '/asistencia/exportar': (_) => _roleGuard(
            const ExportarAsistenciaScreen(),
            attendanceRouteRoles,
          ),
          '/asistencia/scanner': (ctx) {
            final raw = ModalRoute.of(ctx)?.settings.arguments;
            EventoAsistencia? evento;
            String? attendanceEventId;
            if (raw is AsistenciaEventRouteArgs) {
              evento = raw.evento;
              attendanceEventId = raw.attendanceEventId;
            } else if (raw is EventoAsistencia) {
              evento = raw;
            }
            return _roleGuard(
              ScannerAsistenciaScreen(
                evento: evento,
                attendanceEventId:
                    attendanceEventId != null && attendanceEventId.isNotEmpty
                    ? attendanceEventId
                    : null,
              ),
              attendanceRouteRoles,
            );
          },
          '/asistencia/importar_personas': (_) =>
              _roleGuard(const ImportarPersonasScreen(), attendanceRouteRoles),
          '/asistencia/qr_codes': (_) =>
              _roleGuard(const QRCodesScreen(), attendanceRouteRoles),
          // 🆕 Rutas de gestión sindical
          '/members': (_) =>
              _roleGuard(const MembersListScreen(), adminRouteRoles),
          '/members/import': (_) =>
              _roleGuard(const ImportMembersScreen(), adminRouteRoles),
          '/attendance/report': (ctx) {
            final eventId =
                ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            if (eventId.isEmpty) {
              return _roleGuard(
                const AsistenciaHomeScreen(),
                attendanceRouteRoles,
              );
            }
            return _roleGuard(
              AttendanceReportScreen(eventId: eventId),
              attendanceRouteRoles,
            );
          },
          '/audit/logs': (_) =>
              _roleGuard(const AuditLogsScreen(), adminRouteRoles),
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
        final decision = resolveProtectedRouteAccess(
          isLoading: auth.isLoading,
          isSignedIn: auth.isSignedIn,
          user: auth.user,
          allowedRoles: allowedRoles,
        );

        switch (decision) {
          case RouteAccessDecision.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case RouteAccessDecision.loginRequired:
            return const LoginScreen();
          case RouteAccessDecision.allowed:
            return child;
          case RouteAccessDecision.denied:
            return const _AccessDeniedScreen();
        }
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
