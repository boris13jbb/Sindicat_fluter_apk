# Expediente Técnico de la Aplicación

## 1. Información general del proyecto

| Ítem | Detalle |
|---|---|
| Nombre de la aplicación | Sistema Integrado Sindicato / VotaSind. El paquete Flutter se identifica como `fluter_apk`. |
| Objetivo principal | Gestionar procesos sindicales de votación electrónica, control de asistencia, padrón de socios, generación de códigos QR, resultados y auditoría. |
| Tipo de aplicación | Aplicación Flutter multiplataforma: Android, iOS, Web y Windows. |
| Público objetivo | Organización sindical, administradores, operadores de asistencia y votantes/socios. |
| Roles identificados | `SUPERADMIN`, `ADMIN`, `OPERADOR_ASISTENCIA`, `VOTER`, `USER`. |
| Tecnologías utilizadas | Flutter, Dart, Firebase Core, Firebase Auth, Cloud Firestore, **Firebase Storage**, Provider, PDF/Printing, File Picker, **image_picker**, Excel, CSV, Mobile Scanner, QR Flutter, Share Plus. |
| Backend / servicios externos | Firebase Authentication, Cloud Firestore y **Firebase Storage** (uso para fotos opcionales de candidatos tras aprovisionar Storage en consola y desplegar **`storage.rules`**). |
| Estado actual estimado | MVP avanzado / desarrollo funcional. La UI operativa de asistencia queda unificada para crear eventos nuevos en `attendance_events`, con **modalidades no convocadas** configurables en el alta (**`CrearAttendanceEventScreen`**) y editables desde el detalle (**`AttendanceEventDetailScreen`**, diálogo + icono en AppBar). `eventos` legacy se conserva como histórico/compatibilidad mediante `AsistenciaEventRouteArgs`. En **Mi Perfil**, el resumen de asistencia se consume con una **`StreamSubscription` única** compatible con **TabBarView** (véase **E-042**). **Alta/edición de candidatos**: URL de imagen opcional y foto opcional (**E-044**, ampliación **E-045** /**2026-05-02**): **`CandidateImageUploadSection`**, **`CandidatePhotoStorage`** (`uploadCandidateImage`, **`FirebaseStorage.instance`**, mismo ref para **`putFile`/`putData`** y **`snapshot.ref.getDownloadURL()`**); objetos bajo **`elections/{electionId}/candidates/{candidateId}/{archivo}`**; **`storage.rules`** mantiene además **`candidate_photos/`** por compatibilidad y quedó endurecido localmente en **E-046** para que sólo `SUPERADMIN`/`ADMIN` escriban/eliminen fotos. **`AndroidManifest`**: **`CAMERA`**; **`Info.plist`**: fototeca/cámara. Tras activar Storage en consola (**2026-05-02**), hubo deploy previo de reglas en **`sistema-integrado-sindicato`** (§F); el endurecimiento **E-046** compila en dry-run y requiere deploy real antes de operación. El modal **Editar candidato** usa **`await showDialog`** + **`finally`** para **dispose**, y omite **`setModal(saving=false)`** justo antes de **`Navigator.pop`** en guardado OK (evita assert **`_dependents.isEmpty`**). Tras **E-054**, el resumen de perfil ya no depende de un índice `COLLECTION_GROUP_ASC` sobre `asistencias.personaId`; en el estado local actual no existe `firestore.indexes.json` referenciado en `firebase.json`. Sigue recomendándose validación con datos/usuarios reales. |
| Arquitectura | Capa de UI en `lib/features`, estado global en `lib/providers`, servicios en `lib/services`, modelos en `lib/core/models`, tema y widgets compartidos en `lib/core`. |
| Punto de entrada | `lib/main.dart`. `AppBootstrap` inicializa Firebase con timeout de 10 segundos, muestra carga/error con reintento y sólo crea `AuthProvider` cuando Firebase está disponible; Firestore offline se configura fuera de Web. |

## 2. Alcance de la revisión

La revisión se realizó sobre el repositorio local `D:\Sindicat_fluter_apk`, mediante análisis estático del código, revisión de reglas Firestore y **reglas Firebase Storage** (**`storage.rules`**, **`firebase.json`**), rutas, pantallas, modelos, servicios, documentación existente y ejecución de comandos de QA disponibles.

### Elementos revisados

- Pantallas definidas en `MaterialApp.routes`.
- Pantallas internas abiertas con `MaterialPageRoute`.
- Módulos funcionales: autenticación, inicio, perfil, elecciones, votación, resultados, asistencia, socios, auditoría e importaciones.
- Menús, navegación, formularios, botones y acciones principales.
- Validaciones visibles en formularios.
- Estados de carga, vacío, error, éxito y sin permisos.
- Servicios Firestore: `AuthService`, `ElectionService`, `VoteService`, `AsistenciaService`, `AttendanceService`, `MembersService`, `ImportService`, `AuditService`, `EventService`.
- Modelos de datos y serialización `fromMap` / `toMap`.
- Reglas de seguridad en `firestore.rules` y, para candidatos con imagen subida, ejemplo en `storage.rules`.
- Documentación existente en `README.md` y `docs/`.
- Pruebas y análisis estático con Flutter.

### Verificaciones ejecutadas

| Comando | Resultado | Observación |
|---|---|---|
| `flutter analyze --no-pub` | Correcto | Sin issues detectados al 2026-05-01 después de correcciones. |
| `flutter test --no-pub --reporter expanded` | Correcto | 45 pruebas pasan: smoke de login sin sesión, error/reintento de `AppBootstrap`, contrato `AppUser.memberId`, matriz local de acceso por rol, validaciones de candidatos, rechazo lógico de borrado con votos y bloqueo lógico de nombres duplicados, visibilidad de resultados por rol/estado, regla `canVoteInElection`, serialización de `Election.status`, validación de fechas de elección, scanner, configuración de importación, parser CSV, modalidad de socios, plantillas XLSX/CSV de importación, prevalidación de archivos, exportación completa de socios y serialización/compatibilidad de `modalidadesNoConvocadas` en eventos legacy. |
| `firebase deploy --only firestore --dry-run` | Correcto | `firestore.rules` compila correctamente en dry-run después de alinear permisos de `members`/`import_logs`, endurecer `audit_logs` y validar `users.memberId`. |
| Firebase Emulator Suite para reglas | Pendiente/bloqueado | No se ejecutó por requisito local de Java 21+ para Firebase Tools/emuladores. |
| `firebase deploy --only storage` (CLI) contra **`sistema-integrado-sindicato`** | Correcto para deploy previo (**2026-05-02**); **E-046** sólo dry-run | Tras **Comenzar** en Storage (consola), **`firebase deploy --only storage`** liberó **`storage.rules`** de E-045. La versión endurecida **E-046** compila con **`--dry-run`** y queda pendiente de deploy real. Histórico: hasta **2026-04-30** el mismo comando fallaba si el proyecto no tenía bucket inicializado (*«Firebase Storage has not been set up…»*). |

### Convención de mantenimiento del expediente

- Este archivo es la **referencia técnico-funcional** del proyecto (alcance, pantallas, riesgos y pruebas sugeridas): cuando el código o Firestore cambien de forma relevante, debe **actualizarse aquí** (y registrar el cambio **arriba** en **§G Bitácora**) antes de comunicar alcance a terceros.
- No duplicar este contenido en otros documentos salvo **extractos** citando la versión autorizada de `expediente_tecnico_aplicacion.md`.

### Limitaciones de la revisión

- No se ejecutó una sesión manual completa con usuario real, Firebase real ni datos reales de producción.
- No se validó cámara física para escaneo QR en dispositivos Android/iOS.
- Despliegue por CLI de **reglas** al proyecto **`sistema-integrado-sindicato`** se ha ejecutado en entorno de desarrollo; la documentación histórica menciona despliegue de índices, pero en el estado local actual no existe `firestore.indexes.json` referenciado en `firebase.json`. Si se agregan índices compuestos, deben versionarse antes de desplegarlos y contrastarse en Firebase Console.
- **Firebase Storage:** **`storage.rules`** (v2) incluye **`elections/{electionId}/candidates/{candidateId}/{fileName}`** y regla paralela **`elections/{electionId}/candidate_photos/{fileName}`** para objetos legacy. La lectura exige usuario autenticado; **`create`/`update`/`delete`** quedan restringidos localmente a `SUPERADMIN`/`ADMIN` consultando **`users/{uid}.role`** desde reglas Storage (**E-046**). `create`/`update` validan imagen **&lt; 5 MB** y **`contentType`** `image/*`. Proyecto CLI en **`.firebaserc`**. La app nueva sube bajo **`candidates/{candidateId}/`** (**E-045**). Si el bucket no existiera en consola, **`firebase deploy --only storage`** no podría aplicarse hasta completar el asistente inicial; tras E-046 queda pendiente deploy real para que la restricción admin rija en el bucket remoto.
- No se revisaron capturas de pantalla ni diseño visual en navegador/dispositivo.
- En el estado local actual no se encontró **`firestore.indexes.json`**; cualquier índice creado solo en consola debe exportarse al archivo y agregarse a `firebase.json` antes de un deploy de índices. Tras **E-054**, el perfil evita la consulta que requería índice `COLLECTION_GROUP_ASC` sobre `asistencias.personaId`.
- No se probaron credenciales, roles reales ni permisos desde usuarios distintos.
- Las rutas protegidas se validaron por análisis estático y pruebas automatizadas de la decisión de acceso por rol; falta prueba manual por rol real con cuentas Firebase.
- Cualquier comportamiento dependiente de datos existentes queda marcado como pendiente de confirmar.

## 3. Mapa general de la aplicación

```text
Aplicación
├── Arranque y autenticación
│   ├── Carga inicial Firebase/AuthProvider
│   ├── Login
│   ├── Registro
│   └── Recuperación de contraseña
├── Inicio
│   ├── Tarjeta de usuario
│   ├── Sistema de Voto
│   ├── Sistema de Asistencia
│   ├── Gestión de Socios
│   └── Registro de Auditoría
├── Perfil
│   ├── Información de cuenta
│   ├── Resumen de asistencia y faltas del socio
│   └── Código QR del socio
├── Votación
│   ├── Listado de elecciones
│   ├── Crear elección
│   ├── Editar elección
│   ├── Agregar candidato (imagen: URL opcional o subida Storage **E-044**/ **E-045**)
│   ├── Emitir voto
│   ├── Resultados
│   └── Historial de eventos de voto
├── Asistencia
│   ├── Dashboard de asistencia (lista segmentada «Eventos / Históricos»)
│   ├── Crear evento de asistencia (`attendance_events`, convocatoria y **modalidades no convocadas**)
│   ├── Detalle de evento legacy
│   ├── Detalle de evento de asistencia (lectura + edición modalidades no convocadas)
│   ├── Escanear QR / ingreso manual (rutas unificadas con `AsistenciaEventRouteArgs`)
│   ├── Escáner continuo con cámara
│   ├── Registro manual (legacy o modelo nuevo según argumentos de ruta)
│   ├── Asistencias globales (legacy)
│   ├── Exportar asistencias
│   └── Reporte de asistencia (`generateAttendanceReport`: nuevo + fallback legacy)
├── Socios
│   ├── Listado de socios
│   ├── Crear / editar socio
│   └── Importación masiva
└── Auditoría
    ├── Audit logs
    └── Historial de eventos adaptado desde audit_logs
