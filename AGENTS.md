# AGENTS Guide - Sindicat_fluter_apk

## Big picture (what matters first)
- App Flutter multiplataforma (Android/iOS/Web/Windows) con backend Firebase (`lib/main.dart`, `lib/firebase_options.dart`).
- Arquitectura por capas: `features/` (UI), `providers/` (estado global), `services/` (reglas de negocio + Firestore), `core/models/` (serializacion).
- Flujo principal de arranque: `main()` inicializa Firebase con timeout de 10s y luego inyecta `AuthProvider` (`ChangeNotifierProvider` + `init()`).
- La navegacion usa rutas nombradas en `MaterialApp.routes` con prefijos funcionales (`/voto/*`, `/asistencia/*`).

## Boundaries and data flow
- Auth vive en `AuthProvider` + `AuthService`; UI decide `HomeScreen` vs `LoginScreen` segun `auth.isSignedIn`.
- Firestore es reactivo: servicios exponen `Stream` con `includeMetadataChanges: true` para detectar cache/pending writes.
- Votacion: `VoteService.castVote()` usa `WriteBatch` sobre 3 docs (`votes`, `candidates`, `elections`) para mantener contadores sincronizados.
- Auditoria separada: `EventService` escribe en coleccion `events` con metadatos de actor/resultado.
- Asistencia usa colecciones `eventos`, `personas`, `asistencias` y replica en subcoleccion `eventos/{id}/asistencias` por compatibilidad Android (`AsistenciaService.createAsistencia`).

## Project-specific conventions (follow these)
- Idioma de negocio y colecciones es mixto ES/EN (`elections` + `eventos`); no renombrar dominios existentes.
- Modelos usan `fromMap`/`toMap`; al guardar entidades nuevas se fuerza `id` en el map antes de `set()`.
- Para candidatos, el campo `order` debe existir en todos los docs (consultas hacen `.orderBy('order')`).
- Voto unico por usuario: ID de voto derivado `"{electionId}_{userId}"` sanitizado (ver `VoteService._voteId`).
- Firestore offline solo fuera de Web (`if (!kIsWeb) ... persistenceEnabled: true` en `lib/main.dart`).

## Security/integration constraints
- Reglas reales en `firestore.rules`; todo acceso requiere auth, votos no se pueden editar/eliminar.
- `users/{uid}`: lectura/actualizacion del propio usuario; `create` restringido a `role == 'VOTER'`.
- Windows usa config Firebase de Web (`DefaultFirebaseOptions.windows`), importante para evitar timeouts/permisos inconsistentes.

## Developer workflows (prefer these)
- Dependencias: `flutter pub get`.
- Analisis: `flutter analyze`.
- Tests: `flutter test` (hoy hay base minima en `test/widget_test.dart`).
- Ejecutar Windows de forma estable: `./run_windows.ps1` (agrega Git al PATH y limpia `build/windows` antes de `flutter run -d windows`).
- Ejecutar Web sin abrir multiples pestañas: `./run_web.ps1` (usa `web-server` puerto `8080`).
- Diagnostico Windows: `diagnose_windows.bat` (doctor, devices, clean, pub get).

## Where to look before editing
- Entry/rutas: `lib/main.dart`.
- Autenticacion/roles: `lib/providers/auth_provider.dart`, `lib/services/auth_service.dart`, `lib/core/models/user_role.dart`.
- Votacion/resultados: `lib/services/election_service.dart`, `lib/features/voting/`, `lib/features/results/`.
- Asistencia y exportes PDF/CSV: `lib/services/asistencia_service.dart`, `lib/features/asistencia/`.
- Seguridad y despliegue reglas: `firestore.rules`, `docs/setup/firestore-rules.md`.

