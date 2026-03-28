import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'core/models/asistencia/evento.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Configuración de Firestore: solo activamos persistencia fuera de la Web 
    // o de forma controlada para evitar el timeout del arranque.
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    debugPrint('✅ Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error inicializando Firebase: $e');
    debugPrint('Verifica que:');
    debugPrint('1. Las credenciales en firebase_options.dart sean correctas');
    debugPrint('2. Firebase Auth esté habilitado en Firebase Console');
    debugPrint('3. Tengas conexión a internet');
  }

  runApp(const MyApp());
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
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return auth.isSignedIn ? const HomeScreen() : const LoginScreen();
          },
        ),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignUpScreen(),
          '/home': (_) => const HomeScreen(),
          '/voto/elections': (_) => const ElectionsScreen(),
          '/voto/create_election': (_) => const CreateElectionScreen(),
          '/voto/voting': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return VotingScreen(electionId: id);
          },
          '/voto/results': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return ElectionResultsScreen(electionId: id);
          },
          '/voto/add_candidate': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return AddCandidateScreen(electionId: id);
          },
          '/voto/edit_election': (ctx) {
            final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
            return EditElectionScreen(electionId: id);
          },
          '/voto/event_history': (_) => const EventHistoryScreen(),
          '/asistencia': (_) => const AsistenciaHomeScreen(),
          '/asistencia/crear_evento': (_) => const CrearEventoAsistenciaScreen(),
          '/asistencia/evento_detail': (ctx) {
            final evento = ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            if (evento == null) return const AsistenciaHomeScreen();
            return EventoDetailScreen(evento: evento);
          },
          '/asistencia/personas': (_) => const PersonasAsistenciaScreen(),
          '/asistencia/registro_manual': (ctx) {
            final evento = ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            if (evento == null) return const AsistenciaHomeScreen();
            return RegistroManualScreen(evento: evento);
          },
          '/asistencia/asistencias': (_) => const AsistenciasListScreen(),
          '/asistencia/exportar': (_) => const ExportarAsistenciaScreen(),
          '/asistencia/scanner': (ctx) {
            final evento = ModalRoute.of(ctx)?.settings.arguments as EventoAsistencia?;
            return ScannerAsistenciaScreen(evento: evento);
          },
        },
      ),
    );
  }
}