```

### Matriz de acceso por rol

La matriz refleja el contrato actual de navegación en `lib/main.dart` y la decisión reutilizable `resolveProtectedRouteAccess()` en `lib/core/security/route_access.dart`.

| Ruta / pantalla | SUPERADMIN | ADMIN | OPERADOR_ASISTENCIA | VOTER | USER | Control principal |
|---|---:|---:|---:|---:|---:|---|
| `/login`, `/signup` | Sí | Sí | Sí | Sí | Sí | Pantallas públicas de autenticación |
| `/home` | Sí | Sí | Sí | Sí | Sí | Requiere sesión |
| `/profile` | Sí | Sí | Sí | Sí | Sí | Requiere sesión; datos de socio por `users.memberId`/fallbacks |
| `/voto/elections` | Sí | Sí | Sí | Sí | Sí | Requiere sesión; servicio filtra elecciones votables |
| `/voto/voting` | Sí | Sí | Sí | Sí | Sí | Requiere sesión; UI/servicio bloquean elecciones inactivas, ocultas o fuera de fecha; `VoteService` valida voto único y reglas Firestore |
| `/voto/results` | Sí | Sí | Sí | Sí* | Sí* | Requiere sesión; votantes dependen de visibilidad/fin de elección |
| `/voto/create_election`, `/voto/edit_election`, `/voto/add_candidate`, `/voto/event_history` | Sí | Sí | No | No | No | `adminRouteRoles` |
| `/asistencia` y rutas hijas (`crear_evento`, `crear_attendance_event`, `evento_detail`, `attendance_event_detail`, `personas`, `registro_manual`, `asistencias`, `exportar`, `scanner`, `importar_personas`, `qr_codes`, `/attendance/report`) | Sí | Sí | Sí | No | No | `attendanceRouteRoles` |
| `/members`, `/members/import` | Sí | Sí | No | No | No | `adminRouteRoles`; reglas Firestore alineadas para `ADMIN`/`SUPERADMIN` |
| `/audit/logs` | Sí | Sí | No | No | No | `adminRouteRoles`; lectura de `audit_logs` sólo admin |

`Sí*`: acceso a la ruta autenticada, pero para no administradores la información de resultados exige elección activa, visible para votantes, `showResultsAutomatically` y fecha de fin cumplida.

### Módulos y dependencias

| Módulo | Propósito | Pantallas asociadas | Acciones disponibles | Dependencias |
|---|---|---|---|---|
| Autenticación | Controlar acceso y sesión | Login, Registro | Iniciar sesión, registrarse, recuperar contraseña, cerrar sesión | Firebase Auth, `users`, `AuthProvider` |
| Inicio | Navegar a módulos según rol | Home | Abrir voto, asistencia, socios, auditoría, perfil, cerrar sesión | `AuthProvider`, `UserRole`; dashboard visual responsivo rediseñado en **E-052** y navegación inferior tipo pie agregada en **E-053** |
| Perfil | Mostrar datos de cuenta, resumen de asistencia y QR del socio | Mi Perfil | Ver información, ver resumen de asistencias/faltas, ver QR, cerrar sesión | `users`, `members`, `attendance_events`, subcolecciones `asistencias`, `eventos`, `personas`, `QREncodingHelper`; stream de resumen expuesto como **broadcast** y consumido desde `UserProfileScreen` con **una sola `StreamSubscription`** tras **E-042** para coexistir con **TabBarView**; en **E-054** deja de usar `collectionGroup('asistencias')` para evitar índice global requerido por Firestore |
| Elecciones | Administración y consulta de elecciones | Elecciones, Crear, Editar, Agregar Candidato | CRUD de elecciones y candidatos; **`imageUrl`** del candidato puede ser URL manual **o** URL de subida a **Firebase Storage** (**E-044** / **E-045**: `elections/{electionId}/candidates/{candidateId}/`) | `elections`, `candidates`, **Firebase Storage**, `AuditService` |
| Votación | Emitir un voto único por usuario | Votar | Seleccionar candidato, confirmar voto, ver resultados | `votes`, `candidates`, `elections`, `asistencias`, `members` |
| Resultados | Visualizar y exportar conteos | Resultados | Ver ranking, exportar CSV/PDF | `elections`, `candidates`, `printing` |
| Asistencia legacy | Consultar y operar datos antiguos en `eventos` + `asistencias` globales | Home asistencia (tab Históricos), detalle `eventos`, Scanner/Registro con `AsistenciaEventRouteArgs.legacy` desde registros existentes | Compatibilidad con históricos; no es el flujo principal para crear eventos nuevos | `eventos`, `personas`, `asistencias`, `members` |
| Attendance modelo operativo | Eventos para convocados, presentes, faltantes y no convocados con `members` | Home (tab Eventos), crear/detalle `attendance_events`, Scanner/Manual con `AsistenciaEventRouteArgs.attendance`, FAB lista en AppBar → hub | Registro escribe `attendance_events/{id}/asistencias`; `personaId` es id Firestore del doc `members`; **`modalidadesNoConvocadas`** se define en el alta y se puede **editar** en el detalle (**E-043**) | `attendance_events`, subcolección `asistencias`, `members` |
| Socios | Administrar padrón sindical | Socios, Formulario, Importar | Listar por páginas, buscar, filtrar, **export CSV** (`MembersService.buildMembersExportCsv`), crear, editar, activar/desactivar, importar; **campo obligatorio `modalidad`** coherente con turnos (`Modalidad`) | `members`, `import_logs`, `audit_logs` |
| Auditoría | Trazabilidad de acciones | Audit Logs, Historial de Eventos | Consultar y filtrar registros | `audit_logs`; `events` queda como compatibilidad legacy |

## 4. Inventario detallado de pantallas

### Pantalla: Arranque / Control de sesión

**Ruta o ubicación:** `home` de `MaterialApp`, antes de rutas nombradas.

**Objetivo de la pantalla:** inicializar proveedor de autenticación y decidir si se muestra `HomeScreen` o `LoginScreen`.

**Elementos visibles:** indicador `CircularProgressIndicator` durante `auth.isLoading`.

**Acciones disponibles:** no aplica, es estado automático.

**Flujo paso a paso:**
1. `main()` renderiza `AppBootstrap`.
2. `AppBootstrap` inicializa Firebase con timeout de 10 segundos.
3. Si Firebase inicializa correctamente, se crea `MyApp`.
4. `MyApp` crea `AuthProvider` y ejecuta `init()`.
5. Se escucha `authStateChanges`.
4. Si hay usuario, se muestra Home.
5. Si no hay usuario, se muestra Login.

**Validaciones esperadas:** Firebase debe estar inicializado antes de crear `AuthProvider`; si falla, se muestra pantalla de error con botón **Reintentar** y no se navega a módulos dependientes de Firebase.

**Datos utilizados:** Firebase Auth, documento `users/{uid}`.

**Estados posibles:** inicializando servicios, error de inicialización con reintento, autenticado, no autenticado.

**Observaciones técnicas o funcionales:** corregido localmente. `AppBootstrap` usa `FutureBuilder` para separar el arranque Firebase de la app autenticada; muestra pantalla de carga, pantalla de error de conexión con reintento y detalle sólo en debug. Corregido localmente (**E-037**): el inicializador puede inyectarse en pruebas sin alterar producción y la prueba widget valida error inicial, botón **Reintentar** y éxito posterior.

**Problemas encontrados:** mitigado localmente el flujo en el que Firebase fallaba y la app continuaba hacia pantallas que dependen de Firebase sin mensaje claro.

**Huecos o pendientes por corregir:** queda pendiente validación manual en Windows/Web con red deshabilitada o configuración Firebase inválida.

**Prioridad de corrección:** Media.

**Recomendación:** mantener la inyección de inicializador sólo como punto de test y validar en plataforma real antes de entrega operativa.

### Pantalla: Login

**Ruta o ubicación:** `/login`.

**Objetivo de la pantalla:** permitir ingreso con email y contraseña.

**Elementos visibles:** título de la app, subtítulo, campo email, campo contraseña, botón mostrar/ocultar contraseña, enlace recuperar contraseña, botón iniciar sesión, enlace registro, mensajes de error/éxito.

**Acciones disponibles:** iniciar sesión, abrir recuperación de contraseña, navegar a registro.

**Flujo paso a paso:**
1. El usuario ingresa email.
2. Ingresa contraseña.
3. Presiona `Iniciar Sesión`.
4. `AuthProvider.signIn` llama a `AuthService.signIn`.
5. Firebase Auth valida credenciales.
6. Si hay sesión, se redirige a `/home`.
7. Si falla, se muestra mensaje de error.

**Validaciones esperadas:** email obligatorio, contraseña obligatoria, formato de email, credenciales válidas, usuario activo.

**Datos utilizados:** email, password, Firebase Auth, `users/{uid}`.

**Estados posibles:** cargando, error, éxito, autenticado, formulario inválido.

**Observaciones técnicas o funcionales:** existe validación de campos obligatorios y formato de email en login y recuperación de contraseña.

**Problemas encontrados:** corregido localmente. El botón `Enviar` del diálogo de recuperación se reevalúa al escribir, se bloquea con email inválido y muestra error local antes de llamar a Firebase. Si Firebase autentica pero no existe `users/{uid}`, el servicio cierra sesión y muestra mensaje claro.

**Huecos o pendientes por corregir:** falta prueba automatizada específica de recuperación y prueba con una cuenta real sin documento `users/{uid}`.

**Prioridad de corrección:** Media.

**Recomendación:** mantener reactividad del diálogo, cubrir validación de email con prueba widget y validar manualmente el caso de cuenta sin perfil Firestore.

### Pantalla: Registro

**Ruta o ubicación:** `/signup`.

**Objetivo de la pantalla:** crear una cuenta con email, contraseña y número de trabajador.

**Elementos visibles:** app bar, nombre completo, número de trabajador, email, contraseña, confirmar contraseña, mensaje de longitud mínima, botón crear cuenta.

**Acciones disponibles:** crear cuenta, volver.

**Flujo paso a paso:**
1. El usuario completa datos.
2. La UI valida número de trabajador, formato de email, contraseña mínima y confirmación.
3. `AuthProvider.signUpWithEmployeeNumber` llama a `AuthService`.
4. Se crea usuario en Firebase Auth.
5. `AuthService` valida que el número de trabajador exista en `members` por `workerCode` o `memberNumber` y que el socio esté activo.
6. Se crea documento en `users/{uid}`.
7. Se redirige a Home si la sesión queda activa.

**Validaciones esperadas:** número de trabajador obligatorio, existente en padrón activo, email válido, contraseña mínima, confirmación igual, rol seguro por defecto.

**Datos utilizados:** `email`, `displayName`, `employeeNumber`, `role`, Firebase Auth, `users`, `members`.

**Estados posibles:** formulario incompleto, cargando, error, éxito.

**Observaciones técnicas o funcionales:** `AuthProvider` y `AuthService` usan rol `VOTER` por defecto en auto-registro; las reglas Firestore también exigen `role == 'VOTER'`.

**Problemas encontrados:** corregido localmente. Las reglas Firestore ahora restringen `create` de `users/{uid}` al propio usuario, con campos permitidos y rol `VOTER`; la UI valida formato de email y actualiza el estado del botón al cambiar email/número de trabajador; `AuthService` valida padrón activo antes de escribir el perfil y revierte el usuario Auth si falla.

**Huecos o pendientes por corregir:** falta prueba con Firebase real/emulator para confirmar reglas, lectura de `members` y rollback de cuenta Auth.

**Prioridad de corrección:** Alta.

**Recomendación:** mantener la restricción de rol en reglas, agregar pruebas con Firebase Emulator y validar el flujo con socios activos/inactivos/no encontrados.

### Pantalla: Home / Dashboard principal

**Ruta o ubicación:** `/home`.

**Objetivo de la pantalla:** mostrar un dashboard inicial visual, responsivo y segmentado por rol para acceder a los módulos principales del sistema.

**Elementos visibles:** header morado con onda inferior, logo de la aplicación, título "Sistema Integrado Sindicato", botón de notificaciones, botón de perfil, botón de cerrar sesión, tarjeta de bienvenida con nombre y rol, ilustración de usuario, sección "Accesos principales", tarjetas de módulos en grilla responsiva, iconos, flechas de acceso, aviso inferior "Sistema seguro" y barra inferior flotante tipo pie con accesos Inicio, Voto, Asist., Socios y Perfil según permisos del rol.

**Acciones disponibles:** ir a Voto, Asistencia, Gestión de Socios, Auditoría, Perfil, usar navegación inferior, cerrar sesión.

**Flujo paso a paso:**
1. Se obtiene usuario desde `AuthProvider`.
2. Se renderiza el header institucional con acciones rápidas.
3. Se muestra tarjeta de bienvenida con nombre normalizado y rol.
4. Siempre se muestra Sistema de Voto.
5. Para `ADMIN` o `SUPERADMIN` se muestran Asistencia, Socios y Auditoría; para `OPERADOR_ASISTENCIA` se muestra Asistencia.
6. El usuario toca una tarjeta y navega al módulo autorizado.
7. El usuario puede abrir perfil, recibir feedback de notificaciones sin pendientes o cerrar sesión.
8. La barra inferior permite acceso rápido a Inicio, Voto, Asistencia, Socios y Perfil, mostrando sólo las opciones permitidas por rol.

**Validaciones esperadas:** rutas administrativas y operativas protegidas por rol además de ocultarse visualmente.

**Datos utilizados:** `AuthProvider.user`, `UserRole`.

**Estados posibles:** con usuario, sin usuario parcial, sin notificaciones pendientes, logout.

**Observaciones técnicas o funcionales:** corregido localmente. `main.dart` incorpora guard de autenticación y roles para rutas internas; la decisión de acceso fue extraída a `resolveProtectedRouteAccess()` con constantes `adminRouteRoles` y `attendanceRouteRoles` para cubrirla con pruebas puras. Home fue alineado para mostrar Asistencia a `OPERADOR_ASISTENCIA`. En **E-052** se rediseña `HomeScreen` según la referencia visual entregada, reemplazando el app bar clásico por header custom, grilla de tarjetas y aviso de seguridad, sin cambiar rutas ni reglas de visibilidad por rol. En **E-053** se agrega `_BottomHomeNavigation` como pie flotante y las tarjetas dejan de usar altura fija para evitar `BOTTOM OVERFLOWED` en móviles con textos largos o escala visual alta.

**Problemas encontrados:** mitigado localmente. Si un usuario autenticado abre una ruta no autorizada por nombre, se muestra pantalla de "Sin permisos". Corregido localmente en **E-053** el desbordamiento visual de tarjetas de acceso principal.

**Huecos o pendientes por corregir:** la matriz automatizada por rol ya existe; falta prueba manual con cuentas reales por rol y validación del despliegue de reglas en Firebase.

**Prioridad de corrección:** Media.

**Recomendación:** mantener el wrapper `_RouteGuard`, la matriz rol-ruta del expediente y el test `route_access_test.dart`; ejecutar validación manual con cuentas reales antes de producción.

### Pantalla: Mi Perfil

**Ruta o ubicación:** `/profile`.

**Objetivo de la pantalla:** mostrar información de cuenta, información sindical vinculada al padrón, resumen global de asistencia/faltas y QR personal de asistencia.

**Elementos visibles:** app bar, logout, tabs `Información` y `Código QR`, avatar, datos de cuenta, datos de socio (**modalidad visible solo como `Modalidad {letra}`** vía `JustificacionHelper.etiquetaModalidad`, p. ej. `Modalidad N`; sin texto descriptivo *Turno Mañana/Tarde/Noche*), tarjeta **Resumen de Asistencia** con eventos convocados, asistencias, faltas injustificadas, eventos no convocados y últimos eventos, mensaje de error resumido si el cálculo falla, QR o mensajes de indisponibilidad.

**Acciones disponibles:** alternar pestañas, cerrar sesión, volver.

**Flujo paso a paso:**
1. Carga usuario actual.
2. Busca socio por email, employeeNumber/workerCode, documentId, escaneo completo y displayName.
3. En pestaña información muestra cuenta y socio si existe (**valor de modalidad** desde `members.modalidad`; en UI sólo formato **«Modalidad X»**, no etiquetas narrativas de turno).
4. Si hay socio vinculado, `UserProfileScreen` escucha `AttendanceService.watchMemberAttendanceSummary(member.id)` y actualiza en tiempo real la tarjeta de resumen.
5. El resumen escucha `attendance_events` y, por cada evento, la subcolección `attendance_events/{id}/asistencias` filtrada por `personaId`; no usa `collectionGroup('asistencias')`.
6. El resumen cruza `attendance_events/{id}/asistencias`, `attendance_events.miembrosConvocados`, `attendance_events.modalidadesNoConvocadas` y fallback legacy `eventos`/`asistencias`/`personas`.
7. En QR genera código si existe `workerCode`.
8. Si no encuentra socio, muestra causas posibles.

**Validaciones esperadas:** usuario autenticado, socio activo, `workerCode` obligatorio para QR; el resumen sólo debe exponerse al socio dueño o a roles administrativos/operativos autorizados desde servicio.

**Datos utilizados:** `users`, `members`, `attendance_events`, `attendance_events/{id}/asistencias`, `eventos`, `asistencias`, `personas`, `QREncodingHelper`.

**Estados posibles:** cargando socio, socio encontrado, socio no encontrado, sin socios, socio sin workerCode, calculando resumen, resumen disponible, error/permisos del resumen, error de generación QR.

**Observaciones técnicas o funcionales:** el resumen se implementa como stream combinado: cambios en eventos, asistencias nuevas, eventos legacy o datos del socio disparan recalculo. Las faltas contabilizadas son injustificadas: asistencia ausente con `justificacion` se muestra como **Ausente justificado** y no suma a `totalFaltas`; socios en `modalidadesNoConvocadas` o fuera de una lista explícita `miembrosConvocados` se muestran como **No convocado** y tampoco suman faltas. Por compatibilidad, legacy considera convocados a todos los socios salvo eventos ya normalizados con `modalidadesNoConvocadas`. Corregido localmente (**E-042**): `AttendanceService.watchMemberAttendanceSummary` ya no usa `async*` + `yield*` (stream de una sola suscripción) y expone la cadena vía `Stream.fromFuture(...).asyncExpand(...).asBroadcastStream()`. Además, `UserProfileScreen` ya no monta un `StreamBuilder` para el resumen: usa una única `StreamSubscription`, cancela la suscripción anterior al cambiar de socio y cancela en `dispose`, evitando **`Bad state: Stream has already been listened to`** durante reconstrucciones de **TabBarView** / **PageView** en Windows. Corregido localmente (**E-054**): se elimina el `collectionGroup('asistencias').where('personaId')` que producía `failed-precondition` por índice `COLLECTION_GROUP_ASC`; ahora se crean listeners por evento y se agregan documentos en memoria. La UI del error deja de mostrar el enlace técnico de Firebase completo. La pantalla aún contiene mucha lógica de búsqueda y diagnóstico dentro de la UI.

**Problemas encontrados:** corregido localmente el error `failed-precondition` del resumen de asistencia mostrado en perfil. Persisten como deuda técnica el uso intensivo de `debugPrint`, la lógica compleja en widget y mensajes al usuario con pasos administrativos extensos.

**Huecos o pendientes por corregir:** mitigado localmente el vínculo canónico `users.memberId`: el auto-registro lo persiste, el login lo repara si puede resolver el socio por número de trabajador y el perfil lo usa antes de heurísticas. Falta desplegar reglas y validar/migrar usuarios existentes con datos reales.

**Prioridad de corrección:** Media.

**Recomendación:** validar `users.memberId` con cuentas reales, ejecutar migración controlada para usuarios existentes que no inicien sesión pronto y cubrir el resumen con pruebas de integración/emulator.

### Pantalla: Listado de Elecciones

**Ruta o ubicación:** `/voto/elections`.

**Objetivo de la pantalla:** listar elecciones disponibles; para admin, listar todas y permitir administración.

**Elementos visibles:** app bar, historial, logout, lista de tarjetas de elección, FAB crear elección para admin.

**Acciones disponibles:** votar, ver dashboard/resultados, editar, eliminar, agregar candidatos, abrir historial.

**Flujo paso a paso:**
1. Identifica si el usuario es admin/superadmin.
2. Admin escucha `getAllElections`.
3. Votante escucha `getActiveElections`.
4. Renderiza tarjetas con acciones según fecha y rol.
5. Permite eliminar con confirmación.

**Validaciones esperadas:** permisos por rol, elección activa dentro de fechas, visibilidad a votantes.

**Datos utilizados:** `elections`, `AuthProvider`.

**Estados posibles:** cargando, vacío, con datos, error, reintento.

**Observaciones técnicas o funcionales:** corregido localmente. `getActiveElections` reutiliza la regla central `canVoteInElection`, por lo que los votantes sólo reciben elecciones `isActive == true`, `isVisibleToVoters == true` y dentro del rango de fechas. Las tarjetas también usan el mismo estado para no habilitar el botón **Votar** en elecciones inactivas u ocultas.

**Problemas encontrados:** mitigado localmente el caso de elección visible/en rango pero `isActive=false`.

**Huecos o pendientes por corregir:** falta prueba widget/integración con Firebase real/emulator para confirmar navegación completa con datos reales.

**Prioridad de corrección:** Alta.

**Recomendación:** mantener `canVoteInElection` como contrato único de votación y cubrir navegación directa con pruebas de integración cuando el emulator esté disponible.

### Pantalla: Crear Elección

**Ruta o ubicación:** `/voto/create_election`.

**Objetivo de la pantalla:** crear elecciones con fechas, descripción y requisito opcional de asistencia.

**Elementos visibles:** formulario título, descripción, fecha inicio, fecha fin, switch requerir asistencia, selector evento, botón crear.

**Acciones disponibles:** seleccionar fechas, vincular evento de asistencia, crear elección.

**Flujo paso a paso:**
1. Verifica rol admin/superadmin.
2. Usuario completa título y descripción.
3. Selecciona inicio/fin.
4. Opcionalmente exige asistencia y selecciona evento legacy `eventos`.
5. Guarda en `elections`.

**Validaciones esperadas:** título/descripcion obligatorios, fechas obligatorias, fin posterior a inicio, evento obligatorio si requiere asistencia.

**Datos utilizados:** `elections`, `eventos`, usuario creador.

**Estados posibles:** sin permiso, cargando, formulario inválido, éxito, error.

**Observaciones técnicas o funcionales:** usa eventos de asistencia legacy (`eventos`), mientras el reporte nuevo usa `attendance_events`. Corregido localmente (**E-034**): `Election.toMap()` ya no persiste siempre `status: DRAFT`; deriva `DRAFT`, `ACTIVE` o `CLOSED` desde `isActive` y fecha de fin para mantener coherencia con el ciclo operativo actual. Corregido localmente (**E-035**): la validación de calendario queda centralizada en `validateElectionDateRange`/`validateElectionTimestampRange` y se aplica en UI y servicio.

**Problemas encontrados:** corregido localmente el rango de fechas: fin debe ser posterior a inicio y la duración mínima efectiva es 1 minuto. Queda pendiente definir reglas de estado inicial más avanzadas si negocio exige borrador programado, publicación diferida u otros estados.

**Huecos o pendientes por corregir:** queda pendiente definir si producto necesita estados adicionales explícitos como `SCHEDULED`, `PAUSED` o `ARCHIVED`; la incoherencia técnica `status: DRAFT` frente a `isActive` fue corregida localmente con E-034.

**Prioridad de corrección:** Media.

**Recomendación:** mantener `isActive` como contrato operativo mientras no exista flujo formal de ciclo de vida; si se agregan estados nuevos, actualizar reglas Firestore, UI, reportes y pruebas del modelo.

### Pantalla: Editar Elección

**Ruta o ubicación:** `/voto/edit_election`.

**Objetivo de la pantalla:** editar configuración de elección y gestionar candidatos.

**Elementos visibles:** formulario título/descripción/fechas, switches activo/visible/resultados/asistencia, selector evento, listado de candidatos, acciones editar/eliminar candidato, botón guardar.

**Acciones disponibles:** editar campos, agregar candidato, editar candidato en diálogo, eliminar candidato, guardar cambios.

**Flujo paso a paso:**
1. Carga elección y candidatos con `loadResultsBootstrap`.
2. Valida rol admin/superadmin.
3. Modifica datos.
4. Actualiza elección con `updateElection`.
5. Gestiona candidatos con subcolección `candidates`.

**Validaciones esperadas:** título/descripcion obligatorios, fechas válidas, evento requerido si asistencia obligatoria.

**Datos utilizados:** `elections`, `candidates`, `eventos`.

**Estados posibles:** cargando, acceso denegado, datos, sin candidatos, error, éxito.

**Observaciones técnicas o funcionales:** mitigado (**E-008** / bitácora): la **eliminación** de un candidato **con votos** queda **bloqueada** en UI y en `ElectionService` (no se permite dejar contadores incoherentes por borrado accidental). Corregido localmente (**E-039**): la regla de rechazo de borrado con votos se extrae a `validateCandidateDeletion` y queda cubierta por prueba automatizada. Corregido localmente (**E-035**): al guardar cambios se valida rango de fechas y evento vinculado cuando `requireAttendance` está activo; `ElectionService.updateElection` repite la validación para accesos programáticos. Corregido localmente (**E-036**): el diálogo de edición de candidato permite actualizar descripción, URL de imagen y orden con validación de URL http(s) y orden no negativo. Implementado (**E-044**) y ampliado (**E-045**): el diálogo usa **`CandidateImageUploadSection`**: foto en staging hasta **Guardar**; **`CandidatePhotoStorage.uploadCandidateImage`**; cierre seguro (**`await showDialog`** + **dispose** en **`finally`**, sin **`setModal`** de fin de guardado antes del **pop**) para evitar pantalla roja **`_dependents.isEmpty`**.

**Problemas encontrados:** puede seguir existiendo riesgo menor en **edición** de nombre/orden con elección ya en curso; está fuera del bloqueo explícito de eliminación.

**Huecos o pendientes por corregir:** riesgo residual de concurrencia si dos administradores modifican candidatos en paralelo; para garantía fuerte se requiere transacción, Cloud Function o política operativa de bloqueo de edición durante votación.

**Prioridad de corrección:** Media.

**Recomendación:** mantener cobertura de regresión sobre candidatos con votos; documentar política de “edición después de apertura” si aplica.

### Pantalla: Agregar Candidato

**Ruta o ubicación:** `/voto/add_candidate`.

**Objetivo de la pantalla:** registrar candidatos en una elección.

**Elementos visibles:** nombre, descripción, bloque **imagen opcional** (campo URL + texto de ayuda + botón **Elegir foto** con hoja inferior galería / cámara en plataformas nativas; en **Web** sólo flujos compatibles sin cámara expuesta explícita), orden, botón agregar.

**Acciones disponibles:** guardar candidato, volver, introducir URL http(s), subir foto a Storage (**opcional**) para rellenar automáticamente la URL de descarga, limpiar URL con control dedicado cuando hay texto.

**Flujo paso a paso:**
1. Recibe `electionId`.
2. Usuario ingresa datos; puede omitir imagen por completo.
3. Opcionalmente elige foto (staging): `ImagePicker` solo rellena el **`ValueNotifier`**; al guardar se llama **`CandidatePhotoStorage.uploadCandidateImage`** (**`putFile`** en nativo **`putData`** en Web), ruta **`elections/{electionId}/candidates/{candidateId}/{archivo}`**, luego **`snapshot.ref.getDownloadURL()`** y se persiste esa URL en **`imageUrl`** (y en el campo de texto para feedback).
4. Valida nombre y, si hay texto en URL, `validateCandidateImageUrl` (sólo http/https).
5. Crea documento en `elections/{id}/candidates` con `imageUrl` nulo o la URL indicada/upload.
6. Registra auditoría.

**Validaciones esperadas:** elección válida, nombre obligatorio, orden numérico, URL válida si hay texto (**vacío permitido**), tamaño cliente ≤ 5 MB antes de subir (coherente con reglas ejemplo de Storage).

**Datos utilizados:** `candidates`, `audit_logs`, **Firebase Storage** (subida nueva bajo `elections/{electionId}/candidates/{candidateId}/`; reglas siguen contemplando **`candidate_photos/`** para legado).

**Estados posibles:** cargando, subida de foto en curso (**Elegir foto**), error (red permisos Storage, tamaño), éxito.

**Observaciones técnicas o funcionales:** se garantiza campo `order`. **`SingleChildScrollView`** usa padding inferior **`viewPadding` + `viewInsets`** para no quedar tapado por barra del sistema/teclado. Widget reutilizable: **`lib/features/elections/candidate_image_upload_section.dart`**.

**Problemas encontrados:** corregido localmente (**E-036**) el campo URL de imagen y orden: alta/edición validan URL http(s) y orden entero no negativo. Corregido localmente (**E-038**) el bloqueo de nombres duplicados por elección en `ElectionService` con comparación normalizada. **E-044** / **E-045**: subida opcional alineada a reglas y bucket real; **`firebase deploy --only storage`** aplicado tras aprovisionamiento en consola (**2026-05-02**).

**Huecos o pendientes por corregir:** queda riesgo residual de concurrencia si dos administradores crean el mismo nombre simultáneamente desde clientes distintos; para garantía fuerte se requeriría transacción/Cloud Function o índice/ID determinístico de nombre.

**Prioridad de corrección:** Baja.

**Recomendación:** mantener validadores compartidos en `Candidate` y evaluar una garantía transaccional si se espera administración concurrente de boletas.

### Pantalla: Votar

**Ruta o ubicación:** `/voto/voting`.

**Objetivo de la pantalla:** permitir al usuario emitir un voto único por candidato.

**Elementos visibles:** app bar, estados de carga/error, información de elección, lista de candidatos tipo radio, botón emitir voto, diálogo de confirmación, pantalla de voto registrado.

**Acciones disponibles:** seleccionar candidato, confirmar voto, reintentar carga, ver resultados después de votar.

**Flujo paso a paso:**
1. Obtiene usuario actual desde Firebase Auth.
2. Escucha si ya votó con documento determinístico `electionId_userId`.
3. Carga elección y candidatos.
4. Verifica fechas.
5. Si requiere asistencia, valida asistencia.
6. Usuario selecciona candidato.
7. Confirma voto.
8. `VoteService.castVote` crea voto e incrementa contadores en batch.
9. Registra auditoría y muestra éxito.

**Validaciones esperadas:** usuario autenticado, elección existente, activa, no iniciada/finalizada, candidato seleccionado, voto único, asistencia si aplica, reglas Firestore correctas.

**Datos utilizados:** `elections`, `candidates`, `votes`, `members`, `personas`, `asistencias`, `attendance_events`, `audit_logs`.

**Estados posibles:** sin sesión, ya votó, cargando, elección inexistente, no iniciada, finalizada, sin candidatos, sin asistencia, error, éxito.

**Observaciones técnicas o funcionales:** hay validación de asistencia en UI y otra en `VoteService`; la lógica cruza `members`, `personas`, `asistencias` y `attendance_events`.

**Problemas encontrados:** reglas Firestore de actualización parcial usan `request.resource.data.keys().hasOnly(...)`, lo que probablemente bloquea incrementos en documentos existentes porque `request.resource.data` representa el documento completo post-update. Debe usarse `diff(resource.data).affectedKeys()`.

**Huecos o pendientes por corregir:** no hay prueba automatizada de voto con reglas; el botón de resultados después de votar usa la regla central `canViewElectionResults`, cubierta por prueba pura. Falta prueba widget/integración con Firebase real/emulator.

**Prioridad de corrección:** Media.

**Recomendación:** mantener `canViewElectionResults` como contrato único, probar conteo/voto con Firebase Emulator y validar ruta post-voto con usuario real.

### Pantalla: Resultados en Tiempo Real

**Ruta o ubicación:** `/voto/results`.

**Objetivo de la pantalla:** mostrar conteos por candidato y exportar resultados para admin.

**Elementos visibles:** header de elección, total votos, cantidad de candidatos, ranking, porcentajes, barras, ribbon de sincronización, botones CSV/PDF para admin.

**Acciones disponibles:** ver resultados, exportar CSV al portapapeles, compartir PDF.

**Flujo paso a paso:**
1. Carga elección y candidatos.
2. Escucha cambios de elección y candidatos.
3. Ordena por `voteCount`.
4. Calcula total desde suma de candidatos.
5. Muestra ranking y exportaciones.

**Validaciones esperadas:** elección existente, permisos de lectura, candidatos disponibles.

**Datos utilizados:** `elections`, `candidates`, `printing`, `Clipboard`.

**Estados posibles:** cargando, error, elección no encontrada, sin votos/candidatos, sincronizando, con resultados.

**Observaciones técnicas o funcionales:** el total mostrado se calcula por suma de candidatos, no por `election.totalVotes`. La visibilidad se centraliza en `canViewElectionResults`: `ADMIN`/`SUPERADMIN` pueden revisar resultados; roles no administrativos requieren elección activa, visible, publicación automática y fecha de fin cumplida.

**Problemas encontrados:** corregido localmente. Votantes ya no pueden ver resultados por ruta directa ni desde la pantalla de voto registrado si la elección no está activa/visible, no terminó o si `showResultsAutomatically` está desactivado.

**Huecos o pendientes por corregir:** política cubierta por prueba pura; falta prueba widget/integración con navegación real y datos Firebase.

**Prioridad de corrección:** Media.

**Recomendación:** mantener regla funcional: resultados visibles para `ADMIN`/`SUPERADMIN`; para votantes sólo si la elección está activa, visible, finalizada y con `showResultsAutomatically` activo.

### Pantalla: Historial de Eventos de Voto

**Ruta o ubicación:** `/voto/event_history`.

**Objetivo de la pantalla:** listar eventos de auditoría en formato de historial desde `audit_logs`.

**Elementos visibles:** app bar, filtro por entidad, lista de eventos con tipo, descripción, fecha, usuario y error.

**Acciones disponibles:** filtrar, reintentar, volver.

**Flujo paso a paso:**
1. Escucha `audit_logs` ordenado por timestamp.
2. Si hay filtro, filtra en cliente por entidad.
3. Muestra tarjetas o estado vacío.

**Validaciones esperadas:** permisos de lectura, índice por timestamp.

**Datos utilizados:** `audit_logs`; `events` queda disponible solo para compatibilidad legacy mediante `EventService.logEvent()`.

**Estados posibles:** cargando, vacío, error de permisos, error de índice, offline, con datos.

**Observaciones técnicas o funcionales:** `EventService.getAllEvents()` fue adaptado para mapear `AuditLog` a `VotoEvent`; `EventService.logEvent()` permanece como método legacy para escrituras directas en `events` si algún cliente antiguo lo usa. La pantalla de `audit_logs` usa límite inicial de 50 registros y botón **Cargar 50 registros más**; los filtros reinician el límite.

**Problemas encontrados:** corregido localmente el riesgo de pantalla vacía por colección `events` sin escrituras activas; falta validar con datos reales de `audit_logs`.

**Huecos o pendientes por corregir:** definir si `events` se elimina formalmente, se migra o se documenta como compatibilidad legacy.

**Prioridad de corrección:** Media.

**Recomendación:** mantener `audit_logs` como fuente canónica de auditoría, documentar `events` como legado y validar permisos/índices en Firestore real.

**Política técnica de auditoría vigente:**
- `audit_logs` es la fuente canónica para nuevas acciones críticas: altas/ediciones/bajas, votos, importaciones, asistencia y operaciones administrativas.
- `events` queda clasificado como colección legacy de compatibilidad. No debe usarse para nuevos flujos salvo clientes antiguos que todavía llamen `EventService.logEvent()`.
- Las pantallas nuevas deben leer `audit_logs`; si necesitan formato histórico de voto, deben adaptar desde `AuditLog` a vista, no escribir duplicado en `events`.
- No existe purga automática aprobada. `AuditService.cleanOldLogs()` debe considerarse herramienta administrativa controlada, no flujo UI estándar.
- Si se decide migrar `events`, la estrategia recomendada es crear un script idempotente `events` → `audit_logs` que conserve `timestamp`, actor, entidad y resultado; después marcar `events` como sólo lectura hasta retirar clientes antiguos.
- Retención legal/operativa de auditoría: pendiente de confirmar por negocio antes de habilitar borrado periódico.

### Pantalla: Control de Asistencia

**Ruta o ubicación:** `/asistencia`.

**Objetivo de la pantalla:** hub del módulo de asistencia: acciones rápidas y dos listas de eventos (**Eventos** operativos vs **Históricos** legacy).

**Elementos visibles:** acciones rápidas Escanear, Asistencias, **Crear evento** y Exportar; **segmento** «Eventos / Históricos»; lista inferior según segmento (stream `attendance_events` o stream `eventos`); **FAB crear** que siempre abre el formulario operativo de evento de asistencia.

**Acciones disponibles:** navegar a submódulos operativos, abrir detalle de evento operativo o histórico según lista, crear un único tipo de evento nuevo en `attendance_events`.

**Flujo paso a paso:**
1. Segmento **Eventos**: escucha **`AttendanceService.getAllEvents()`** → **`attendance_events`**.
2. Segmento **Históricos**: escucha `AsistenciaService.getAllEventos()` → colección legacy **`eventos`**.
3. Toque en evento operativo → `/asistencia/attendance_event_detail` con `String` id del doc.
4. Toque en evento histórico → `/asistencia/evento_detail` con `EventoAsistencia`.
5. Botón **Crear evento** o FAB → `/asistencia/crear_attendance_event`.

**Validaciones esperadas:** acceso para admin/operador, lecturas Firestore según colección activa.

**Datos utilizados:** `eventos` y/o `attendance_events`.

**Estados posibles:** cargando, vacío segmentado (mensajes distintos por pestaña), error, con eventos.

**Observaciones técnicas o funcionales:** rutas hijas siguen usando guards en `main.dart`. Corregido localmente (**E-040**): el hub deja de mostrar accesos redundantes a **Personas**, **Códigos QR** e **Importar Excel**; el QR canónico del socio queda centralizado en **Mi Perfil**, y la gestión/importación del padrón corresponde al módulo **Socios**. Corregido localmente (**E-041**): se unifica la creación de eventos; la UI ya no ofrece “Evento reporte” vs “Evento clásico”. Los nuevos eventos se crean en `attendance_events`, mientras `eventos` queda como histórico/compatibilidad.

**Problemas encontrados:** corregido localmente. `/asistencia` y subrutas permiten `ADMIN`, `SUPERADMIN` y `OPERADOR_ASISTENCIA`; usuarios sin rol autorizado ven "Sin permisos". Corregido localmente (**E-040**) exceso de accesos rápidos no operativos para asistencia. Corregida localmente (**E-041**) la doble decisión confusa de tipo de evento.

**Huecos o pendientes por corregir:** falta prueba manual con cuenta real `OPERADOR_ASISTENCIA`, test widget de acceso directo por ruta y decisión final sobre si las rutas legacy de creación deben retirarse o conservarse ocultas para migración/soporte.

**Prioridad de corrección:** Media.

**Recomendación:** documentar matriz rol-ruta y agregar pruebas automatizadas para rutas de asistencia.

### Pantalla: Crear Evento de Asistencia

**Ruta o ubicación:** `/asistencia/crear_evento`.

**Objetivo de la pantalla:** crear eventos legacy de asistencia.

**Elementos visibles:** nombre, descripción, tipo ordinaria/extraordinaria, selector fecha/hora, bloque **Modalidades no convocadas**, texto informativo de regla de negocio, chips multi-selección con `Modalidad A`, `Modalidad B`, … para el subconjunto `Modalidad.valoresParaJustificacionAsistencia`, mensaje cuando no hay exclusiones y botón guardar.

**Acciones disponibles:** seleccionar tipo, fecha, marcar/desmarcar una o varias modalidades no convocadas, guardar.

**Flujo paso a paso:**
1. Usuario ingresa nombre.
2. Opcionalmente ingresa descripción.
3. Selecciona tipo y fecha.
4. Opcionalmente selecciona modalidades **no convocadas**.
5. Guarda en `eventos` con `modalidadesNoConvocadas: List<String>`.

**Validaciones esperadas:** nombre obligatorio, fecha válida, permisos operador/admin; el campo `modalidadesNoConvocadas` no es obligatorio, lista vacía significa que no hay modalidades excluidas.

**Datos utilizados:** `eventos.modalidadesNoConvocadas`; compatibilidad de lectura con `eventos.modalidad` legacy.

**Estados posibles:** formulario, cargando, éxito, error.

**Observaciones técnicas o funcionales:** no usa `Form` ni `TextFormField`, validación manual del nombre. Corregido localmente: la modalidad ya no representa convocados; ahora la lista representa únicamente modalidades **no convocadas**.

**Problemas encontrados:** corregido localmente el selector simple incorrecto. Queda pendiente validar con datos reales que todas las modalidades del padrón estén completas para excluir correctamente faltantes.

**Huecos o pendientes por corregir:** lugar/convocados no existen en legacy, pero reporte nuevo espera esos campos en `attendance_events`.

**Prioridad de corrección:** Media.

**Recomendación:** unificar modelo de evento o mapear legacy a nuevo modelo sólo si negocio exige migración de datos histórios; la app ya permite operar ambos en paralelo.

### Pantalla: Crear Evento de Asistencia (`attendance_events`)

**Ruta o ubicación:** `/asistencia/crear_attendance_event`.

**Objetivo de la pantalla:** crear un documento en **`attendance_events`** con lugar, fecha, tipo, convocatoria «todos los socios activos» (lista `miembrosConvocados` vacía) o convocados específicos (IDs `members`), validando lista no vacía en modo específicos; opcionalmente definir **`modalidadesNoConvocadas`** (lista de códigos `Modalidad.value`, p. ej. `D`, `N1`) alineada al mismo subconjunto que eventos legacy (**`Modalidad.valoresParaJustificacionAsistencia`**).

**Elementos visibles:** formulario nombre/descripción/fecha/lugar/tipo; switch convocatoria; selector múltiple de socios cuando aplica; bloque **Modalidades no convocadas** con texto de ayuda, cajas informativas y **FilterChip** multi-selección; resumen visual cuando hay exclusiones.

**Acciones disponibles:** guardar; al éxito **cierra esta ruta con `Navigator.pop(eventId)`** para quien espera resultado y, en el frame siguiente, abre **`/asistencia/attendance_event_detail`**.

**Datos utilizados:** `members` (consultas), colección **`attendance_events`** (escritura vía `AttendanceService.createEvent`, campo `modalidadesNoConvocadas` incluido en el mapa).

### Pantalla: Detalle del Evento de Asistencia (`attendance_events`)

**Ruta o ubicación:** `/asistencia/attendance_event_detail` (`arguments`: id del doc).

**Objetivo de la pantalla:** ver metadatos del evento nuevo modelo (incluidas modalidades excluidas de convocatoria), lista de registros en subcolección **`asistencias`**, FAB reporte/manual/escáner y botón lista en AppBar; **editar** exclusiones por modalidad sin recrear el evento.

**Elementos visibles:** tarjeta con datos del evento; sección **Modalidades no convocadas** siempre visible (chips si hay datos, texto explicativo si la lista está vacía); botón **Editar** en la tarjeta; icono **filtro** en AppBar que abre el mismo editor; diálogo con chips y **Guardar** que llama **`AttendanceService.updateEvent`** (requiere rol operador según reglas).

**Datos utilizados:** `attendance_events/{id}`, `attendance_events/{id}/asistencias`.

**Observaciones técnicas:** registro manual y escáner se abren con **`AsistenciaEventRouteArgs.attendance(eventId)`**; icono lista usa **`pushNamedAndRemoveUntil('/asistencia', hasta `route.isFirst`)`** para volver siempre al hub de asistencia. La edición de modalidades recarga el documento con **`getEventById`** antes de persistir para no perder el resto de campos del **`AttendanceEvent`**.

### Pantalla: Detalle del Evento

**Ruta o ubicación:** `/asistencia/evento_detail`.

**Objetivo de la pantalla:** ver datos de un evento y sus registros de asistencia.

**Elementos visibles:** datos del evento, bloque **Modalidades no convocadas** con lista de códigos excluidos o mensaje “sin modalidades excluidas”, tipo, lista de registros; diálogo de edición con checkboxes para seleccionar varias modalidades no convocadas; botón eliminar evento; FAB reporte/registro manual/escanear.

**Acciones disponibles:** editar modalidades no convocadas, limpiar exclusiones, eliminar evento, eliminar asistencia, abrir reporte, registro manual, escanear QR.

**Flujo paso a paso:**
1. Recibe `EventoAsistencia` como argumento.
2. Muestra datos del evento.
3. Escucha asistencias por evento.
4. Para cada registro busca miembro asociado.
5. Permite borrar registro o navegar a acciones.

**Validaciones esperadas:** argumento obligatorio, permisos de operador, confirmación antes de borrar.

**Datos utilizados:** `eventos`, `asistencias`, `personas`, `members`.

**Estados posibles:** con datos, sin registros, cargando, error.

**Observaciones técnicas o funcionales:** cada registro dispara `FutureBuilder` para buscar miembro, lo cual puede generar muchas lecturas.

**Problemas encontrados:** mitigado (E-005). **`AttendanceService.generateAttendanceReport`** intenta primero **`attendance_events`** y, si no existe, **`eventos`** legacy; monta convocados y cruza `asistencias`/personas según modo. FAB reporte desde detalle legacy debe cargar estadísticas cuando hay datos suficientes en Firestore.

**Huecos o pendientes por corregir:** falta paginación y batch de lookup de miembros en la lista de registros legacy.

**Prioridad de corrección:** Media.

**Recomendación:** batch de lookups o desnormalizar nombre socio en escritura legacy.

### Pantalla: Scanner / Ingreso de código

**Ruta o ubicación:** `/asistencia/scanner`.

**Objetivo de la pantalla:** registrar asistencia mediante QR, código de barras o ingreso manual (**legacy `eventos`** o **`attendance_events`**).

**Argumentos de ruta:** `EventoAsistencia`; o **`AsistenciaEventRouteArgs`** (constructores `.legacy` / `.attendance`).

**Elementos visibles:** botón escanear QR, selector de evento legacy si no hay argumento único de evento, instrucciones, campo código, mensaje, botón registrar asistencia; título/carga pueden usar meta de **`attendance_events`** si viene `attendanceEventId`.

**Acciones disponibles:** seleccionar evento legacy, escanear con cámara, ingresar código, registrar.

**Flujo paso a paso:**
1. Sincroniza `members` → `personas`.
2. Resuelve **`eventId` efectivo** (legacy desde argumento/selección; reporte desde `widget.attendanceEventId`).
3. Llama **`registrarAsistenciaDesdeEscaneo`** con **`registrosAttendanceEvents: true`** si el contexto es `attendance_events` (escribe subcolección y resuelve `personaId` en `members`); si no, flujo **`createAsistencia`** legacy.
4. En caso de éxito, **muestra inmediatamente los datos del socio desde `members`**, incluyendo **Modalidad** (vía `JustificacionHelper.etiquetaModalidad`) con fallback **“Sin asignar”** si el socio no tiene modalidad.
5. **`ScannerQRScreen`** recibe **`eventId`** y el mismo flag para el callback.

**Validaciones esperadas:** evento resuelto, código no vacío, socio encontrado en modelo reporte (`members`).

**Datos utilizados:** `eventos`, `attendance_events`, `members`, `personas`, `asistencias` y subcolección **`attendance_events/.../asistencias`** según modo.

**Estados posibles:** sin evento legacy disponible cuando aplica selección manual, cargando meta reporte, éxito/error/duplicado.

**Observaciones técnicas:** el detalle legacy pasa **`AsistenciaEventRouteArgs.legacy`** desde `main.dart`; el hub «Escanear» sin argumentos sigue pudiendo obligar a elegir evento **`eventos`**.

**Problemas encontrados:** histórico E-004: habilitación con evento seleccionado; mantener regresión revisando modo sin argumentos.

**Huecos o pendientes por corregir:** prueba física por plataforma; permisos cámara (ver también escáner continuo).

**Prioridad de corrección:** Media.

**Recomendación:** caso de prueba TC-031 (modelo reporte) más TC-017 (legacy sin evento inicial).

### Pantalla: Escáner QR continuo con cámara

**Ruta o ubicación:** pantalla interna `ScannerQRScreen`, abierta desde `/asistencia/scanner`.

**Objetivo de la pantalla:** leer QR con cámara y registrar asistencias en modo continuo.

**Elementos visibles:** cámara, marco de escaneo, mensajes de éxito/error, botón linterna, cierre.

**Acciones disponibles:** escanear códigos, alternar linterna, volver/cerrar.

**Flujo paso a paso:**
1. Se abre con `eventoId`.
2. `MobileScanner` detecta barcode.
3. Bloquea duplicados por 2 segundos.
4. Ejecuta callback de registro.
5. Muestra **overlay temporal** con nombre/identificadores y **Modalidad** (desde `members`) y reanuda escaneo.

**Validaciones esperadas:** permiso de cámara, plataforma compatible, evento válido.

**Datos utilizados:** QR/barcode y `asistencias`.

**Estados posibles:** escaneando, éxito, error, reanudación.

**Observaciones técnicas o funcionales:** no hay fallback dentro de esta pantalla si la cámara no está disponible.

**Problemas encontrados:** limitación conocida en Web/Windows no está controlada con UI específica en este componente.

**Huecos o pendientes por corregir:** falta manejo explícito de permisos/cámara no disponible.

**Prioridad de corrección:** Media.

**Recomendación:** detectar plataforma/permisos y mostrar guía de ingreso manual.

### Pantalla: Registro Manual de Asistencia

**Ruta o ubicación:** `/asistencia/registro_manual`.

**Argumentos de ruta:** `EventoAsistencia`; o **`AsistenciaEventRouteArgs`** (solo uno de los dos contenidos válido).

**Objetivo de la pantalla:** registrar presente/ausente manualmente. **Dos modos:**
- **Legacy:** nueva persona opcional (`createPersona` + `registrarAsistenciaManual`).
- **`attendance_events`:** solo persona existente (lista members+legacy); **`personaId` en Firestore = id doc `members`**; duplicados vía **`AttendanceService.hasAttendanceRecord`**; persistencia **`registerAttendance`** (justificación/nota como `observaciones`/`justificacion` en servicio).

**Elementos visibles:** tarjeta de evento (legacy vs doc reporte cacheado); selector con **`_PersonaPickSheet`**; sin segmento «nueva persona» en modo reporte.

**Acciones disponibles:** sincronizar miembros, elegir persona, guardar según modo.

**Flujo paso a paso (legacy):**
1. Sincroniza miembros → personas.
2. Persona existente o nueva → `AsistenciaService.registrarAsistenciaManual`.

**Flujo paso a paso (reporte):**
1. Resuelve id `members` con **`_memberIdFirestoreParaAttendance`** desde fila **`member`**/`persona` y `identificador`.
2. **`hasAttendanceRecord`** + **`registerAttendance`**.

**Validaciones esperadas:** campos obligatorios según modo; no duplicado por usuario/evento.

**Datos utilizados:** según modo, `eventos`/`personas`/`asistencias` o `attendance_events` + subcolección `asistencias`.

**Estados posibles:** cargando combinación members+personas, vacío, error, duplicado, éxito; modo reporte con metadatos de evento cargando desde `AttendanceService.getEventById`.

**Problemas encontrados:** usa `firstOrNull`; compila con Flutter actual, pero conviene asegurar compatibilidad mínima real del SDK.

**Huecos o pendientes por corregir:** corregido localmente: lista con **búsqueda en modal inferior** (`_PersonaPickSheet`) en lugar de dropdown largo. Sigue recomendable **paginación o carga lazy** si el padrón supera cómodamente el millar de filas combinadas members+personas.

**Prioridad de corrección:** Baja/Media según tamaño real del padrón.

**Recomendación:** medir tamaño típico; si crece, limitar sincronización o cache local.

### Pantalla: Personas de Asistencia

**Ruta o ubicación:** `/asistencia/personas`.

**Objetivo de la pantalla:** listar personas/socios y mostrar QR.

**Elementos visibles:** buscador, lista combinada de `members` y `personas`, tarjetas QR.

**Acciones disponibles:** buscar y visualizar QR.

**Flujo paso a paso:**
1. Escucha `members`.
2. Consulta `personas`.
3. Combina sin duplicar por identificador.
4. Filtra por texto.
5. Muestra QR por socio o persona legacy.

**Validaciones esperadas:** lectura de miembros/personas, identificador disponible.

**Datos utilizados:** `members`, `personas`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** contiene imports no usados detectados por `flutter analyze`.

**Problemas encontrados:** consulta completa de `personas` por cada emisión de stream de `members`; puede escalar mal.

**Huecos o pendientes por corregir:** falta paginación, acciones de edición/eliminación para esta pantalla.

**Prioridad de corrección:** Media.

**Recomendación:** crear servicio combinado con caché, paginación y filtros Firestore si aplica.

### Pantalla: Códigos QR de Socios

**Ruta o ubicación:** `/asistencia/qr_codes`.

**Objetivo de la pantalla:** visualizar, copiar, compartir y eliminar QR legacy.

**Elementos visibles:** buscador, tarjetas QR de socios y personas legacy, acciones copiar/compartir/eliminar.

**Acciones disponibles:** buscar, copiar QR, compartir imagen QR, eliminar persona legacy.

**Flujo paso a paso:**
1. Combina `members` y `personas`.
2. Genera QR por `workerCode` o fallback.
3. Permite copiar contenido.
4. Captura QR como imagen y comparte.
5. Permite borrar persona legacy con confirmación.

**Validaciones esperadas:** QR no vacío, permisos de archivos/compartir según plataforma.

**Datos utilizados:** `members`, `personas`, archivos temporales, clipboard, share.

**Estados posibles:** cargando, vacío, error, con datos, éxito/error al compartir.

**Observaciones técnicas o funcionales:** `flutter analyze` advierte uso de `BuildContext` a través de gaps async.

**Problemas encontrados:** imports no usados y riesgo de `BuildContext` después de operaciones asíncronas.

**Huecos o pendientes por corregir:** falta exportación masiva de QRs.

**Prioridad de corrección:** Media.

**Recomendación:** ajustar checks `mounted/context.mounted` y agregar lote de impresión/descarga si el negocio lo necesita.

### Pantalla: Asistencias

**Ruta o ubicación:** `/asistencia/asistencias`.

**Objetivo de la pantalla:** listar todos los registros de asistencia con datos relacionados.

**Elementos visibles:** lista de asistencias con persona, evento, estado y fecha.

**Acciones disponibles:** volver.

**Flujo paso a paso:**
1. Escucha `asistencias`.
2. Carga eventos y personas relacionados.
3. Muestra lista global.

**Validaciones esperadas:** permisos de lectura y referencias válidas.

**Datos utilizados:** `asistencias`, `eventos`, `personas`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** no permite filtrar por evento, fecha o persona.

**Problemas encontrados:** sin paginación; carga relaciones en memoria.

**Huecos o pendientes por corregir:** faltan filtros y búsqueda.

**Prioridad de corrección:** Media.

**Recomendación:** agregar filtros por evento/fecha y paginación.

### Pantalla: Exportar Asistencias

**Ruta o ubicación:** `/asistencia/exportar`.

**Objetivo de la pantalla:** copiar CSV y exportar Excel/PDF desde **legacy** (`collection` `asistencias` + relaciones), sólo **reporte** (`attendance_events/*/asistencias` + nombres desde `members`), o **combinado** en memoria.

**Elementos visibles:** **SegmentedButton** «Legacy / Reporte / Ambos»; texto de ayuda por origen; contador y lista; prefijo «**[Reporte]**» en nombre de evento cuando el registro viene del modelo nuevo; en Reporte, botón «Actualizar lista reporte» (vuelve a leer Firestore).

**Acciones disponibles:** copiar CSV, generar Excel, generar PDF, actualizar (pestaña Reporte).

**Flujo paso a paso:**
1. **Legacy:** stream `watchAllAsistenciasConDatos()` (colección global `asistencias`).
2. **Reporte:** `AttendanceService.fetchAllAttendanceExportsRows()` (todos los docs `attendance_events` y subcolecciones `asistencias`, lookup batch de `members` por `personaId`).
3. **Ambos:** `asyncMap` sobre el stream legacy + mismo fetch reporte, lista fusionada y ordenada por `fechaRegistro` descendente.
4. Serializa como `AsistenciaConDatos` unificado; copia/comparte igual que antes.

**Validaciones esperadas:** lista no vacía antes de Excel/PDF, permisos de compartir; muchos eventos reporte ⇒ un `get` por evento en **paralelo** sobre subcolecciones `asistencias` (misma cantidad de lecturas, menor latencia acumulada).

**Datos utilizados:** `asistencias`, `eventos`, `personas`, `attendance_events`, subcolección `asistencias` bajo `attendance_events`, `members`, `printing`.

**Estados posibles:** cargando, vacío por pestaña (mensajes distintos), error, generando, éxito.

**Observaciones técnicas o funcionales:** `generateExcelExportStatic` sigue como hoja única **`Asistencias`**; mismo layout de columnas para ambos modelos.

**Problemas encontrados:** corregido localmente el riesgo de archivo CSV compartido como `.xlsx`; combinar muy grandes puede ser lento sin paginación.

**Huecos o pendientes por corregir:** filtros por evento/fecha concretos (el segmento Legacy/Reporte/Ambos **no** sustituye filtro dentro de cada modelo); modo **Combinado** dispara nueva lectura del bloque reporte en cada cambio del stream legacy (posible sobrecarga con padrón grande).

**Prioridad de corrección:** Media.

**Recomendación:** agregar prueba manual/automatizada que verifique que el archivo `.xlsx` generado abre correctamente en Excel/LibreOffice y conserva caracteres especiales.

### Pantalla: Importar Personas desde Excel

**Ruta o ubicación:** `/asistencia/importar_personas`.

**Objetivo de la pantalla:** importar personas legacy para asistencia y generar QR.

**Elementos visibles:** instrucciones, botón seleccionar archivo, resultado de importación, errores, ejemplo.

**Acciones disponibles:** seleccionar `.xlsx`, `.xls` o `.csv`, importar personas.

**Flujo paso a paso:**
1. Usuario selecciona archivo.
2. Se leen bytes.
3. Se decodifica con `Excel.decodeBytes`.
4. Se recorren filas con columnas A/B/C.
5. Se validan nombre, apellido, identificador.
6. Se omiten duplicados por identificador.
7. Se crean personas.

**Validaciones esperadas:** archivo legible, columnas requeridas, identificador único.

**Datos utilizados:** archivo local, `personas`.

**Estados posibles:** esperando archivo, procesando, éxito parcial, duplicados, errores.

**Observaciones técnicas o funcionales:** aunque permite elegir CSV, el flujo siempre usa `Excel.decodeBytes`.

**Problemas encontrados:** corregido localmente. Si la extensión es `.csv` se usa `ImportService.parseCsv` (RFC 4180/comillas); si es `.xlsx`/`.xls` sigue `Excel.decodeBytes`. Se detecta fila de encabezados típicos para omitirla.

**Huecos o pendientes por corregir:** vista previa de filas antes de insertar y plantilla descargable; prueba manual en Web/Android con archivo real.

**Prioridad de corrección:** Media.

**Recomendación:** ampliar pruebas con CSV con BOM, separador `;` regional y archivos grandes.

### Pantalla: Reporte de Asistencia

**Ruta o ubicación:** `/attendance/report`.

**Objetivo de la pantalla:** calcular convocados, presentes, faltantes, no convocados y tasa de asistencia.

**Elementos visibles:** información de evento, chips de modalidades no convocadas si existen, estadísticas, barra de asistencia, lista completa/faltantes con estado **No convocado / Justificado por modalidad** cuando aplica.

**Acciones disponibles:** alternar vista de faltantes, reintentar carga.

**Flujo paso a paso:**
1. Recibe `eventId` único desde la ruta.
2. **`generateAttendanceReport`** usa **`_getEventForReport`**: primero **`getEventById`** en **`attendance_events`**; si no existe, documento **`eventos/{eventId}`** y adapta metadatos a `AttendanceEvent` marcando modo **legacy**.
3. Carga convocados (`members` desde `miembrosConvocados` o todos activos si vacío según modelo).
4. Carga asistencias: subcolección **`attendance_events/.../asistencias`** o lecturas legacy (**`AsistenciaService`** sobre `asistencias`/`personas`) según bandera.
5. Aplica exclusión por `modalidadesNoConvocadas`: socios activos cuya `members.modalidad` esté en esa lista pasan a **no convocados** y no se cuentan como faltantes.
6. Calcula conjunto de presentes (en legacy cruza personas → miembros) y estadísticas sobre los convocados obligados.

**Validaciones esperadas:** evento existe en **`attendance_events`** *o* en **`eventos`**; convocados cargables.

**Datos utilizados:** `attendance_events` y/o `eventos`, `asistencias`, `personas`, `members.modalidad`, `eventos.modalidadesNoConvocadas`.

**Estados posibles:** cargando, error (evento inexistente en ambos), reporte vacío válido si no hay convocados, éxito con listas presentes/ausentes.

**Observaciones técnicas o funcionales:** botón FAB desde **`attendance_events`** usa el mismo endpoint; FAB desde **legacy** ya no falla sólo porque el doc no está en colección nueva (E-005). Corregido localmente: `AttendanceReport` incluye `totalNotConvoked` y `notConvokedMembers`.

**Problemas encontrados:** mitigado E-005 (**fallback legacy** en generación de reporte) y E-024 (modalidades excluidas no se cuentan como ausencias); error «Evento no encontrado» sólo si el id no existe ni en **`attendance_events`** ni en **`eventos`**.

**Huecos o pendientes por corregir:** export filtrado por evento/tipo modelo; prueba con alto volumen de convocados.

**Prioridad de corrección:** Baja/Media.

**Recomendación:** documentar para operadores: **día operativo reporte** = tab **Reporte** + detalle modelo nuevo + escaneo/registro lanzados desde ahí.


### Pantalla: Gestión de Socios

**Ruta o ubicación:** `/members`.

**Objetivo de la pantalla:** administrar padrón sindical.

**Elementos visibles:** buscador, filtro estado, **exportación CSV como reporte completo** (archivo real compartido desde sistema), botón importar, lista paginada de socios (si hay modalidad, tarjeta muestra **`Modalidad {código}`**), botón **Cargar más socios**, menú desactivar/reactivar, FAB nuevo socio.

**Acciones disponibles:** buscar, filtrar, **exportar todo el padrón con modalidad, asistencias, faltas, ausencias justificadas y no convocados**, crear, editar, activar/desactivar, importar.

**Flujo paso a paso:**
1. Carga la primera página de `members` con límite de 50 registros.
2. Permite cargar páginas adicionales con cursor Firestore.
3. Si el usuario busca texto, usa el flujo legacy de búsqueda flexible en cliente sobre `members`.
4. Muestra lista.
5. Permite abrir formulario.
6. Permite cambiar estado con confirmación.

**Validaciones esperadas:** permisos admin, búsqueda eficiente, estado correcto.

**Datos utilizados:** `members`, `attendance_events`, subcolecciones `attendance_events/{id}/asistencias`, `eventos`, `asistencias`, `personas`, `audit_logs`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** mitigado 2026-05-01: el listado normal usa `MembersService.getMembersPage()` con `limit` y cursor `startAfterDocument`; búsqueda textual conserva lectura completa por flexibilidad multi-campo. Corregido localmente (**E-048**): la exportación ya no comparte el CSV como texto; usa `Share.shareXFiles` con `XFile.fromData`, BOM UTF-8 y nombre `socios_reporte_completo_{timestamp}.csv`. `MembersService.fetchMembersForExport()` consulta toda la colección `members`, no sólo la página visible, y `filterAndSortMembersForDisplay()` mantiene ordenamiento reutilizable y testeado. Ampliado localmente (**E-049**): la exportación agrega columnas de asistencia por socio (`eventos_convocados`, `asistencias`, `faltas`, `ausencias_justificadas`, `no_convocado`, `porcentaje_asistencia`, `ultimo_evento_asistencia`, `ultimo_estado_asistencia`) calculadas con `AttendanceService.fetchMemberAttendanceSummariesForExport()` usando el mismo cruce funcional del perfil para modelo nuevo y legacy.

**Problemas encontrados:** paginación básica implementada para listado; búsqueda sigue leyendo completo. Exportación como archivo real corregida en E-048 y exportación con asistencias/faltas agregada en E-049.

**Huecos o pendientes por corregir:** falta eliminación permanente desde UI aunque existe en servicio; falta búsqueda indexada backend si el padrón supera volumen alto.

**Prioridad de corrección:** Media.

**Recomendación:** validar paginación con datos reales e implementar búsqueda indexada/backend si el padrón crece.

### Pantalla: Formulario de Socio

**Ruta o ubicación:** pantalla interna `MemberFormScreen`, abierta desde `/members`.

**Objetivo de la pantalla:** crear o editar socio.

**Elementos visibles:** número socio, nombres, apellidos, workerCode, **modalidad** (lista desplegable obligatoria; ítems con texto **`Modalidad {código}`** para todos los valores del enum, **A,B,C,D,E,N,N1,N2,X,Y,Z**, sin descripciones *Mañana/Tarde/Noche* en la lista), documento, email, teléfono, botón crear/actualizar.

**Acciones disponibles:** guardar, volver.

**Flujo paso a paso:**
1. Si es edición precarga datos.
2. Valida obligatorios.
3. Construye `Member`.
4. Crea o actualiza documento en `members`.
5. Registra auditoría.

**Validaciones esperadas:** número socio único, workerCode único, documento único, email válido, **modalidad presente y valor permitido (`Modalidad.tryParse`)** (`MembersService` rechaza alta/actualización sin modalidad).

**Datos utilizados:** `members` (campo `modalidad`), `audit_logs` (delta de cambios incluye **`modalidad`**), usuario autenticado.

**Estados posibles:** formulario, cargando, error, éxito.

**Observaciones técnicas o funcionales:** valida obligatorios; en alta y edición se comprueba unicidad contra Firestore para `memberNumber`, `documentId` y `workerCode` antes de persistir (`MembersService`).

**Problemas encontrados:** formato de teléfono y documento sigue siendo permisivo (sin máscaras ni validación estricta homogénea en todos los flujos).

**Huecos o pendientes por corregir:** reglas de formato acordadas con negocio (teléfono/documento); pruebas automatizadas de duplicados y conflictos en el servicio de socios.

**Prioridad de corrección:** Media.

**Recomendación:** formato de teléfono/documento acordados con negocio; alta cobertura de pruebas de socios contra emulator.

**Observación (2026-05):** la edición de modalidad sólo llega desde **Gestión de Socios** (rutas con rol admin/superadmin); el socio en **Mi Perfil** es lectura — alineado con que votantes no alteren turno desde la app.

### Pantalla: Importar Socios

**Ruta o ubicación:** `/members/import`.

**Objetivo de la pantalla:** importar padrón de socios desde CSV/Excel.

**Elementos visibles:** instrucciones, botón **Plantilla Excel**, selector archivo, tarjeta de **prevalidación del archivo**, botón importar, resumen de importación, errores/duplicados.

**Acciones disponibles:** compartir plantilla XLSX, seleccionar archivo, importar.

**Flujo paso a paso:**
1. Selecciona `.csv`, `.xlsx` o `.xls`.
2. Lee bytes.
3. Detecta tipo.
4. Normaliza columnas.
5. Valida filas.
6. Detecta duplicados en archivo y contra Firestore (número de socio, `workerCode`, documento cuando aplica).
7. Inserta en batches.
8. Guarda `import_logs` y `audit_logs`.

**Validaciones esperadas:** columnas obligatorias (`numero_socio`, `nombres`, `apellidos` y columna `modalidad` exigida por archivo), email válido si viene informado, duplicados, auth.

**Datos utilizados:** archivo local, `members`, `import_logs`, `audit_logs`.

**Estados posibles:** sin archivo, archivo seleccionado, procesando, éxito, éxito parcial, error.

**Observaciones técnicas o funcionales:** `ImportService.requiredColumns` sigue siendo **`numero_socio`, `nombres`, `apellidos`**, pero el archivo debe incluir también la columna **`modalidad` (obligatoria)** con valores exactos tipo `A`, `B`, `N1`, …; encabezados alternativos: `mod`, `modulo`, `turno` (véase `columnMappings`). `documento` es opcional. **Ya no se persiste modalidad dentro de `additionalData.mod`;** campo canónico en doc `members` es `modalidad`. Si existe `additionalData.mod` antiguo, `Member.fromMap` puede mapearlo como respaldo hasta normalizar datos. `ImportService.parseCsv()` usa `CsvToListConverter`, normaliza saltos CRLF/CR/LF y conserva campos entre comillas con comas internas. Corregido localmente (**E-047**): la pantalla puede compartir una **plantilla XLSX real** (`Socios` + `Modalidades`) desde `ImportService.buildMembersImportTemplateExcel()`, con pruebas que verifican encabezados y fila de ejemplo válida. Ajustado localmente (**E-051**): se retira el botón visible **Plantilla CSV** para evitar redundancia; la app conserva importación `.csv` y parser/preview CSV, pero la salida de plantilla visible queda sólo en Excel. También se agrega **prevalidación local** (`previewCsv` / `previewExcel`) antes de importar: muestra total de filas, válidas, inválidas, duplicados dentro del archivo y primeras observaciones; si hay advertencias, solicita confirmación antes de procesar filas válidas.

**Problemas encontrados:** corregido localmente el riesgo de datos mal partidos en CSV con comillas/comas internas; corregida localmente la ausencia de plantilla descargable desde la app y la falta de prevalidación local antes de confirmar escritura masiva (**E-047**). Retirada redundancia visual de plantilla CSV en **E-051**.

**Huecos o pendientes por corregir:** ampliar pruebas con comillas escapadas y saltos de línea dentro de campos; prueba manual de compartir plantilla y tarjeta de prevalidación en Windows/Web/Android; preview no consulta Firestore para detectar duplicados remotos, esa verificación sigue ocurriendo durante la importación real.

**Prioridad de corrección:** Media.

**Recomendación:** mantener el contrato de columnas y parser CSV cubiertos por tests (`test/import_service_test.dart`) y agregar preview antes de escritura masiva.

**Plantilla XLSX:** además del script **`tool/generate_socios_template.dart`**, la app genera plantilla desde **Importar Socios**. La plantilla in-app usa hoja `Socios` con columnas canónicas y hoja `Modalidades` con códigos aceptados.

### Pantalla: Registro de Auditoría

**Ruta o ubicación:** `/audit/logs`.

**Objetivo de la pantalla:** consultar logs técnicos de auditoría.

**Elementos visibles:** filtros por acción, entidad y fecha; lista de logs con acción, fecha, entidad, usuario, cambios y plataforma.

**Acciones disponibles:** filtrar, limpiar filtros, volver.

**Flujo paso a paso:**
1. Consulta `audit_logs`.
2. Aplica filtros opcionales.
3. Ordena por timestamp descendente.
4. Muestra tarjetas.

**Validaciones esperadas:** acceso admin, índices Firestore si se combinan filtros.

**Datos utilizados:** `audit_logs`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** la regla permite lectura a `isAdmin`.

**Problemas encontrados:** filtros combinados pueden requerir índices compuestos no documentados.

**Huecos o pendientes por corregir:** no hay paginación ni exportación de auditoría.

**Prioridad de corrección:** Media.

**Recomendación:** documentar índices necesarios y agregar paginación.

## 5. Flujos principales de usuario

### Flujo: Inicio de sesión

**Flujo ideal:**
1. Usuario abre la app.
2. Ingresa email y contraseña.
3. El sistema valida campos obligatorios y formato de email.
4. Firebase Auth valida credenciales.
5. Se carga `users/{uid}`.
6. Se redirige a Home.

**Flujos alternativos:** credenciales inválidas, usuario sin documento Firestore (se cierra sesión y muestra mensaje), Firebase no inicializado, red no disponible.

**Errores posibles:** `invalid-email`, `user-not-found`, `wrong-password`, error genérico de conexión.

**Mejoras recomendadas:** prueba automatizada de recuperación, validación con Firebase real y error claro si falta perfil.

### Flujo: Registro de usuario votante

1. Usuario abre Registro.
2. Completa nombre, número trabajador, email y contraseña.
3. Se crea cuenta Firebase Auth.
4. Se valida número de trabajador contra `members` por `workerCode` o `memberNumber`.
5. Si no existe o está inactivo, se elimina/cierra la cuenta recién creada y se muestra error.
6. Si es válido, se crea documento `users`.
7. Se asigna rol `VOTER` desde UI.

**Riesgo mitigado en reglas locales:** `firestore.rules` restringe `users` create al propietario y exige entre otros campos permitidos que `role == 'VOTER'` (ver bitácora E-002).

**Pendiente:** validar en Firebase Emulator o proyecto real que ningún cliente antiguo o binario compilado antes del despliegue cree roles elevados.

### Flujo: Crear elección y candidatos

1. Admin entra a Sistema de Voto.
2. Crea elección con título, descripción y fechas.
3. Opcionalmente vincula evento de asistencia.
4. Agrega candidatos (**nombre obligatorio**; **imagen siempre opcional**: URL manual **o** subida a Firebase Storage desde **Agregar candidato** o diálogo de edición (**E-044**/ **E-045**, ruta **`candidates/{id}/`**)).
5. Votantes ven elección activa si visible y en rango.

**Errores posibles:** permisos Firestore o **Storage** (si Storage no está aprovisionado o reglas deniegan `create`), fechas inválidas, candidato sin `order`, evento no seleccionado cuando `requireAttendance`, imagen &gt; 5 MB (rechazo en cliente o en reglas).

**Mejoras:** validar `isActive`, bloquear cambios destructivos con votos existentes.

### Flujo: Emitir voto

1. Votante abre elección.
2. Sistema verifica si ya votó.
3. Sistema verifica regla central de votación: activa, visible para votantes y dentro de fechas.
4. Si se requiere asistencia, verifica registro con stream combinado legacy (`asistencias`) y reporte (`attendance_events/{eventoAsistenciaId}/asistencias`).
5. Usuario selecciona candidato.
6. Confirma.
7. `VoteService.castVote` vuelve a validar el estado de la elección antes del batch.
8. Se muestra éxito.

**Errores posibles:** permiso denegado por reglas, voto duplicado, falta asistencia, elección inactiva u oculta, elección cerrada/no iniciada, candidato inexistente.

**Mejora crítica:** mantener alineados `canVoteInElection`, `VoteService.castVote` y `firestore.rules/electionIsOpen`.

### Flujo: Registrar asistencia por QR

1. Operador abre scanner.
2. Selecciona evento o recibe evento desde detalle.
3. Escanea QR o ingresa código.
4. Sistema parsea JSON/CSV/identificador.
5. Busca socio por workerCode.
6. Sincroniza/crea persona legacy.
7. Crea asistencia si no existe.

**Errores posibles:** evento no seleccionado, código vacío, QR inválido, duplicado, cámara no disponible.

**Mejora crítica:** corregir condición del botón manual cuando se abre sin evento.

### Flujo: Registro manual de asistencia

1. Operador abre evento.
2. Presiona registro manual.
3. Selecciona persona existente o crea nueva.
4. Marca asistió/no asistió.
5. Ingresa justificación.
6. Guarda.

**Errores posibles:** duplicado, persona sin identificador, error Firestore.

**Mejora:** agregar búsqueda/paginación en selector.

### Flujo: Importar socios

1. Admin abre Gestión de Socios.
2. Selecciona Importar.
3. Carga archivo CSV/Excel.
4. Sistema normaliza encabezados.
5. Valida columnas y filas.
6. Inserta en batches.
7. Muestra resumen.

**Errores posibles:** columnas no encontradas (**incluida `modalidad`**), valores de modalidad inválidos, CSV con comillas/comas, duplicados por número de socio, `workerCode` o documento.

**Mejora:** vista previa de importación antes de escritura masiva.

**Plantilla Excel en repo:** generar/regenerar con **`dart run tool/generate_socios_template.dart`** (véase tabla «Herramienta Plantilla socios» en §6).

### Flujo: Ver QR personal

1. Usuario abre perfil.
2. Sistema resuelve socio asociado.
3. Si existe `workerCode`, genera QR.
4. Si no existe, informa causa.

**Errores posibles:** socio no importado, email/workerCode no coinciden, socio inactivo.

**Mejora:** vincular usuario-socio explícitamente en datos.

## 6. Funcionalidades identificadas

| Módulo | Funcionalidad | Descripción | Estado | Observaciones | Prioridad |
|---|---|---|---|---|---|
| Login | Iniciar sesión | Acceso por email/password | Funcional/parcial | Validación local de email y error por perfil Firestore faltante implementados; falta prueba manual con usuario real | Alta |
| Login | Recuperar contraseña | Envía correo Firebase | Funcional/parcial | Botón reacciona al escribir y valida formato de email; falta prueba con Firebase real | Baja |
| Registro | Crear usuario | Crea Firebase Auth y `users` | Funcional/parcial | Email validado localmente, padrón activo requerido y reglas restringen rol `VOTER`; falta prueba con Firebase real/emulator | Media |
| Home | Navegación por rol | Muestra módulos según rol | Funcional/parcial | Guard de rutas implementado; falta prueba manual por rol real | Media |
| Perfil | Información socio | Muestra **«Modalidad X»** desde `members` (`etiquetaModalidad`) | Funcional/parcial | Matching heurístico usuario↔socio; si no hay `modalidad`, mensaje de pendiente administrativo (sin texto largo de turno) | Media |
| Perfil | Resumen de asistencia | Stream reactivo con eventos convocados, asistencias, faltas injustificadas, no convocados y últimos eventos | Funcional/parcial | Cruza modelo nuevo y legacy; respeta `miembrosConvocados` y `modalidadesNoConvocadas`; `users.memberId` implementado localmente; falta prueba con Firebase real/emulator | Alta |
| Perfil | QR personal | Genera QR desde socio | Parcial | Depende de matching heurístico con `members` y de `workerCode` | Media |
| Elecciones | Listar elecciones | Streams Firestore | Funcional/parcial | Votantes filtran `isVisibleToVoters`, `isActive` y rango de fechas; falta prueba con datos reales | Media |
| Elecciones | Crear/editar | CRUD elección | Funcional | Requiere unificar estados | Media |
| Candidatos | Agregar/editar/eliminar | Gestiona subcolección | Funcional/parcial | Eliminación bloqueada si el candidato tiene votos; alta/edición validan URL http(s) y orden; **foto opcional** (**E-044**/ **E-045**) vía **`CandidatePhotoStorage.uploadCandidateImage`**; reglas/deploy Storage verificados en proyecto **2026-05-02**; falta suite emulator Storage | Media |
| Voto | Emitir voto | Batch de voto y contadores | Parcial | UI, servicio y reglas locales validan elección activa, visible, en rango, asistencia legacy/reporte cuando aplica, voto propio y contadores; falta suite de reglas con emulator | Alta |
| Resultados | Ver conteos | Ranking en tiempo real | Funcional/parcial | Visibilidad para votantes centralizada y testeada; exportación CSV/PDF pide confirmación previa; falta prueba widget/Firebase real | Media |
| Asistencia | Crear evento legacy | Crea `eventos` con `modalidadesNoConvocadas` | Funcional | Selector múltiple de modalidades no convocadas; lista vacía significa sin exclusiones | Alta |
| Asistencia | Scanner | QR/código/manual | Funcional/parcial | Legacy y modelo reporte vía rutas/contexto (`AsistenciaEventRouteArgs`); falta prueba de cámara/dispositivo | Media |
| Asistencia | Registro manual | Alta manual | Funcional/parcial | Modo legacy o `attendance_events`; buscador en hoja inferior; padrón muy grande ⇒ coste en cliente | Media |
| Asistencia | Exportar | CSV/PDF/XLSX | Funcional/parcial | Segmentos **Legacy / Reporte / Ambos**; modelo reporte vía `fetchAllAttendanceExportsRows` (subs en paralelo); CSV/Excel/PDF piden confirmación previa por datos sensibles; falta **filtro fino** por evento/fecha dentro de cada origen y prueba manual con datos masivos | Media |
| Asistencia | Reporte faltantes | Calcula ausentes y no convocados | Funcional/parcial | Soporta `attendance_events` y fallback legacy; excluye `modalidadesNoConvocadas` de faltantes; falta prueba con datos reales | Media |
| Socios | CRUD | Listar por páginas, crear/editar/activar/desactivar | Funcional/parcial | **Modalidad obligatoria** en crear/actualizar; unicidad número, documento y `workerCode`; auditoría registra cambio de modalidad; listado `/members` paginado de forma incremental | Media |
| Socios | Importación masiva | CSV/Excel a `members` | Funcional/parcial | **Columna `modalidad` obligatoria** y validación estricta; `documento` opcional; duplicados y parser CSV robusto; plantilla XLSX visible desde la app, parser/preview CSV conservado para importación y prevalidación local (**E-047/E-051**); falta prueba con datos reales | Media |
| Socios | Exportación CSV | Reporte completo de padrón con modalidad, asistencias, faltas y no convocados | Funcional | `MembersService.fetchMembersForExport` lee toda la colección para exportar, no sólo la página visible; `AttendanceService.fetchMemberAttendanceSummariesForExport()` calcula totales por socio cruzando `attendance_events`, subcolecciones `asistencias`, `eventos`, `asistencias` legacy y `personas`; `buildMembersExportCsv` genera CSV con datos personales + métricas de asistencia y la UI comparte archivo `.csv` real con BOM UTF-8 (**E-048/E-049**); requiere confirmación previa por datos sensibles | Baja/Media |
| Herramienta | Plantilla `socios.xlsx` | Regeneración local | Funcional | Script **`dart run tool/generate_socios_template.dart`**: hoja **`Plantilla_socios`** (cabeceras + ejemplo fila código en `modalidad`) y hoja **`Modalidades`** (todas las letras **`documentar_como`** = **`Modalidad X`**). Si `socios.xlsx` está abierto en Excel, puede generarse **`socios_plantilla.xlsx`** en raíz hasta poder sobrescribir. | Media |
| Auditoría | `audit_logs` | Registra acciones críticas | Funcional/parcial | Pantalla limitada inicialmente a 50 registros con carga incremental; filtros por acción/entidad/fecha; índices y datos reales pendientes | Media |
| Auditoría | Historial de eventos | Mapea `audit_logs` a eventos visuales | Funcional/parcial | `events` queda como compatibilidad legacy; falta validar con datos reales | Media |

## 7. Errores, inconsistencias y problemas encontrados

| ID | Pantalla/Módulo | Problema | Descripción | Impacto | Prioridad | Recomendación |
|---|---|---|---|---|---|---|
| E-001 | Firestore reglas / Voto | Corregido localmente: regla de actualización parcial | Se cambió a validación de campos modificados con `diff`, voto propio y contadores exactos. | Reduce fallos `permission-denied` y manipulación de contadores. | Alta | Agregar pruebas con Firebase Emulator antes de producción. |
| E-002 | Firestore reglas / Users | Corregido localmente: creación de usuario restringida | `allow create` valida usuario propietario, campos permitidos y `role == 'VOTER'`. | Reduce riesgo de escalamiento si cliente manipula payload. | Alta | Validar con emulator y usuarios reales. |
| E-003 | Elecciones | Corregido localmente: filtro de elecciones activas | `getActiveElections` filtra `isActive`, visibilidad y rango de fechas. | Evita mostrar elecciones desactivadas a votantes. | Media | Cubrir con prueba de servicio o integración. |
| E-004 | Scanner | Corregido localmente: evento real seleccionado | El botón/registro usa `_eventoReal`, contemplando evento inicial o seleccionado. | Permite registrar asistencia desde scanner con evento seleccionado. | Media | Probar en dispositivo con cámara. |
| E-005 | Reporte asistencia | Corregido localmente: fallback legacy | El reporte detecta evento nuevo o legacy; para `eventos` lee `asistencias/personas` y cruza contra `members`. | Evita fallo al abrir reporte desde detalle legacy. | Media | Validar con datos reales y definir fuente canónica futura. |
| E-006 | Socios importación | Corregido localmente: documento opcional + **modalidad obligatoria por archivo** | `requiredColumns` sigue (`numero_socio`, `nombres`, `apellidos`); el archivo **debe** incluir columna **modalidad** validada contra `Modalidad.tryParse`; `documento` no es obligatorio. | Padrón con turno definido para perfil/exportación/coherencia con asistencia. | Media | Mantener `test/import_service_test.dart` alineado; migrar filas legacy sin `modalidad` en Firestore. |
| E-007 | Socios | Corregido localmente: unicidad de identificadores | Crear/actualizar validan `memberNumber`, `documentId` y `workerCode`; importación valida duplicados en archivo y Firestore. | Reduce sobrescrituras o socios duplicados. | Media | Agregar pruebas con mocks/emulator para altas y ediciones. |
| E-008 | Candidatos | Corregido localmente: bloqueo de eliminación con votos | UI y servicio impiden eliminar candidatos con `voteCount > 0` o votos existentes en `votes`. | Reduce inconsistencias en resultados. | Media | Agregar prueba de servicio/UI para candidato con votos. |
| E-009 | Tests | Corregido localmente: test por defecto reemplazado | La suite actual pasa con smoke real de login sin sesión, contrato de importación y parser CSV con comillas/comas internas. | La base de QA vuelve a ser ejecutable. | Media | Ampliar cobertura de login, roles, voto y asistencia. |
| E-010 | Login | Corregido localmente: recuperación de contraseña reactiva y email válido | El botón Enviar se habilita/deshabilita al escribir, valida formato de email y muestra carga durante envío. | Usuario puede solicitar reset desde diálogo con menor ruido de errores evitables. | Baja | Agregar prueba widget y validación con Firebase real. |
| E-011 | Historial de eventos | Corregido localmente: consolidación con `audit_logs` | `EventService.getAllEvents()` lee `audit_logs` y adapta `AuditLog` a `VotoEvent`; `events` queda como legacy. | Evita historial vacío por falta de escrituras en `events`. | Media | Validar con registros reales, permisos e índices. |
| E-012 | Exportar asistencia | Corregido localmente: XLSX real | `generateExcelExportStatic` ahora crea libro XLSX con `package:excel`, hoja y columnas de asistencia. | Reduce confusión/error al abrir el archivo exportado. | Media | Validar apertura manual con Excel/LibreOffice y datos reales. |
| E-013 | CSV import | Corregido localmente: parser CSV robusto | `parseCsv` usa `CsvToListConverter`, normaliza saltos de línea y respeta campos entre comillas con comas internas. | Reduce corrupción de datos en importaciones reales. | Media | Agregar casos con comillas escapadas, saltos de línea internos y archivos reales. |
| E-014 | Permisos UI | Corregido localmente: rutas con guard | Las rutas internas se protegen por autenticación y roles; usuarios no autorizados ven "Sin permisos". | UX más clara y menor exposición accidental. | Media | Agregar tests de rutas por rol y validación manual. |
| E-015 | Performance | Lecturas completas | Members/personas/asistencias se cargan completos en varias pantallas. | Rendimiento bajo en padrones grandes. | Media | Paginación, filtros, índices. |
| E-016 | Login | Corregido localmente: cuenta sin perfil Firestore | `AuthService.signIn` valida que exista `users/{uid}` después de Firebase Auth; si falta, cierra sesión y devuelve mensaje claro. | Evita sesión fantasma sin navegación ni explicación. | Alta | Probar con cuenta real sin documento `users/{uid}`. |
| E-017 | Registro | Corregido localmente: email válido, botón reactivo y padrón activo | `SignUpScreen` valida formato de email y `AuthService` exige socio activo en `members` por `workerCode` o `memberNumber`; si falla, revierte/cierra el usuario Auth recién creado. | Reduce rechazos tardíos, usuarios huérfanos y cuentas sin socio asociado. | Media | Agregar prueba widget/emulator con socio activo, inactivo y no encontrado. |
| E-018 | Socios modalidad turno | Corregido localmente: modelo y flujos alineados | Campo **`modalidad`** en `members` (enum `Modalidad` compartido con eventos legacy), formulario/import/export/perfil/admin; migra opcional desde `additionalData.mod`. Socios históricos sin campo requieren edición o masa de datos antes de otros updates vía servicio si aplica. **Ampliación 2026-05:** UX unificada: en **perfil, socios y selectores revisados** el usuario ve solo **`Modalidad {letra}`** (`JustificacionHelper.etiquetaModalidad`); en **detalle/creación evento legacy** el picker de convocatorias usa sólo **`Modalidad.valoresParaJustificacionAsistencia`** (sin X/Y/Z) y sin subtítulos *Mañana/Tarde/Noche*; plantilla **`socios.xlsx`** vía **`tool/generate_socios_template.dart`**. | Coherencia documental y legibilidad en campo. | Media | Ejecutar script con Excel cerrado; completar datos legacy sin `modalidad`. |
| E-019 | Firestore reglas / Socios e importaciones | Corregido localmente: permisos `ADMIN` coherentes con UI | `firestore.rules` permite ahora `create` en `members` e `import_logs` a `isAdmin()` (`SUPERADMIN` o `ADMIN`), manteniendo `delete` de `members` solo para `SUPERADMIN`. | Evita `permission-denied` al crear/importar socios desde cuentas `ADMIN`, ruta que la UI ya habilita. | Alta | Validar con usuarios reales/emulator y desplegar reglas antes de pruebas operativas. |
| E-020 | Firestore reglas / Auditoría | Corregido localmente: contrato mínimo de `audit_logs` | `audit_logs.create` ya no acepta payload arbitrario: exige campos esperados, `userId == request.auth.uid`, acción/entidad permitidas, `timestamp` numérico y opcionales tipados. | Reduce falsificación de eventos de auditoría por clientes autenticados sin romper votos/asistencia/importaciones. | Alta | Validar con emulator/reglas y flujos reales; desplegar reglas antes de prueba operativa. |
| E-021 | Asistencia | Corregido localmente: reducción de duplicados por evento/persona | `AsistenciaService.createAsistencia` usa ID determinístico por `eventoId + personaId` en legacy y replica el mismo ID en `eventos/{id}/asistencias`; `AttendanceService.registerAttendance` usa ID determinístico por `personaId` dentro de cada `attendance_events/{id}`. Ambos servicios verifican duplicado interno antes de escribir. | Reduce duplicados por doble click, doble escaneo o llamadas directas al servicio. | Alta | Validar con doble escaneo real/emulator y revisar datos históricos con IDs aleatorios ya existentes. |
| E-022 | Asistencia legacy / Auditoría | Corregido localmente: trazabilidad y borrado consistente | `AsistenciaService` registra auditoría al crear/actualizar/eliminar eventos legacy y al crear/eliminar asistencias legacy; `deleteAsistencia` elimina también la réplica `eventos/{id}/asistencias/{asistenciaId}` cuando el registro global contiene `eventoId`. | Reduce registros huérfanos y mejora trazabilidad operativa de asistencia clásica. | Media/Alta | Validar borrado desde UI con datos reales y revisar registros legacy sin `eventoId`. |
| E-023 | Socios / Rendimiento | Corregido localmente: paginación básica del padrón | `MembersService.getMembersPage()` expone páginas con `limit` y cursor; `/members` carga 50 socios iniciales, permite **Cargar más socios**, refresca tras alta/edición/cambio de estado y conserva búsqueda/exportación completa como fallback funcional. | Reduce lecturas iniciales y mejora uso del padrón con muchos socios sin cambiar contrato de import/export. | Media | Validar con Firestore real, volumen representativo e índices; implementar búsqueda backend/indexada si el padrón crece mucho. |
| E-024 | Asistencia / Modalidades no convocadas | Corregido localmente: selector múltiple y exclusión de faltantes | `CrearEventoAsistenciaScreen` reemplaza `Modalidad` simple por chips de **Modalidades no convocadas**; `EventoAsistencia` persiste `modalidadesNoConvocadas: List<String>` y lee `modalidad` legacy como respaldo; `AttendanceService.generateAttendanceReport` excluye esas modalidades del cálculo de faltantes y las muestra como **No convocado / Justificado por modalidad**. | Evita contar como ausentes injustificados a socios que no debían asistir por modalidad/turno. | Alta | Validar con padrón real que todos los socios tengan `members.modalidad`; probar evento con D/N1/N2 excluidas y datos reales de asistencia. |
| E-025 | Perfil / Asistencia | Corregido localmente: resumen reactivo de asistencias y faltas por socio | `AttendanceService.watchMemberAttendanceSummary(memberId)` combina `attendance_events`, subcolección `asistencias`, `eventos`, `asistencias` legacy y `personas`; `UserProfileScreen` muestra eventos convocados, asistencias, faltas injustificadas, no convocados por modalidad/lista explícita y últimos eventos. | El socio puede auditar su estado de asistencia desde el perfil y el dato se actualiza al registrar eventos/asistencias nuevas. | Alta | Validar con Firebase real/emulator, eventos con `miembrosConvocados` explícitos/vacíos, `modalidadesNoConvocadas`, ausencias justificadas y datos legacy. |
| E-026 | Perfil / Users / Firestore reglas | Corregido localmente: vínculo canónico `users.memberId` | `AppUser` serializa `memberId`; `AuthService.signUpWithEmployeeNumber` guarda el id de `members`; `_getUserFromFirestore` hace backfill seguro si falta; `UserProfileScreen` resuelve primero por `memberId`; `AttendanceService` autoriza resumen por `users.memberId`; reglas aceptan/validan `memberId` contra `members.workerCode/memberNumber/documentId`. | Reduce heurísticas usuario↔socio y prepara endurecimiento real de lecturas por propietario. | Alta | Desplegar reglas, validar con usuarios reales y crear migración para documentos `users` históricos sin `memberId`. |
| E-027 | Navegación / Roles | Corregido localmente: decisión de acceso testeable por rol | Se extrae la matriz de roles a `lib/core/security/route_access.dart` (`adminRouteRoles`, `attendanceRouteRoles`, `resolveProtectedRouteAccess`) y `_RouteGuard` consume esa decisión. `test/route_access_test.dart` valida carga, login requerido, rutas autenticadas, rutas admin y rutas de asistencia para todos los roles. | Reduce riesgo de regresión al abrir rutas directas por nombre/URL y documenta el contrato efectivo rol-ruta. | Media | Mantener el test al agregar nuevas rutas y completar validación manual con cuentas reales. |
| E-028 | Resultados / Votación | Corregido localmente: visibilidad de resultados centralizada y testeada | Se agrega `canViewElectionResults` en `lib/core/security/election_visibility.dart`; `ElectionResultsScreen` y la pantalla post-voto usan la misma regla. Admins pueden revisar siempre; roles no administrativos sólo ven resultados si la elección está activa, visible, con publicación automática y finalizada. | Evita publicación anticipada u oculta por ruta directa y reduce divergencias entre pantalla de resultados y pantalla de voto registrado. | Media/Alta | Mantener `test/election_visibility_test.dart`; validar navegación real y reglas con usuarios Firebase. |
| E-029 | Exportaciones / UX | Corregido localmente: confirmación previa en exportaciones sensibles | Exportar socios CSV, asistencia CSV/Excel/PDF y resultados CSV/PDF muestran diálogo de confirmación antes de copiar o compartir. Los textos advierten sobre datos personales/operativos y recomiendan compartir sólo con personal autorizado. | Reduce filtraciones accidentales y acciones involuntarias sobre datos sensibles. | Baja/Media | Validar UX con usuarios reales y extender la misma pauta a nuevas exportaciones futuras. |
| E-030 | Auditoría / Rendimiento | Corregido localmente: carga incremental en `audit_logs` | `AuditLogsScreen` consume `AuditService.getAuditLogs(limit: ...)` con límite inicial de 50 y permite aumentar de 50 en 50; al cambiar filtros se reinicia el límite. | Reduce lecturas/render inicial en auditoría y conserva acceso gradual a históricos. | Media | Validar con volumen real e índices compuestos para filtros combinados. |
| E-031 | Votación / Elecciones | Corregido localmente: regla única para permitir votar | Se agrega `canVoteInElection`/`ElectionVotingStatus`; listado, tarjetas, pantalla directa de voto y `VoteService.castVote` bloquean elecciones inactivas, ocultas, no iniciadas o finalizadas antes de permitir el batch. | Reduce divergencias UI-servicio-reglas y evita intentos de voto por ruta directa sobre elecciones no votables. | Alta | Mantener prueba pura y validar con Firebase real/emulator por rol. |
| E-032 | Votación / Asistencia | Corregido localmente: elegibilidad por asistencia escucha legacy y reporte | `VoteService.watchUserEligibilityForElection` recalcula al cambiar `asistencias` legacy o `attendance_events/{eventoAsistenciaId}/asistencias`; `VotingScreen` lo usa cuando `requireAttendance` está activo y bloquea elecciones sin evento vinculado. | Evita que una elección vinculada a modelo reporte quede bloqueada en UI aunque el socio ya tenga asistencia válida; mantiene validación final en `castVote`. | Alta | Validar con eventos reales legacy/reporte y suite emulator cuando esté disponible. |
| E-033 | Arranque / Firebase | Corregido localmente: error de inicialización visible y reintentable | `main.dart` incorpora `AppBootstrap`: inicializa Firebase antes de crear `AuthProvider`, muestra carga, muestra error con botón **Reintentar** y no entra al flujo de login si Firebase no está disponible. | Evita estados rotos o mensajes confusos cuando hay timeout/red/configuración Firebase incorrecta. | Media/Alta | Agregar prueba widget con inicializador fake y validar en plataforma real con red desconectada. |
| E-034 | Votación / Elecciones | Corregido localmente: `status` de elección coherente con `isActive` | `ElectionStatus` define `DRAFT`, `ACTIVE` y `CLOSED`; `Election.toMap()` deriva el estado persistido según `isActive` y `endDate`, evitando guardar elecciones activas como `DRAFT`. Se agrega `test/election_model_test.dart`. | Reduce ambigüedad en reportes, integraciones y mantenimiento de datos históricos sin cambiar la regla efectiva de votación. | Media | Definir con producto si se requiere ciclo de vida más fino (`SCHEDULED`, `PAUSED`, `ARCHIVED`) y desplegar migración si se decide normalizar históricos. |
| E-035 | Votación / Elecciones | Corregido localmente: validación centralizada de calendario electoral | `validateElectionDateRange`/`validateElectionTimestampRange` rechazan fechas faltantes, fin igual/anterior al inicio y duración menor a 1 minuto; crear/editar elección y `ElectionService.createElection/updateElection` aplican el mismo contrato. | Evita elecciones inválidas por UI o llamadas de servicio, y asegura que el requisito de asistencia no se guarde sin evento vinculado. | Media/Alta | Validar manualmente formularios en móvil/web y mantener pruebas si se agregan estados o duración configurable. |
| E-036 | Candidatos | Corregido localmente: edición completa de URL de imagen y orden | `AddCandidateScreen` y el diálogo de edición comparten validadores de `Candidate`: URL opcional sólo http(s), orden entero no negativo y parseo seguro. El diálogo permite corregir imagen/orden sin borrar el candidato. | Permite mantener boletas ordenadas y corregir datos visuales sin operaciones destructivas sobre candidatos existentes. | Baja/Media | Mantener validadores y validar manualmente en boletas con candidatos existentes. |
| E-037 | Arranque / Firebase | Corregido localmente: prueba widget de error y reintento | `AppBootstrap` permite inyectar un inicializador y `readyApp` para pruebas; `test/widget_test.dart` simula fallo inicial, verifica pantalla de error/reintento y confirma render exitoso tras reintentar. | Reduce riesgo de regresión en el arranque cuando Firebase falla por red, timeout o configuración. | Media | Validar manualmente en Windows/Web con red desconectada y conservar la prueba al modificar el bootstrap. |
| E-038 | Candidatos | Corregido localmente: bloqueo de nombres duplicados por elección | `Candidate` agrega `candidateNameKey`/`hasCandidateNameConflict`; `ElectionService.addCandidate/updateCandidate` lee candidatos de la elección y rechaza nombres repetidos normalizando mayúsculas y espacios. Nuevos mapas guardan `nameKey` para trazabilidad futura. | Evita boletas ambiguas y errores operativos al administrar candidatos con nombres repetidos dentro de una misma elección. | Media | Validar manualmente con Firebase real y evaluar garantía transaccional si habrá múltiples administradores editando en paralelo. |
| E-039 | Candidatos | Corregido localmente: prueba de rechazo al borrar candidatos con votos | `Candidate` agrega `validateCandidateDeletion` y `candidateWithVotesDeletionError`; `ElectionService.deleteCandidate` reutiliza la regla para `voteCount` y para documentos `votes`; `test/candidate_model_test.dart` cubre ambos escenarios. | Reduce riesgo de regresión en una regla crítica para no dejar boletas/resultados con votos huérfanos. | Media | Agregar prueba emulator de la consulta real a subcolección `votes` y validar manualmente desde UI con candidato votado. |
| E-040 | Asistencia / UX | Corregido localmente: hub de asistencia sin accesos redundantes de QR/padrón | `AsistenciaHomeScreen` elimina de acciones rápidas **Personas**, **Códigos QR** e **Importar Excel**. El hub conserva sólo acciones operativas de asistencia: escanear, asistencias, crear evento y exportar. El copy de importación legacy deja de remitir a “Códigos QR” y apunta al QR canónico en **Mi Perfil**. | Reduce confusión operativa y evita duplicar la generación/consulta de QR fuera del perfil del socio. | Media | Validar visualmente en Windows/móvil y definir si las rutas legacy ocultas deben retirarse definitivamente o conservarse sólo para soporte/migración. |
| E-041 | Asistencia / UX / Datos | Corregido localmente: creación de eventos unificada | `AsistenciaHomeScreen` reemplaza **Evento reporte** + **Evento clásico** por un único **Crear evento** que abre `/asistencia/crear_attendance_event`; el FAB también crea siempre en `attendance_events`. La ruta antigua `/asistencia/crear_evento` queda como alias del mismo formulario actual. El listado principal inicia en **Eventos** y deja `eventos` legacy como pestaña **Históricos**. Crear/detalle/scanner/manual/exportación muestran textos funcionales sin exponer “reporte” como tipo de evento. | Evita que operadores elijan entre dos modelos técnicos y establece `attendance_events` como flujo canónico para eventos nuevos. | Alta | Validar con datos reales; decidir si el formulario legacy `CrearEventoAsistenciaScreen` se elimina del código o se conserva sólo para soporte/migración. |
| E-042 | Perfil / Streams | Corregido localmente: compatibilidad TabBarView + resumen | `AttendanceService.watchMemberAttendanceSummary` sustituye `async*` + `yield*` por `Stream.fromFuture(_ensureCanReadMemberSummary).asyncExpand(...).asBroadcastStream()`. `UserProfileScreen` sustituye el `StreamBuilder` por una única `StreamSubscription<MemberAttendanceSummary>`, guarda el último resumen en estado y cancela la escucha anterior al recargar socio o destruir la pantalla. | Elimina crash **`Bad state: Stream has already been listened to`** en **Mi Perfil** al cambiar pestañas, relayout o reconstrucciones del árbol (p. ej. Windows). | Alta | Cambiar entre pestañas Información / QR; revisar avisos de hilo en plugins Firebase Windows aparte. |
| E-043 | Asistencia / `attendance_events` | Corregido localmente: modalidades no convocadas en flujo canónico | **`CrearAttendanceEventScreen`** persiste `modalidadesNoConvocadas` al crear. **`AttendanceEventDetailScreen`** muestra exclusiones, botón **Editar**, icono en AppBar y diálogo que actualiza vía **`AttendanceService.updateEvent`**. | Paridad con eventos legacy para exclusiones por modalidad en reportes y resumen de perfil. | Alta | Crear evento con exclusiones; editarlas en detalle; validar reporte y perfil con socios por modalidad. |
| E-044 | Candidatos / Firebase Storage | Implementado localmente: imagen opcional por URL **o** subida | Dependencias **`firebase_storage`** + **`image_picker`**; **`candidate_image_upload_section.dart`** en **`add_candidate_screen.dart`** y diálogo de **`edit_election_screen.dart`**; reglas **`storage.rules`** y **`firebase.json`**. La implementación de ruta objeto y orden **getDownloadURL** quedó refinada en **E-045**; la política de escritura sólo admin queda cerrada localmente en **E-046**. | Los administradores pueden omitir URL externa y subir archivo; el documento del candidato guarda la URL en **`imageUrl`** (https). | Media | Probar subida Android/iOS/Web, rechazo sin auth, rechazo como `VOTER`/`USER` y archivo &gt; 5 MB. |
| E-045 | Candidatos / Storage + lifecycle modal | Corregido **2026-05-02**: ruta canónica **`elections/{electionId}/candidates/{candidateId}/{file}`**, **`FirebaseStorage.instance`**, **`uploadCandidateImage`** ( **`putFile`/`putData`** luego **`snapshot.ref.getDownloadURL()`** ), **`tryDeleteOldCandidateImage`** no bloqueante; modal **Editar candidato** (**`await showDialog`** + **`finally`** dispose; sin **`setModal`** previo al **pop** en éxito) evita crash **`_dependents.isEmpty`**; Storage consola + **`firebase deploy --only storage`** OK. | Subidas coherentes con **`storage.rules`**; cierre de modal estable tras guardar con foto. | Media | Regresión manual agregar/editar con y sin imagen; emulator Storage opcional. |
| E-046 | Candidatos / Storage / Permisos | Corregido localmente: escritura de fotos sólo para admins | **`storage.rules`** ahora usa **`firestore.exists/get`** sobre **`users/{uid}.role`**; lectura queda para usuarios autenticados, pero **`create`/`update`/`delete`** en **`candidates/{candidateId}/`** y **`candidate_photos/`** exige `SUPERADMIN` o `ADMIN`. `create`/`update` mantienen validación `image/*` y tamaño &lt; 5 MB. | Evita que `VOTER`, `USER` u otros usuarios autenticados llenen o manipulen el bucket de candidatos. | Alta | Ejecutar `firebase deploy --only storage` real y validar con cuenta admin y cuenta votante/usuario. |
| E-047 | Socios / Importación | Corregido localmente: plantillas y prevalidación desde la app | **`ImportMembersScreen`** agrega acciones **Plantilla Excel** y **Plantilla CSV** y tarjeta de **Prevalidación del archivo**. **`ImportService`** genera XLSX real con hoja `Socios` y hoja `Modalidades`, CSV con encabezados canónicos, y métodos `previewCsv` / `previewExcel` para validar filas, modalidad y duplicados internos antes de escribir. | Reduce errores operativos al preparar padrones y evita depender sólo de scripts locales para obtener la estructura correcta; el operador ve problemas antes de importar. | Media | Probar compartir/abrir plantilla y previsualización en Windows, Android y Web; considerar consulta previa a Firestore para duplicados remotos si el volumen lo permite. |
| E-048 | Socios / Exportación | Corregido localmente: exportar todo como archivo CSV real | **`MembersListScreen`** ya no comparte el CSV como texto. Usa **`Share.shareXFiles`** con `XFile.fromData`, BOM UTF-8 y nombre `socios_{timestamp}.csv`. **`MembersService.fetchMembersForExport()`** consulta toda la colección `members` para exportar, independiente de la página visible; helpers de orden/filtro quedan testeados. | Permite exportar padrones grandes desde móvil sin truncamiento del share text y evita confundir página visible con padrón completo. | Alta | Probar en Android/Windows con padrón real grande y abrir el archivo en Excel/LibreOffice. |

### Clasificación por tipo

- Errores funcionales: corregidos localmente E-001, E-003, E-004, E-005, E-008, E-009, E-010, E-011, E-016, E-021, E-022, E-024, E-025, E-026, E-027, E-028, E-031, E-032, E-033, E-034, E-035, E-036, E-037, E-038, E-039, E-041, E-042, E-043, **E-044**, **E-045**, **E-046** y **E-048** (foto candidato + modal edición + permisos Storage + exportación completa de socios); pendientes funcionales relevantes: reporte/resumen con datos reales, reset con Firebase real, doble escaneo físico, prueba manual de cuenta sin perfil/historial y pruebas Storage con emulator/cuentas reales más allá del smoke administrativo.
- Errores visuales/UX: mensajes extensos en perfil/importación y falta de filtros; E-012, E-029, E-040 y E-041 quedan corregidos localmente con pendiente de validación manual.
- Errores de navegación: E-014 y E-027 corregidos localmente, pendiente validación manual con cuentas reales.
- Errores de validación: corregidos localmente E-002, E-006 (**incluye columna modalidad en import socios**), E-007, E-013, E-017, E-018 (**modalidad en padrón**), E-024 (**modalidades no convocadas opcionales en legacy**), E-025 (**faltas injustificadas vs ausencias justificadas/no convocados**), E-028 (**publicación de resultados**), E-035 (**fechas/evento requerido en elecciones**), E-036 (**URL/orden de candidatos**), E-038 (**nombres duplicados de candidatos por elección**), E-039 (**borrado de candidatos con votos**), E-043 (**mismas exclusiones en `attendance_events`**), **E-044**, **E-045**, **E-046** (**imagen candidato**: URL http(s), subida bajo **`candidates/{id}/`**, reglas Storage con escritura admin), **E-047** (**plantilla import socios** con encabezados canónicos) y **E-048** (**CSV export socios como archivo completo**); faltan pruebas sistemáticas con emulator Storage si se desea garantía fuerte.
- Errores de permisos: E-001, E-002, E-014, E-019, E-020, E-026, E-027 y **E-046** corregidos localmente, pendientes pruebas con emulator/usuarios reales.
- Errores de rendimiento: E-015 parcialmente mitigado por E-023 en el listado de socios y E-030 en auditoría; persisten lecturas completas en búsqueda/exportación y algunas pantallas de asistencia.
- Errores de contenido: instrucciones contradictorias de importación/QR corregidas en perfil; mantener revisión de copy operativo con usuarios reales.

## 8. Huecos funcionales pendientes por corregir

| ID | Hueco detectado | Módulo relacionado | Riesgo | Recomendación | Prioridad |
|---|---|---|---|---|---|
| H-013 | **Cerrado flujo escritura modelo nuevo en app (2026-05-01):** crear (`attendance_events`), detalle con FAB manual/QR, rutas **`AsistenciaEventRouteArgs`**, home segmentado (**Eventos** vs **Históricos**). **Ampliación 2026-05-02:** exclusiones por modalidad también en alta/edición del modelo nuevo (**E-043**). Persiste decisión organizativa si operación continúa usando solo legacy. | Asistencia / modelo nuevo | Divergencias si el mismo día se mezclan registros inconsistentes fuera del flujo indicado | Comunicación operativa: eventos nuevos desde tab **Eventos**, detalle **`attendance_event_detail`** | Baja/Media |
| H-014 | **Mitigado localmente (2026-05-01):** vínculo canónico `users.memberId` para consultas de perfil/resumen | Perfil / Seguridad | Queda riesgo residual hasta desplegar reglas y completar datos históricos; las reglas aún mantienen lecturas amplias en colecciones de asistencia por compatibilidad | Desplegar reglas, validar auto-registro/backfill con usuarios reales y preparar migración para `users` antiguos sin `memberId` | Alta |
| H-001 | **Mitigado localmente (2026-05-01):** test puro de decisión de acceso por rol y matriz documentada; falta validación manual con cuentas reales | Navegación | Regresión futura reducida en acceso por URL/ruta; persiste riesgo si reglas desplegadas o claims reales difieren | Ejecutar pruebas manuales por `SUPERADMIN`, `ADMIN`, `OPERADOR_ASISTENCIA`, `VOTER` y `USER` en Firebase real | Media |
| H-002 | Cobertura baja de login/voto/asistencia, mitigada parcialmente con pruebas de ruta/roles y visibilidad de resultados | QA | Regresiones no detectadas en flujos críticos de negocio con Firestore real | Crear tests de widgets y servicios con mocks/emulator para voto, resumen de asistencia, login y reglas | Alta |
| H-003 | No hay Firebase Emulator tests para reglas | Seguridad | Reglas rotas en producción | Agregar suite de reglas y Java 21+ local | Alta |
| H-004 | Dos modelos de asistencia coexistiendo | Asistencia | Divergencias si operación no sigue pestañas en UI export/home | **`generateAttendanceReport`** y **`/asistencia/exportar`** contemplan legacy + **`attendance_events`** (pestaña Reporte/Ambos) | Media |
| H-005 | Mitigado parcialmente 2026-05-01: paginación básica en listado de socios (`/members`) y carga incremental en auditoría (`/audit/logs`) | Socios/asistencia/auditoría | Persisten costes en búsqueda/exportación y algunos listados de asistencia | Extender paginación a asistencia, búsqueda indexada y exportaciones por rango/evento | Media |
| H-006 | **Mitigado localmente (2026-05-01):** exportaciones sensibles de socios, asistencia y resultados piden confirmación previa; cambios de estado/eliminaciones ya tenían confirmación | Exportaciones/estado | Riesgo residual si se agregan nuevas exportaciones sin seguir el patrón | Mantener confirmación y advertencia de datos sensibles en toda exportación nueva | Baja |
| H-007 | Mitigado 2026-05-01: buscador en modal de personas | Asistencia | Listas muy grandes cargan todas en cliente | Paginación o virtual scrolling con backend | Media |
| H-008 | Falta accesibilidad formal | UI | Dificultad para usuarios con lectores | Semántica, labels, contrastes, tamaños | Media |
| H-009 | Falta responsive verificado | Multiplataforma | Layouts pueden romperse | Pruebas visuales Web/Windows/mobile | Media |
| H-010 | **Mitigado documentalmente (2026-05-01):** `audit_logs` definido como fuente canónica y `events` como legacy; retención/migración requiere decisión operativa | Auditoría | Riesgo residual si clientes antiguos siguen escribiendo sólo en `events` o si se purgan logs sin política aprobada | Mantener nuevas pantallas sobre `audit_logs`, preparar script idempotente si se decide migrar `events` y aprobar política de retención | Media |
| H-011 | Cuenta sin perfil ya bloqueada con mensaje; falta flujo de reparación | Auth | El usuario entiende el problema, pero depende de intervención administrativa | Pantalla/proceso admin para crear o reparar `users/{uid}` | Media |
| H-012 | **Mitigado localmente (2026-05-01):** regla `canViewElectionResults` testeada para admin/votante, publicación automática, fecha, activo y visible | Votación | Regresión futura reducida; falta navegación widget/Firebase real | Cubrir ruta directa y pantalla post-voto con tests widget o integración al habilitar emulator/datos reales | Media |
| H-015 | **Mitigado operativamente 2026-05-02:** bucket Storage activado en **`sistema-integrado-sindicato`** y deploy Storage previo exitoso (**E-045**). **E-046** endurece reglas localmente para escritura sólo `SUPERADMIN`/`ADMIN`; compila en dry-run y requiere deploy real para quedar vigente en remoto. | Storage / candidatos | Histórico: sin bucket CLI no desplegaba reglas ni existía destino real de subidas. Riesgo residual: usar bucket remoto con reglas anteriores si no se despliega E-046. | Mantener proyecto de app alineado a consola actual; ejecutar **`firebase deploy --only storage`** tras E-046 y validar admin vs votante. | Alta hasta deploy; luego media/baja |

## 9. Recomendaciones de mejora

| Área | Problema detectado | Solución sugerida | Beneficio esperado | Prioridad |
|---|---|---|---|---|
| Seguridad | Reglas de voto y usuarios corregidas localmente, sin pruebas emulator | Mantener reglas con `diff`, validar con emulator y casos negativos | Voto funcional y menor riesgo de manipulación | Alta |
| Seguridad / Storage | Reglas locales de **`storage.rules`** ya restringen escritura/borrado de fotos de candidatos a `SUPERADMIN`/`ADMIN`, pero E-046 está pendiente de deploy real y prueba por rol | Ejecutar **`firebase deploy --only storage`**, probar subida/edición/borrado como admin y rechazo como `VOTER`/`USER`; luego considerar emulator Storage para regresión | Evita que cualquier usuario autenticado llene o manipule el bucket | Alta hasta deploy/validación |
| Seguridad | `users.memberId` ya queda persistido/backfilled localmente, pero faltan despliegue y migración histórica | Desplegar reglas, validar con usuarios reales y luego endurecer lecturas Firestore por propietario/rol donde no rompa compatibilidad legacy | Menor exposición de datos de asistencia entre socios | Alta |
| Arquitectura | Legacy + `attendance_events` con rutas y servicios diferenciados | Comunicar proceso operativo por tab; opcional migración de datos | Menos confusión campo vs reporte consolidado | Alta (gestión) |
| QA | Cobertura automatizada aún insuficiente en flujos con Firestore real | Ampliar pruebas reales de autenticación, voto, asistencia, resumen de perfil y formularios; conservar `route_access_test.dart` como contrato de roles | Suite útil y confiable | Alta |
| UX | Rutas administrativas ya guardadas y cubiertas con decisión de acceso pura; falta validación manual por cuenta real | Ejecutar checklist manual rol-ruta contra Firebase real antes de entrega | Experiencia clara y segura | Media |
| Datos | WorkerCode cubierto en formulario/import; sin suite amplia dedicada | Mantener validaciones y ampliar pruebas de servicio/mock | Evita duplicidad crítica | Media |
| Rendimiento | Lecturas completas parcialmente mitigadas en `/members`; persisten búsqueda/exportación y otros listados | Extender paginación, filtros Firestore, cache y búsqueda indexada | Mejor desempeño con padrones grandes | Media |
| Importación | `ImportService`/personas legacy: CSV y Excel cubiertos para socios/personas; plantilla socios y prevalidación local ya se generan desde la app; falta preview contra duplicados Firestore antes de escritura masiva | Opcional: ampliar vista previa para consultar duplicados remotos antes de confirmar importación | Menos errores operativos | Media |
| Auditoría | `audit_logs` ya alimenta ambas pantallas; `events` sigue legacy | Documentar responsabilidades, migración/retención y permisos | Trazabilidad completa | Media |
| Accesibilidad | No verificada | Agregar labels, contraste, navegación teclado | Cumplimiento y usabilidad | Media |
| Documentación | Matriz rol-ruta agregada al expediente; falta mantenerla al crear rutas nuevas | Actualizar §3 y `route_access_test.dart` en cada cambio de navegación/permisos | Mejor alineación producto/desarrollo | Media |

## 10. Checklist técnico-funcional

| Ítem | Estado | Observación |
|---|---|---|
| Login funcional | Parcial | Flujo implementado con validación de email y control de perfil faltante; falta prueba específica de reset y cuenta real sin perfil. |
| Registro funcional | Parcial | Implementado; reglas locales restringen rol, falta validar con Firebase real/emulator. |
| Validaciones de formularios | Parcial | Hay obligatorios, email en login/registro y unicidad de socios reforzada; faltan formatos estrictos (tel./documento) en algunos puntos. |
| Manejo de errores | Parcial | Hay mensajes, pero algunos son genéricos o solo `debugPrint`. |
| Responsive design | Pendiente | No se verificó visualmente; algunos layouts tienen adaptaciones. |
| Roles y permisos | Parcial | UI y rutas ya incluyen guard; falta validación manual/test por rol real. |
| Seguridad básica | Parcial | Firebase Auth y reglas locales compilan; falta suite emulator y despliegue controlado. |
| Estados de carga | Completo/parcial | Existen en la mayoría de pantallas. |
| Estados vacíos | Completo/parcial | Implementados en listados principales. |
| Mensajes al usuario | Parcial | Presentes, pero algunos son excesivos o inconsistentes. |
| Navegación consistente | Parcial | Rutas nombradas claras; guard y adaptación de operador implementados; falta prueba manual. |
| Resumen asistencia en perfil | Parcial | Implementado con stream nuevo + legacy y exclusión por modalidad; falta validación Firebase real/emulator y datos representativos. |
| Auditoría | Parcial | `audit_logs` activo; Historial de Eventos ya se alimenta desde `audit_logs`; `events` queda legacy. |
| Exportaciones | Parcial | CSV/PDF/XLSX real; exportación de socios como archivo CSV completo corregida en E-048; falta prueba manual de apertura y filtros por evento/fecha. |
| Pruebas automatizadas | Parcial | 45 pruebas pasan; cobertura local creció en roles, elecciones, candidatos, socios/exportación, importación, scanner y arranque, pero aún falta emulator/Firestore real para flujos críticos. |
| Análisis estático | Completo/parcial | `flutter analyze` / `--no-pub` sin issues en verificaciones recientes (**E-044** a **E-047** Mayo 2026). |

## 11. Casos de prueba sugeridos

| ID | Caso de prueba | Pasos | Resultado esperado | Prioridad |
|---|---|---|---|---|
| TC-001 | Login exitoso | Ingresar email/password válidos | Redirige a Home y muestra rol | Alta |
| TC-002 | Login inválido | Ingresar credenciales erróneas | Muestra error claro | Alta |
| TC-003 | Recuperar contraseña | Abrir diálogo, escribir email inválido y luego válido, enviar | Email inválido muestra error y bloquea envío; email válido muestra éxito/error Firebase | Media |
| TC-004 | Registro votante | Probar email inválido, número no registrado, socio inactivo y socio activo | Bloquea email inválido/número inválido/inactivo; socio activo crea usuario con rol VOTER | Alta |
| TC-005 | Registro rol manipulado | Intentar crear usuario con rol ADMIN desde cliente modificado | Firestore rechaza | Alta |
| TC-006 | Home por rol VOTER | Entrar como votante | Solo ve Sistema de Voto y Perfil | Alta |
| TC-007 | Ruta admin directa como VOTER | Abrir `/members` directo | UI bloquea con sin permisos | Alta |
| TC-008 | Crear elección | Admin crea elección válida | Se guarda y aparece en listado admin | Alta |
| TC-009 | Elección inactiva | Crear visible en fecha pero `isActive=false` | No aparece a votantes | Alta |
| TC-010 | Agregar candidato | Crear candidato con orden | Aparece ordenado | Media |
| TC-010B | Agregar/editar candidato con foto opcional (**E-044**/ **E-045**/ **E-046**) | **Agregar** / **Editar** (modal): sin imagen; sólo URL https; foto desde galería/cámara (nativo); revisar tras guardar que no aparezca crash rojo (**`_dependents.isEmpty`**). Tras deploy de E-046, repetir con cuenta `ADMIN` y con cuenta `VOTER`/`USER`. | **`imageUrl`** coherente; objeto esperado en **`elections/.../candidates/{id}/...`**; nueva subida ya no usa solo **`candidate_photos/`**; admin puede subir/borrar y votante/usuario recibe rechazo de permisos | Alta |
| TC-011 | Voto normal | Votante elegible selecciona candidato | Crea voto e incrementa contadores | Alta |
| TC-012 | Voto duplicado | Reingresar y votar de nuevo | Bloquea y muestra ya votó | Alta |
| TC-013 | Voto con asistencia requerida sin asistencia | Abrir elección vinculada | Bloquea voto | Alta |
| TC-014 | Voto con reglas emulator | Ejecutar batch como VOTER | Reglas permiten solo voto legítimo | Alta |
| TC-015 | Resultados visibilidad | Votante intenta ver resultados antes de tiempo, con elección oculta/inactiva o publicación automática desactivada | No ve resultados; sólo `ADMIN`/`SUPERADMIN` pueden revisar siempre | Media |
| TC-016 | Crear evento asistencia | Operador/admin crea evento legacy **`eventos`** o, en flujo canónico, **`attendance_events`** vía `/asistencia/crear_attendance_event`, y opcionalmente marca modalidades D/N1/N2 como no convocadas | Evento aparece en listado correspondiente y persiste `modalidadesNoConvocadas` | Alta |
| TC-016B | Reporte con modalidades no convocadas | Crear evento legacy con D/N1/N2 excluidas; tener socios activos en esas modalidades sin asistencia | Esos socios aparecen como No convocado / Justificado por modalidad y no suman en faltantes | Alta |
| TC-016C | Resumen de asistencia en perfil | Entrar como socio; crear/registrar eventos nuevo y legacy con presente, ausente justificado, ausente sin justificación, modalidad no convocada y evento con `miembrosConvocados` que no incluya al socio | La tarjeta del perfil se actualiza en tiempo real; presentes suman asistencias, no convocados por modalidad/lista explícita no suman faltas y sólo ausentes injustificados suman `Faltas injustificadas`; al cambiar pestañas Información/QR no debe aparecer pantalla roja por stream (**E-042**) | Alta |
| TC-016D | Modalidades no convocadas en `attendance_events` | Operador crea evento en `/asistencia/crear_attendance_event` marcando p. ej. Modalidad D y N1; guardar; en detalle ver chips; pulsar **Editar** o icono de filtro, quitar una modalidad, guardar | Firestore refleja `modalidadesNoConvocadas` actualizado; reporte y resumen de perfil tratan esos socios como **No convocado / Justificado por modalidad** donde aplique (**E-043**) | Alta |
| TC-017 | Scanner sin evento inicial | Abrir scanner desde dashboard, seleccionar evento, ingresar código | Botón registrar se habilita y guarda | Alta |
| TC-018 | Scanner QR duplicado | Escanear mismo QR dos veces | Segundo intento informa duplicado | Alta |
| TC-019 | Registro manual existente | Seleccionar socio, guardar asistencia | Crea registro con justificación | Alta |
| TC-020 | Registro manual nueva persona duplicada | Crear persona con identificador existente | Bloquea y muestra error | Alta |
| TC-021 | Reporte desde evento legacy | Abrir reporte FAB desde detalle `eventos` | Debe cargar estadísticas mediante fallback legacy (**E-005**); sin error «Evento no encontrado» si el doc existe en `eventos` | Alta |
| TC-031 | Registro escaneo modelo reporte | Tab Reporte → abrir evento → Escanear o pegar código de socio válido | Escribe doc en **`attendance_events/{id}/asistencias`** con **`personaId`** = id `members`; duplicados rechazados | Alta |
| TC-032 | Exportar modelo reporte | `/asistencia/exportar` → pestaña **Reporte** con datos en `attendance_events` | Lista muestra eventos con prefijo «[Reporte]»; Excel/PDF incluyen esas filas; **Legacy** no las mezcla | Media |
| TC-033 | Exportar combinado | Misma pantalla → **Ambos** | Archivo contiene filas legacy y filas reporte (identificables por prefijo en nombre de evento) | Media |
| TC-022 | Importar socios CSV válido | Cargar plantilla válida | Importa filas y muestra resumen | Alta |
| TC-023 | Importar socios sin documento | Usar archivo sin documento si UI dice opcional | Comportamiento alineado con especificación | Alta |
| TC-024 | WorkerCode duplicado | Importar dos filas mismo workerCode | Bloquea duplicado | Alta |
| TC-025 | Exportar asistencia PDF | Generar PDF con datos | Archivo se comparte sin error | Media |
| TC-026 | Exportar Excel | Generar Excel desde asistencias con caracteres especiales | Archivo abre correctamente como XLSX real y conserva columnas/datos | Media |
| TC-027 | Auditoría create/update | Crear socio/elección | `audit_logs` registra acción | Media |
| TC-028 | Filtros auditoría | Aplicar filtros combinados | Lista correcta o índice documentado | Media |
| TC-029 | Responsive mobile | Probar pantallas principales en ancho pequeño | Sin overflow ni botones cortados | Media |
| TC-030 | Accesibilidad básica | Navegar con lector/teclado | Controles identificables | Baja |

## 12. Conclusión general

La aplicación tiene una base funcional amplia y una arquitectura entendible por módulos. Están implementados los flujos principales de autenticación, votación, asistencia, socios, QR, exportaciones y auditoría. Después de las correcciones locales del 2026-05-01, el estado mejora a MVP avanzado con riesgos críticos mitigados, pero aún no listo para producción sin validación con Firebase real/emulator, usuarios por rol y datos representativos.

Para **fotos de candidatos** (**E-044**/ **E-045**/ **E-046**), el entorno **`sistema-integrado-sindicato`** quedó con Storage iniciado y un deploy previo de reglas (**2026-05-02**). La versión local actual de **`storage.rules`** ya restringe escritura y borrado a `SUPERADMIN`/`ADMIN`; compila en dry-run y debe desplegarse con **`firebase deploy --only storage`** antes de pruebas operativas. Revisar objetos **`candidates/{candidateId}/`** en consola ante incidencias.

El mayor riesgo residual en datos de asistencia es **organizativo**: conviven **`eventos`** y **`attendance_events`** pero la aplicación ya enruta y persiste cada flujo coherentemente (**`AsistenciaEventRouteArgs`** + servicios); el reporte (**`generateAttendanceReport`**) consume ambos. Quedan mejoras como exportación única desde modelo nuevo si se desea vista global. El riesgo de seguridad de reglas de voto/usuarios fue corregido localmente y las reglas compilan en dry-run; falta suite emulator con casos negativos.

La completitud funcional estimada es alta en cobertura de pantallas y media-alta en robustez local. El nivel de completitud global estimado sube a **86-90%**, condicionado por pruebas automatizadas adicionales, validación con Firebase real/emulator y pruebas manuales por rol/datos reales.

Para considerar la aplicación **100% completa** antes de entrega productiva todavía falta:

1. Ejecutar suite Firebase Emulator con casos positivos y negativos de reglas para `users`, `members`, `votes`, `attendance_events`, `asistencias`, `audit_logs` y acceso por rol.
2. Validar manualmente con cuentas reales `SUPERADMIN`, `ADMIN`, `OPERADOR_ASISTENCIA`, `VOTER` y `USER`, incluyendo rutas directas protegidas, botones ocultos y acciones bloqueadas por servicio/reglas.
3. Probar en dispositivo físico el escáner QR, permisos de cámara, doble escaneo, registro manual y actualización del resumen de asistencia del perfil.
4. Ejecutar pruebas end-to-end con datos representativos de socios, eventos legacy, eventos reporte, elecciones activas/inactivas, candidatos y votos reales de prueba.
5. Confirmar estrategia de datos históricos: backfill de `users.memberId`, `Candidate.nameKey` en candidatos existentes si se requiere trazabilidad, normalización opcional de estados de elecciones y política final entre `eventos`/`attendance_events`.
6. Ampliar cobertura automatizada de servicios críticos: emisión de voto con Firestore/emulator, no duplicidad de votos, reportes de asistencia, importaciones/exportaciones con archivos reales, auditoría y permisos.
7. Validar rendimiento con padrón grande: paginación/filtros en listados, búsqueda, auditoría, exportaciones y reportes.
8. Completar QA visual, responsive y accesibilidad básica en Android, Web, Windows y resoluciones móviles reales.
9. Definir si se requiere garantía transaccional fuerte para nombres de candidatos cuando varios administradores editan en paralelo; hoy existe bloqueo local de servicio, pero no índice/Cloud Function global.
10. **Storage** (**H-015** mitigado parcialmente **2026-05-02**): mantener consola **`sistema-integrado-sindicato`** coherente; ejecutar **`firebase deploy --only storage`** para liberar **E-046**; validar que sólo `SUPERADMIN`/`ADMIN` puedan subir/actualizar/borrar fotos y que `VOTER`/`USER` sean rechazados en **TC-010B**.

Prioridades antes de entrega o producción:

1. Validar reglas Firestore **y Firebase Storage** (tras aprovisionamiento) con Firebase Emulator o proyecto de staging y usuarios reales por rol.
2. Ampliar tests reales de login, rutas, voto, importación y asistencia.
3. Política de negocio: si un único almacén canónico se desea para histórico, planificar migración; en código el **dual write** está resuelto por contexto (**legacy vs reporte**). Ampliar **export/global** si deben aparecer registros sólo del modelo nuevo.
4. Probar rutas protegidas por rol y documentar matriz rol-permiso.
5. Validar scanner manual/cámara en dispositivo.
6. Agregar pruebas de unicidad de socios en alta, edición e importación.
7. Validar exportaciones, rendimiento y responsive.

## 13. Anexos

### A. Lista de pantallas revisadas

| Pantalla | Ruta |
|---|---|
| Arranque/Auth Gate | `MaterialApp.home` |
| Login | `/login` |
| Registro | `/signup` |
| Home | `/home` |
| Perfil | `/profile` |
| Elecciones | `/voto/elections` |
| Crear elección | `/voto/create_election` |
| Editar elección | `/voto/edit_election` |
| Agregar candidato | `/voto/add_candidate` |
| Votar | `/voto/voting` |
| Resultados | `/voto/results` |
| Historial eventos voto | `/voto/event_history` |
| Asistencia Home | `/asistencia` |
| Crear evento de asistencia | `/asistencia/crear_attendance_event` |
| Alias legacy de creación | `/asistencia/crear_evento` (redirige al formulario actual en `attendance_events`) |
| Detalle evento histórico | `/asistencia/evento_detail` |
| Detalle evento de asistencia (`attendance_events`) | `/asistencia/attendance_event_detail` (`arguments`: id doc) |
| Registro manual | `/asistencia/registro_manual` (`EventoAsistencia` \| `AsistenciaEventRouteArgs`) |
| Scanner | `/asistencia/scanner` (`EventoAsistencia` \| `AsistenciaEventRouteArgs`) |
| Scanner QR cámara | `MaterialPageRoute` interna |
| Personas asistencia legacy | `/asistencia/personas` (ruta no expuesta en hub; usar módulo Socios como padrón canónico) |
| Asistencias | `/asistencia/asistencias` |
| Exportar asistencia | `/asistencia/exportar` |
| Importar personas legacy | `/asistencia/importar_personas` (ruta no expuesta en hub; usar importación de Socios) |
| Códigos QR legacy | `/asistencia/qr_codes` (ruta no expuesta en hub; QR canónico en Mi Perfil) |
| Reporte asistencia | `/attendance/report` |
| Gestión socios | `/members` |
| Formulario socio | `MaterialPageRoute` interna |
| Importar socios | `/members/import` |
| Audit logs | `/audit/logs` |

### B. Colecciones Firestore identificadas

**Nota Firebase Storage (no Firestore):** fotos nuevas de candidatos bajo **`elections/{electionId}/candidates/{candidateId}/{nombreArchivo}`** (**E-045**). La regla **`candidate_photos/`** cubre objetos legacy. Gobierno en **`storage.rules`**; desde **E-046** las escrituras/borrados son sólo admin en reglas locales y requieren **`firebase deploy --only storage`** real para quedar vigentes en remoto.

| Colección | Uso |
|---|---|
| `users` | Perfil de usuario y rol |
| `members` | Padrón sindical moderno |
| `elections` | Elecciones |
| `elections/{id}/candidates` | Candidatos por elección |
| `elections/{id}/votes` | Votos inmutables |
| `eventos` | Eventos de asistencia legacy |
| `personas` | Personas legacy para asistencia |
| `asistencias` | Registros globales legacy |
| `eventos/{id}/asistencias` | Réplica legacy por evento |
| `attendance_events` | Modelo nuevo de eventos de asistencia |
| `attendance_events/{id}/asistencias` | Asistencias del modelo nuevo |
| `audit_logs` | Auditoría actual de acciones |
| `events` | Historial legacy de eventos de voto; la pantalla actual consume `audit_logs` mediante adaptador |
| `import_logs` | Resultado de importaciones |

### C. Modelos principales

| Modelo | Archivo | Campos clave |
|---|---|---|
| `AppUser` | `lib/core/models/user.dart` | id, email, displayName, role, employeeNumber, memberId |
| `Election` | `lib/core/models/election.dart` | title, dates, isActive, isVisibleToVoters, requireAttendance, totalVotes |
| `Candidate` | `lib/core/models/candidate.dart` | electionId, name, **imageUrl** (opcional), description, order, voteCount |
| `Member` | `lib/core/models/member.dart` | memberNumber, firstName, lastName, workerCode, documentId, modalidad, status |
| `EventoAsistencia` | `lib/core/models/asistencia/evento.dart` | nombre, fecha, tipoReunion, `modalidadesNoConvocadas`; `modalidad` queda como lectura legacy |
| `PersonaAsistencia` | `lib/core/models/asistencia/persona.dart` | nombres, apellidos, identificador, codigoQR |
| `AsistenciaRegistro` | `lib/core/models/asistencia/asistencia.dart` | eventoId, personaId, metodoRegistro, justificacion, asistio |
| `AsistenciaEventRouteArgs` | `lib/features/asistencia/route_args.dart` | `evento` (legacy), `attendanceEventId` (reporte), `isAttendanceReport` |
| `AttendanceEvent` (DTO Firestore `attendance_events`) | `lib/services/attendance_service.dart` | nombre, fecha, lugar, tipo, miembrosConvocados, modalidadesNoConvocadas, activo, creadoPor, estado |
| `MemberAttendanceSummary` | `lib/services/attendance_service.dart` | totalConvocados, totalAsistencias, totalFaltas, totalNoConvocado, detalles |
| `AsistenciaDetalle` | `lib/services/attendance_service.dart` | eventId, eventName, fecha, estado, justificacion, isLegacy |
| `AuditLog` | `lib/core/models/audit_log.dart` | action, entityType, entityId, userId, timestamp |
| `VotoEvent` | `lib/core/models/voto_event.dart` | type, entityType, result, timestamp |
| `ImportLog` | `lib/core/models/import_log.dart` | fileName, totalRows, successfulImports, errors, duplicates |

### D. Resultados de análisis estático

`flutter analyze` / `--no-pub` ejecutado sin issues en revisiones previas (**2026-05-01** global; **2026-04-30** en archivos **E-044**). Tras **E-047** (**2026-05-02**), **`flutter analyze --no-pub`** queda limpio sobre el proyecto completo.

Resultado actual:

- Comando: `flutter analyze` / `--no-pub` según ciclo local.
- Estado: sin issues conocidos sobre el código documentado (**E-044** a **E-047**).
- Observación: la revisión estática local queda limpia después de las correcciones aplicadas y la ampliación de candidatos con Storage.

### E. Resultados de pruebas

`flutter test --no-pub --reporter expanded` se ejecutó nuevamente el 2026-05-01 y pasó correctamente:

- `test/widget_test.dart`: valida que se muestre Login cuando no hay sesión activa y que `AppBootstrap` muestre error Firebase con **Reintentar** y se recupere al segundo intento.
- `test/app_user_test.dart`: valida serialización y lectura de `AppUser.memberId`.
- `test/candidate_model_test.dart`: valida URL de imagen opcional http(s), rechazo de URL inválida, orden entero no negativo, rechazo de borrado de candidatos con votos y detección de nombres duplicados de candidatos por elección.
- `test/election_model_test.dart`: valida que `Election.toMap()` persista `status` como `ACTIVE`, `DRAFT` o `CLOSED` según `isActive`/fecha de fin, que `fromMap()` tenga fallback seguro y que el rango de fechas electorales rechace ausencias, igualdad, inversión o duración menor a 1 minuto.
- `test/election_visibility_test.dart`: valida publicación de resultados para admin/votante, estado activo/visible, fecha de cierre y `showResultsAutomatically`.
- `test/import_service_test.dart`: valida contrato de columnas obligatorias, separación de `numero_socio` frente a `worker_code`, CSV con campos entre comillas/comas internas, obligatoriedad de `modalidad`, normalización/canonización de alias (`turno` → `modalidad`, `n1` → `N1`), plantillas de importación XLSX/CSV con encabezados canónicos y prevalidación de duplicados/headers antes de importar.
- `test/members_service_test.dart`: valida generación de CSV de socios con todos los registros recibidos, columna `modalidad`, orden/filtro reutilizable para exportación y desacople respecto de la página visible.
- `test/evento_asistencia_test.dart`: valida serialización canónica de `modalidadesNoConvocadas`, lectura de `modalidad` legacy como exclusión única y descarte de valores inválidos/duplicados.
- `test/route_access_test.dart`: valida decisión de acceso por rol para estados de carga, sesión requerida, rutas autenticadas, rutas administrativas y rutas de asistencia.
- `test/scanner_screen_test.dart`: valida que el scanner muestre nombre/modalidad al registrar por código y no bloquee registros cuando la modalidad está sin asignar.
- Estado: 45 pruebas pasan.
- Acción recomendada: ampliar cobertura de reglas Firestore, voto, resumen de asistencia, login e importación con datos representativos/emulator.

### F. Validación de reglas Firestore

- `firebase deploy --only firestore --dry-run` se ejecutó nuevamente el 2026-05-01: correcto (compilación local de reglas actuales, incluyendo E-019 y E-020).
- `firebase deploy --only firestore` (sin dry-run) al proyecto **`sistema-integrado-sindicato`** se ejecutó previamente el mismo día: **deploy complete** según ejecución en entorno de desarrollo. Tras E-019/E-020 se validó con dry-run, pero queda pendiente repetir deploy real antes de pruebas operativas con `ADMIN`.
- **Actualización 2026-05-02 / revisada 2026-05-04:** en entorno de desarrollo se ejecutaron despliegues parciales explícitos **`firebase deploy --only firestore:rules`** contra **`sistema-integrado-sindicato`**; la referencia previa a **`firestore:indexes`** queda marcada como pendiente de confirmar porque el estado local actual no incluye **`firestore.indexes.json`** ni entrada `indexes` en **`firebase.json`**. Tras **E-054**, el resumen de perfil evita la consulta que requería índice `COLLECTION_GROUP_ASC`.
- Limitación: no sustituye pruebas con Firebase Emulator; para emuladores suele hacer falta Java 21+ local.

**Firebase Storage (reglas):**

- Repo: **`storage.rules`** (v2): **`elections/{electionId}/candidates/{candidateId}/{fileName}`** (+ compat **`elections/{electionId}/candidate_photos/{fileName}`**). **`firebase.json` → `"storage":{"rules":"storage.rules"}`**; **`.firebaserc`** → **`sistema-integrado-sindicato`**.
- Operación: **`firebase deploy --only storage`**.
- **2026-04-30:** error *«Firebase Storage has not been set up…»* hasta **Comenzar** en consola.
- **2026-05-02:** tras aprovisionamiento, **`firebase deploy --only storage`** completado (reglas liberadas). La app cliente sube fotos nuevas por **`CandidatePhotoStorage`** bajo **`candidates/{candidateId}/`** (**E-045**).
- **2026-05-02 / E-046:** **`storage.rules`** se endurece localmente: lectura autenticada, escritura/borrado sólo `SUPERADMIN`/`ADMIN`, validación `image/*` &lt; 5 MB. **`firebase deploy --only storage --dry-run`** compila correctamente; pendiente deploy real para liberar esta versión.

### G. Bitácora de correcciones

_Se añaden entradas nuevas arriba; las anteriores se conservan como historial._

| Fecha | Corrección | Archivos | Validación | Estado |
|---|---|---|---|---|
| 2026-05-04 | **E-054**: corrección del error en **Mi Perfil / Resumen de asistencia** mostrado como `[cloud_firestore/failed-precondition]` por índice `COLLECTION_GROUP_ASC` en `asistencias.personaId`. `AttendanceService.watchMemberAttendanceSummary()` deja de usar `collectionGroup('asistencias')` y escucha cada subcolección `attendance_events/{eventId}/asistencias` filtrada por `personaId`; `UserProfileScreen` reemplaza el detalle técnico largo por un mensaje resumido para usuario. | `lib/services/attendance_service.dart`, `lib/features/profile/user_profile_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (52/52); búsqueda local confirma que ya no hay `collectionGroup('asistencias')` en `lib/` | Aplicado localmente |
| 2026-05-02 | **E-053**: ajuste de **Home / Dashboard principal** para completar el pie de navegación y eliminar desbordamientos. Se agrega barra inferior flotante tipo pill con Inicio, Voto, Asist., Socios y Perfil según rol; las tarjetas de módulos pasan de altura fija a altura mínima flexible para evitar `BOTTOM OVERFLOWED` en móvil. | `lib/features/home/home_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (45/45) | Aplicado localmente |
| 2026-05-02 | **E-052**: rediseño visual del **Home / Dashboard principal** según referencia entregada. `HomeScreen` reemplaza app bar/tarjetas lineales por header morado con onda, logo, acciones rápidas, tarjeta de bienvenida, grilla responsiva de módulos y aviso de seguridad; conserva rutas y visibilidad por rol. | `lib/features/home/home_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (45/45) | Aplicado localmente |
| 2026-05-02 | **E-051**: limpieza de redundancia en **Importar Socios**. Se retira el botón visible **Plantilla CSV** y queda sólo **Plantilla Excel** como salida/plantilla compartible; se mantiene la selección/importación de `.csv`, `.xlsx` y `.xls`, junto con prevalidación CSV/Excel. | `lib/features/members/import_members_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded test/import_service_test.dart` OK (8/8) | Aplicado localmente |
| 2026-05-02 | **E-050**: corrección de `permission-denied` al exportar reporte completo de socios. `AttendanceService.fetchMemberAttendanceSummariesForExport()` deja de usar `collectionGroup('asistencias').get()` para la exportación y ahora lee las subcolecciones `attendance_events/{eventId}/asistencias` por evento, compatible con las reglas específicas ya existentes. Se añade regla explícita de lectura para `match /{path=**}/asistencias/{asistenciaId}` para soportar resúmenes/consultas `collectionGroup` sin abrir escrituras. | `lib/services/attendance_service.dart`, `firestore.rules`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (45/45); `firebase deploy --only firestore:rules --dry-run` OK; pendiente prueba manual exportando con usuario admin real | Aplicado localmente |
| 2026-05-02 | **E-049**: exportación de socios ampliada a **reporte completo**. El botón de `/members` mantiene archivo CSV real, pero ahora consulta resúmenes masivos con `AttendanceService.fetchMemberAttendanceSummariesForExport()` y agrega al CSV columnas de eventos convocados, asistencias, faltas injustificadas, ausencias justificadas, no convocados, porcentaje y último estado/evento. El cálculo reutiliza la lógica del perfil y separa registros nuevos (`attendance_events/{id}/asistencias`) de legacy (`eventos`, `asistencias`, `personas`) para no mezclar orígenes. | `lib/features/members/members_list_screen.dart`, `lib/services/attendance_service.dart`, `lib/services/members_service.dart`, `test/members_service_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (45/45); `git diff --check` OK; pendiente prueba manual con padrón real | Aplicado localmente |
| 2026-05-02 | **E-048**: exportación completa de socios como archivo real. `MembersListScreen` cambia de **`Share.share(csv)`** a **`Share.shareXFiles`** con `XFile.fromData`, BOM UTF-8 y nombre `socios_{timestamp}.csv`; `MembersService.fetchMembersForExport()` consulta toda la colección `members`, independiente de la página visible; helpers de orden/filtro quedan cubiertos por prueba. | `lib/features/members/members_list_screen.dart`, `lib/services/members_service.dart`, `test/members_service_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (45/45); pendiente prueba manual con padrón real | Aplicado localmente |
| 2026-05-02 | **E-047**: Importación de socios con plantillas y prevalidación local desde la app. **`ImportMembersScreen`** agrega botón **Plantilla Excel** y tarjeta de **Prevalidación**; **`ImportService.buildMembersImportTemplateExcel()`** crea XLSX real con hojas `Socios` y `Modalidades`; **`buildMembersImportTemplateCsv()`** queda como helper de servicio/test, pero la UI visible se simplifica en **E-051**; **`previewCsv`** / **`previewExcel`** detectan filas inválidas y duplicados internos. | `lib/features/members/import_members_screen.dart`, `lib/services/import_service.dart`, `test/import_service_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` OK; `flutter test --no-pub --reporter expanded` OK (43/43); pendiente prueba manual por plataforma | Aplicado localmente |
| 2026-05-02 | **E-046**: reglas Storage endurecidas para fotos de candidatos. `read` exige sesión; `create`/`update`/`delete` en **`elections/{electionId}/candidates/{candidateId}/{file}`** y **`candidate_photos/{file}`** exige `SUPERADMIN`/`ADMIN` consultando **`users/{uid}.role`** con **`firestore.exists/get`**; uploads siguen limitados a imagen **&lt; 5 MB**. | `storage.rules`, `expediente_tecnico_aplicacion.md` | **`firebase deploy --only storage --dry-run`** OK; pendiente deploy real y prueba admin/votante | Aplicado localmente |
| 2026-05-02 | **E-045**: Ampliación foto candidatos — ruta **`elections/{electionId}/candidates/{candidateId}/{file}`**; **`CandidatePhotoStorage.uploadCandidateImage`** + **`FirebaseStorage.instance`** + **`candidate_storage_put_io`/`web`**; **`tryDeleteOldCandidateImage`**; modal **Editar candidato**: **`await showDialog`** + **`finally`** **dispose**, sin **`setModal(saving=false)`** antes del **pop** en éxito (evita **`_dependents.isEmpty`**); logs en alta/edición. **`storage.rules`**: ramas **`candidates`** + **`candidate_photos`**. Consola Storage activada → **`firebase deploy --only storage`** OK. | `lib/services/candidate_photo_storage_service.dart`, `lib/services/candidate_storage_put_io.dart`, `lib/services/candidate_storage_put_web.dart`, `lib/features/elections/add_candidate_screen.dart`, `lib/features/elections/edit_election_screen.dart`, `storage.rules`, `expediente_tecnico_aplicacion.md` | `dart analyze`/`flutter test` sobre cambios locales; **`firebase deploy --only storage`** | Aplicado |
| 2026-04-30 | **E-044**: Foto opcional para candidatos. Dependencias **`firebase_storage`** + **`image_picker`**; **`CandidatePhotoStorage`** (evoluciona en **E-045** respecto de ruta de objeto previa); **`CandidateImageUploadSection`** en **`add_candidate_screen`** y diálogo de **`edit_election_screen`**; padding scroll **`viewPadding`/`viewInsets`**. **`storage.rules`**, **`firebase.json`**, **`.firebaserc`**. **Android** **`CAMERA`**; **iOS** uso fototeca/cámara. Deploy Storage inicialmente bloqueado sin bucket en consola. | `pubspec.yaml`, `lib/services/candidate_photo_storage_service.dart`, `lib/features/elections/candidate_image_upload_section.dart`, `lib/features/elections/add_candidate_screen.dart`, `lib/features/elections/edit_election_screen.dart`, `storage.rules`, `firebase.json`, `.firebaserc`, permisos nativos | `flutter analyze`; `flutter test` | Superado deploy tras **E-045**/ consola (**2026-05-02**) |
| 2026-05-02 | **E-042**: `watchMemberAttendanceSummary` usa cadena broadcast (`asyncExpand` + `asBroadcastStream`) en lugar de `async*` + `yield*`; `UserProfileScreen` reemplaza el `StreamBuilder` por una única `StreamSubscription` cancelable, evitando segundo `listen` ilegal con **TabBarView** en Mi Perfil. **E-043**: alta de **`modalidadesNoConvocadas`** en **`CrearAttendanceEventScreen`**; detalle **`AttendanceEventDetailScreen`** con visualización permanente, botón **Editar** e icono AppBar; diálogo **`_EditModalidadesNoConvocadasDialog`** + **`AttendanceService.updateEvent`**. Nota **E-054**: en el estado local actual no existe `firestore.indexes.json` ni entrada `indexes` en `firebase.json`; el perfil ya no requiere índice `collectionGroup` para `asistencias.personaId`. | `lib/services/attendance_service.dart`, `lib/features/profile/user_profile_screen.dart`, `lib/features/asistencia/crear_attendance_event_screen.dart`, `lib/features/asistencia/attendance_event_detail_screen.dart`, `firebase.json`, `expediente_tecnico_aplicacion.md` | `flutter analyze`; `flutter test --no-pub --reporter expanded`; pendiente repetir `flutter run -d windows` con usuario real | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-041**: la UI de asistencia deja de ofrecer “Evento reporte” vs “Evento clásico”; se expone un único **Crear evento** que crea en `attendance_events`, el FAB usa el mismo flujo, `/asistencia/crear_evento` queda como alias del formulario actual y `eventos` queda como pestaña **Históricos**. También se limpian textos de crear/detalle/scanner/manual/exportación y el prefijo exportado pasa a `[Evento]`. | `lib/main.dart`, `lib/features/asistencia/asistencia_home_screen.dart`, `lib/features/asistencia/crear_attendance_event_screen.dart`, `lib/features/asistencia/attendance_event_detail_screen.dart`, `lib/features/asistencia/scanner_screen.dart`, `lib/features/asistencia/registro_manual_screen.dart`, `lib/features/asistencia/exportar_screen.dart`, `lib/services/attendance_service.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (39/39) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-040**: el hub de asistencia retira accesos rápidos redundantes a **Personas**, **Códigos QR** e **Importar Excel**; conserva acciones operativas y el copy legacy apunta al QR canónico en **Mi Perfil**. | `lib/features/asistencia/asistencia_home_screen.dart`, `lib/features/asistencia/importar_personas_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (39/39) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-039**: la regla que impide eliminar candidatos con votos se extrae a `validateCandidateDeletion`, se reutiliza en `ElectionService.deleteCandidate` y queda cubierta por prueba unitaria para `voteCount` y documentos de voto existentes. | `lib/core/models/candidate.dart`, `lib/services/election_service.dart`, `test/candidate_model_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (39/39) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-038**: candidatos bloquean nombres duplicados por elección con normalización de mayúsculas/espacios; `toMap()` agrega `nameKey` para nuevos/actualizados. | `lib/core/models/candidate.dart`, `lib/services/election_service.dart`, `test/candidate_model_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (38/38) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-037**: `AppBootstrap` admite inicializador/`readyApp` inyectables para pruebas y `widget_test` cubre error Firebase, botón **Reintentar** y recuperación exitosa. | `lib/main.dart`, `test/widget_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (36/36) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-036**: alta/edición de candidatos validan URL de imagen http(s), orden entero no negativo y el diálogo de edición permite corregir imagen/orden sin borrar candidato. | `lib/core/models/candidate.dart`, `lib/features/elections/add_candidate_screen.dart`, `lib/features/elections/edit_election_screen.dart`, `test/candidate_model_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (35/35) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-035**: validación común de calendario electoral y evento requerido por asistencia en crear/editar elección y `ElectionService`; se rechaza fin igual/anterior al inicio y duración menor a 1 minuto. | `lib/core/models/election.dart`, `lib/features/elections/create_election_screen.dart`, `lib/features/elections/edit_election_screen.dart`, `lib/services/election_service.dart`, `test/election_model_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (32/32) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-034**: `ElectionStatus` agrega estados `DRAFT`/`ACTIVE`/`CLOSED` y `Election.toMap()` deja de guardar elecciones activas como borrador, derivando el estado desde `isActive` y `endDate`. | `lib/core/models/election.dart`, `test/election_model_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (28/28) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-033**: `AppBootstrap` inicializa Firebase antes de `AuthProvider`, muestra carga, error con **Reintentar** y evita entrar al login si Firebase no está disponible. | `lib/main.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (24/24) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-032**: elegibilidad de voto por asistencia escucha tanto `asistencias` legacy como `attendance_events/{eventoAsistenciaId}/asistencias`; la pantalla bloquea elecciones que exigen asistencia pero no tienen evento vinculado. | `lib/services/election_service.dart`, `lib/features/voting/voting_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (24/24) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **E-031**: regla única de votación `canVoteInElection`/`ElectionVotingStatus`; listado, tarjetas, pantalla directa `/voto/voting` y `VoteService.castVote` bloquean elecciones inactivas, ocultas, no iniciadas o finalizadas antes de votar. | `lib/core/security/election_visibility.dart`, `lib/services/election_service.dart`, `lib/features/elections/election_card.dart`, `lib/features/voting/voting_screen.dart`, `test/election_visibility_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (24/24) | Aplicado localmente |
| 2026-05-01 | Se mitiga documentalmente **H-010**: política de auditoría define `audit_logs` como fuente canónica, `events` como legacy, uso permitido, estrategia de migración idempotente y retención pendiente de decisión operativa. | `expediente_tecnico_aplicacion.md` | Revisión documental contra `AuditService`/`EventService`; sin cambios de código | Documentación |
| 2026-05-01 | Se mitiga parcialmente **H-005** en auditoría: `/audit/logs` carga 50 registros iniciales y permite ampliar de 50 en 50; filtros reinician el límite para evitar arranques pesados. | `lib/features/audit/audit_logs_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (21/21) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **H-006**: confirmación previa para exportaciones sensibles de socios, asistencia y resultados antes de copiar/compartir CSV, Excel o PDF. | `lib/features/members/members_list_screen.dart`, `lib/features/asistencia/exportar_screen.dart`, `lib/features/results/election_results_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (21/21) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **H-012**: visibilidad de resultados centralizada en `canViewElectionResults`; pantalla de resultados y post-voto comparten regla; votantes requieren elección activa, visible, finalizada y `showResultsAutomatically`; admins pueden revisar siempre. | `lib/core/security/election_visibility.dart`, `lib/features/results/election_results_screen.dart`, `lib/features/voting/voting_screen.dart`, `test/election_visibility_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (21/21) | Aplicado localmente |
| 2026-05-01 | Se mitiga localmente **H-001**: lógica de acceso de rutas extraída a `route_access.dart`, `_RouteGuard` consume `resolveProtectedRouteAccess`, se agregan constantes `adminRouteRoles`/`attendanceRouteRoles`, test puro por todos los roles y matriz rol-ruta en §3. | `lib/core/security/route_access.dart`, `lib/main.dart`, `test/route_access_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (16/16) | Aplicado localmente |
| 2026-05-01 | Se cierra localmente **H-014**: `users.memberId` queda como vínculo canónico usuario↔socio. `AppUser` serializa `memberId`; registro lo persiste desde `members`; login/getCurrentUser hace backfill seguro por `employeeNumber`; perfil resuelve primero por `memberId`; resumen autoriza por `users.memberId`; reglas validan `memberId` contra `workerCode/memberNumber/documentId`. | `lib/core/models/user.dart`, `lib/services/auth_service.dart`, `lib/features/profile/user_profile_screen.dart`, `lib/services/attendance_service.dart`, `firestore.rules`, `test/app_user_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (11/11); `firebase deploy --only firestore --dry-run` OK | Aplicado localmente |
| 2026-05-01 | Perfil de socio agrega **Resumen de Asistencia** reactivo: `MemberAttendanceSummary`/`AsistenciaDetalle`, `AttendanceService.watchMemberAttendanceSummary(memberId)` combina `attendance_events`, subcolección `asistencias`, `eventos`, `asistencias` legacy y `personas`; `UserProfileScreen` muestra convocados, asistencias, faltas injustificadas, no convocados por modalidad/lista explícita y últimos eventos. El pendiente `users.memberId` quedó abordado después en E-026. | `lib/services/attendance_service.dart`, `lib/features/profile/user_profile_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (10/10) | Aplicado localmente |
| 2026-05-01 | Crear Evento legacy cambia `Modalidad` única por **Modalidades no convocadas** multi-selección; se persiste `modalidadesNoConvocadas: List<String>`, se lee `modalidad` legacy como respaldo, el detalle permite editar la lista y el reporte excluye esas modalidades de faltantes mostrándolas como **No convocado / Justificado por modalidad**. | `lib/core/models/asistencia/evento.dart`, `lib/features/asistencia/crear_evento_screen.dart`, `lib/features/asistencia/evento_detail_screen.dart`, `lib/features/attendance/attendance_report_screen.dart`, `lib/services/asistencia_service.dart`, `lib/services/attendance_service.dart`, `test/evento_asistencia_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (8/8) | Aplicado localmente |
| 2026-05-01 | Paginación básica del padrón de socios: `MembersService.getMembersPage()` con límite/cursor y `/members` carga 50 registros iniciales, permite **Cargar más socios** y refresca tras alta/edición/cambio de estado. Búsqueda/exportación conservan lectura completa como fallback funcional. | `lib/services/members_service.dart`, `lib/features/members/members_list_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (5/5) | Aplicado localmente |
| 2026-05-01 | Asistencia legacy con auditoría y borrado consistente: eventos legacy registran create/update/delete en `audit_logs`; asistencias legacy registran alta/baja; `deleteAsistencia` elimina colección global y réplica por evento cuando puede resolver `eventoId`. | `lib/services/asistencia_service.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (5/5) | Aplicado localmente |
| 2026-05-01 | Asistencia sin duplicados operativos: IDs determinísticos para registros legacy (`eventoId + personaId`) y modelo reporte (`personaId` dentro del evento), con prevalidación interna de duplicados en servicio antes de escribir. | `lib/services/asistencia_service.dart`, `lib/services/attendance_service.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (5/5); pendiente doble escaneo real/emulator | Aplicado localmente |
| 2026-05-01 | Auditoría Firestore endurecida: `audit_logs.create` valida contrato de campos, `userId == request.auth.uid`, acciones/entidades permitidas y tipos de campos opcionales; se mantiene append-only y lectura sólo admin. | `firestore.rules`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (5/5); `firebase deploy --only firestore --dry-run` OK | Aplicado localmente |
| 2026-05-01 | Permisos `ADMIN` alineados con UI de socios: `members.create` e `import_logs.create` pasan a `isAdmin()`; `delete` de socios se conserva sólo `SUPERADMIN`. Se corrige texto del perfil QR sobre columnas de importación y se agregan pruebas puras de `modalidad` (`turno` → `modalidad`, `n1` → `N1`). | `firestore.rules`, `lib/features/profile/user_profile_screen.dart`, `lib/services/import_service.dart`, `test/import_service_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (5/5); `firebase deploy --only firestore --dry-run` OK | Aplicado localmente |
| 2026-05-01 | **Sólo expediente:** convención de mantenimiento (§2); coherencia **Editar elección** ↔ **E-008** (bloqueo eliminación candidato con votos); matriz §6 Exportar/Manual/Scanner; limitación modo **Combinado** en texto §4 Exportar. Sin cambios en `lib/`. | `expediente_tecnico_aplicacion.md` | Revisión interna línea contra línea; sin ejecución de QA en esta edición editorial | Documentación |
| 2026-05-01 | Export reporte: lecturas de subcolecciones `asistencias` por evento en paralelo (`Future.wait`) dentro de `fetchAllAttendanceExportsRows`. | `lib/services/attendance_service.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub` OK | Aplicado localmente |
| 2026-05-01 | Exportar asistencias: segmento Legacy / Reporte / Ambos; `fetchAllAttendanceExportsRows` en `AttendanceService` (subcolecciones + `members`); expediente §4 export, H-004, TC-032/033. | `lib/services/attendance_service.dart`, `lib/features/asistencia/exportar_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` OK | Aplicado localmente |
| 2026-05-01 | Expediente técnico: alinear §3–§4 (asistencia), reporte (**`generateAttendanceReport`** dual), Scanner/Registro manual, huecos **H-004/H-013**, conclusión y casos TC-021/TC-031 tras implementación modelo reporte en app. | `expediente_tecnico_aplicacion.md` | Revisión cruzada con `main.dart`, `AsistenciaEventRouteArgs`, `AttendanceService`; `flutter analyze --no-pub` | Documentación |
| 2026-05-01 | Alta/detalle de evento `attendance_events`: `pop(eventId)` + `pushNamed` al detalle; icono lista en AppBar usa `pushNamedAndRemoveUntil('/asistencia', hasta isFirst)` para llegar al hub sin depender de que `/asistencia` ya estuviera debajo en la pila. Detalle histórico pasa `AsistenciaEventRouteArgs.legacy` a registro manual y escáner. | `lib/features/asistencia/crear_attendance_event_screen.dart`, `lib/features/asistencia/evento_detail_screen.dart`, `lib/features/asistencia/attendance_event_detail_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` OK | Aplicado localmente |
| 2026-05-01 | Unificación modelo reporte (`attendance_events`): registro manual resuelve `personaId` en `members`, evita duplicados con subcolección, escribe vía `AttendanceService.registerAttendance`; rutas nombradas aceptan `AsistenciaEventRouteArgs`; home lista segmentada y nueva ruta detalle `/asistencia/attendance_event_detail`. La UI quedó refinada después en **E-041** como «Eventos / Históricos» con creación nueva siempre en `attendance_events`. | `lib/features/asistencia/registro_manual_screen.dart`, `lib/main.dart`, `lib/features/asistencia/asistencia_home_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` OK | Aplicado localmente |
| 2026-05-01 | Evento de asistencia (`attendance_events`): convocatoria «todos los socios activos» o selección múltiple de convocados con búsqueda y acciones rápidas sobre lista filtrada; validación si lista personalizada queda vacía. | `lib/features/asistencia/crear_attendance_event_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub` OK | Aplicado localmente |
| 2026-05-01 | Registro manual asistencia: sustituye dropdown masivo por hoja inferior con filtro textual y selección táctil (`_PersonaPickSheet`). | `lib/features/asistencia/registro_manual_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub` OK | Aplicado localmente |
| 2026-05-01 | Despliegue producción Firebase: `firebase deploy --only firestore` al proyecto configurado (`sistema-integrado-sindicato`). | `firestore.rules` | Deploy CLI completo (`released rules`) | Producción |
| 2026-05-01 | UI `attendance_events`: ruta `/asistencia/crear_attendance_event`, acceso desde asistencia; reglas permiten crear con `isOperator()` igual que flujo práctico de operadores. | `main.dart`, `crear_attendance_event_screen.dart`, `asistencia_home_screen.dart`, `firestore.rules` | `flutter analyze`; `firebase deploy --only firestore --dry-run` OK | Aplicado localmente |
| 2026-05-01 | Import personas legacy: CSV con mismo parser robusto que socios; omitir cabecera heurística. | `importar_personas_screen.dart` | `flutter analyze` | Aplicado localmente |
| 2026-05-01 | Actualización editorial del expediente: alineación con `ImportService` (CSV socios, mapeos, duplicados en import), formulario/import vs legacy personas, distinción pantalla crear evento legacy vs modelo `attendance_events`, flujo de registro alineado con reglas y hueco **H-013**. | `expediente_tecnico_aplicacion.md` | Cruzado con código; `flutter test`/`flutter analyze` sin issues | Documentación |
| 2026-05-01 | Reglas de votos y usuarios reforzadas: `users` restringe rol `VOTER`; votos validan ID propio, elección abierta, candidato existente y contadores exactos. | `firestore.rules` | `firebase deploy --only firestore --dry-run` correcto | Aplicado localmente |
| 2026-05-01 | Elecciones visibles para votantes filtran `isActive`, visibilidad y rango de fechas. | `lib/services/election_service.dart` | `flutter analyze --no-pub` correcto | Aplicado localmente |
| 2026-05-01 | Scanner de asistencia usa evento real inicial o seleccionado para habilitar registro. | `lib/features/asistencia/scanner_screen.dart` | `flutter analyze --no-pub` correcto | Aplicado localmente |
| 2026-05-01 | Importación de socios alinea columnas obligatorias y controla duplicados en archivo/Firestore. | `lib/services/import_service.dart`, `test/import_service_test.dart` | `flutter test --no-pub --reporter expanded` correcto | Aplicado localmente |
| 2026-05-01 | Parser CSV de socios reemplazado por `CsvToListConverter` con soporte de comillas/comas internas y prueba dedicada. | `lib/services/import_service.dart`, `test/import_service_test.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos; 3 tests pasan | Aplicado localmente |
| 2026-05-01 | Alta y edición manual de socios validan unicidad de `memberNumber`, `documentId` y `workerCode`; auditoría registra cambios de identificadores. | `lib/services/members_service.dart` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Eliminación de candidatos con votos queda bloqueada en UI y servicio para preservar resultados. | `lib/features/elections/edit_election_screen.dart`, `lib/services/election_service.dart` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Reporte de asistencia soporta eventos nuevos y fallback legacy desde `eventos/asistencias/personas`. | `lib/services/attendance_service.dart` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Exportación de asistencia genera XLSX real con `package:excel` en lugar de CSV con extensión `.xlsx`. | `lib/services/asistencia_service.dart`, `expediente_tecnico_aplicacion.md` | `dart format`, `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Rutas internas protegidas por autenticación/rol y pantalla de "Sin permisos"; Home muestra Asistencia a `OPERADOR_ASISTENCIA`. | `lib/main.dart`, `lib/features/home/home_screen.dart` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Recuperación de contraseña reacciona al texto ingresado, valida formato de email y visibilidad de resultados respeta `showResultsAutomatically`/fin de elección para votantes. | `lib/features/auth/login_screen.dart`, `lib/features/results/election_results_screen.dart`, `lib/features/voting/voting_screen.dart` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos | Aplicado localmente |
| 2026-05-01 | Login valida perfil Firestore después de Firebase Auth; si falta `users/{uid}`, cierra sesión y muestra mensaje claro. | `lib/services/auth_service.dart`, `lib/providers/auth_provider.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos; 3 tests pasan | Aplicado localmente |
| 2026-05-01 | Historial de Eventos deja de depender de `events` sin escrituras activas y se alimenta desde `audit_logs` mediante adaptador `AuditLog` → `VotoEvent`. | `lib/services/event_service.dart`, `lib/core/models/voto_event.dart`, `lib/features/voto/event_history_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos; 3 tests pasan | Aplicado localmente |
| 2026-05-01 | Registro valida formato de email, reacciona al cambio de email/número de trabajador y exige socio activo en `members` antes de crear `users/{uid}`. | `lib/features/auth/sign_up_screen.dart`, `lib/services/auth_service.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub` y `flutter test --no-pub --reporter expanded` correctos; 3 tests pasan | Aplicado localmente |

### H. Supuestos utilizados

- El nombre funcional se tomó de `MaterialApp.title`, README y `pubspec.yaml`.
- El alcance de usuario se infiere del dominio sindical y roles en código.
- No se asume existencia de datos en Firestore.
- No se asume que reglas locales estén desplegadas en Firebase después de cada edición; para Storage, **E-046** está validado con dry-run pero pendiente de deploy real.
- **Firebase Storage** ya fue aprovisionado en **`sistema-integrado-sindicato`** durante la revisión, pero no se asume lo mismo para otros proyectos/entornos sin ejecutar el flujo de consola (**Comenzar**) y un deploy de **`storage.rules`**.
- Cuando el comportamiento depende de datos reales, se marca como pendiente de confirmar.
