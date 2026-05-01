# Expediente Técnico de la Aplicación

## 1. Información general del proyecto

| Ítem | Detalle |
|---|---|
| Nombre de la aplicación | Sistema Integrado Sindicato / VotaSind. El paquete Flutter se identifica como `fluter_apk`. |
| Objetivo principal | Gestionar procesos sindicales de votación electrónica, control de asistencia, padrón de socios, generación de códigos QR, resultados y auditoría. |
| Tipo de aplicación | Aplicación Flutter multiplataforma: Android, iOS, Web y Windows. |
| Público objetivo | Organización sindical, administradores, operadores de asistencia y votantes/socios. |
| Roles identificados | `SUPERADMIN`, `ADMIN`, `OPERADOR_ASISTENCIA`, `VOTER`, `USER`. |
| Tecnologías utilizadas | Flutter, Dart, Firebase Core, Firebase Auth, Cloud Firestore, Provider, PDF/Printing, File Picker, Excel, CSV, Mobile Scanner, QR Flutter, Share Plus. |
| Backend / servicios externos | Firebase Authentication y Cloud Firestore. |
| Estado actual estimado | MVP avanzado / desarrollo funcional. Conviven dos modelos de asistencia con contrato UI explícito (`AsistenciaEventRouteArgs`): legacy `eventos` y reporte `attendance_events`; escáner/registro manual escriben en la subcolección correcta según contexto. Sigue recomendándose validación con datos/usuarios reales antes de producción. |
| Arquitectura | Capa de UI en `lib/features`, estado global en `lib/providers`, servicios en `lib/services`, modelos en `lib/core/models`, tema y widgets compartidos en `lib/core`. |
| Punto de entrada | `lib/main.dart`. Inicializa Firebase con timeout de 10 segundos y configura Firestore offline fuera de Web. |

## 2. Alcance de la revisión

La revisión se realizó sobre el repositorio local `D:\Sindicat_fluter_apk`, mediante análisis estático del código, revisión de reglas Firestore, rutas, pantallas, modelos, servicios, documentación existente y ejecución de comandos de QA disponibles.

### Elementos revisados

- Pantallas definidas en `MaterialApp.routes`.
- Pantallas internas abiertas con `MaterialPageRoute`.
- Módulos funcionales: autenticación, inicio, perfil, elecciones, votación, resultados, asistencia, socios, auditoría e importaciones.
- Menús, navegación, formularios, botones y acciones principales.
- Validaciones visibles en formularios.
- Estados de carga, vacío, error, éxito y sin permisos.
- Servicios Firestore: `AuthService`, `ElectionService`, `VoteService`, `AsistenciaService`, `AttendanceService`, `MembersService`, `ImportService`, `AuditService`, `EventService`.
- Modelos de datos y serialización `fromMap` / `toMap`.
- Reglas de seguridad en `firestore.rules`.
- Documentación existente en `README.md` y `docs/`.
- Pruebas y análisis estático con Flutter.

### Verificaciones ejecutadas

| Comando | Resultado | Observación |
|---|---|---|
| `flutter analyze --no-pub` | Correcto | Sin issues detectados al 2026-05-01 después de correcciones. |
| `flutter test --no-pub --reporter expanded` | Correcto | 10 pruebas pasan: smoke de login sin sesión, scanner, configuración de importación, parser CSV, modalidad de socios y serialización/compatibilidad de `modalidadesNoConvocadas` en eventos legacy. |
| `firebase deploy --only firestore --dry-run` | Correcto | `firestore.rules` compila correctamente en dry-run después de alinear permisos de `members`/`import_logs` y endurecer contrato de `audit_logs`. |
| Firebase Emulator Suite para reglas | Pendiente/bloqueado | No se ejecutó por requisito local de Java 21+ para Firebase Tools/emuladores. |

### Convención de mantenimiento del expediente

- Este archivo es la **referencia técnico-funcional** del proyecto (alcance, pantallas, riesgos y pruebas sugeridas): cuando el código o Firestore cambien de forma relevante, debe **actualizarse aquí** (y registrar el cambio **arriba** en **§G Bitácora**) antes de comunicar alcance a terceros.
- No duplicar este contenido en otros documentos salvo **extractos** citando la versión autorizada de `expediente_tecnico_aplicacion.md`.

### Limitaciones de la revisión

- No se ejecutó una sesión manual completa con usuario real, Firebase real ni datos reales de producción.
- No se validó cámara física para escaneo QR en dispositivos Android/iOS.
- No se verificó despliegue actual de reglas en Firebase Console.
- No se revisaron capturas de pantalla ni diseño visual en navegador/dispositivo.
- No se validaron índices Firestore reales.
- No se probaron credenciales, roles reales ni permisos desde usuarios distintos.
- Las rutas protegidas se validaron por análisis estático y pruebas automatizadas generales; falta prueba manual por rol real.
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
│   ├── Agregar candidato
│   ├── Emitir voto
│   ├── Resultados
│   └── Historial de eventos de voto
├── Asistencia
│   ├── Dashboard de asistencia (lista segmentada «Clásicos / Reporte»)
│   ├── Crear evento (legacy `eventos`)
│   ├── Crear evento reporte (`attendance_events`)
│   ├── Detalle de evento legacy
│   ├── Detalle de evento reporte
│   ├── Escanear QR / ingreso manual (rutas unificadas con `AsistenciaEventRouteArgs`)
│   ├── Escáner continuo con cámara
│   ├── Registro manual (legacy o modelo nuevo según argumentos de ruta)
│   ├── Personas
│   ├── Códigos QR
│   ├── Asistencias globales (legacy)
│   ├── Exportar asistencias
│   ├── Importar personas legacy
│   └── Reporte de asistencia (`generateAttendanceReport`: nuevo + fallback legacy)
├── Socios
│   ├── Listado de socios
│   ├── Crear / editar socio
│   └── Importación masiva
└── Auditoría
    ├── Audit logs
    └── Historial de eventos adaptado desde audit_logs
```

### Módulos y dependencias

| Módulo | Propósito | Pantallas asociadas | Acciones disponibles | Dependencias |
|---|---|---|---|---|
| Autenticación | Controlar acceso y sesión | Login, Registro | Iniciar sesión, registrarse, recuperar contraseña, cerrar sesión | Firebase Auth, `users`, `AuthProvider` |
| Inicio | Navegar a módulos según rol | Home | Abrir voto, asistencia, socios, auditoría, perfil | `AuthProvider`, `UserRole` |
| Perfil | Mostrar datos de cuenta, resumen de asistencia y QR del socio | Mi Perfil | Ver información, ver resumen de asistencias/faltas, ver QR, cerrar sesión | `users`, `members`, `attendance_events`, subcolecciones `asistencias`, `eventos`, `personas`, `QREncodingHelper` |
| Elecciones | Administración y consulta de elecciones | Elecciones, Crear, Editar, Agregar Candidato | CRUD de elecciones y candidatos | `elections`, `candidates`, `AuditService` |
| Votación | Emitir un voto único por usuario | Votar | Seleccionar candidato, confirmar voto, ver resultados | `votes`, `candidates`, `elections`, `asistencias`, `members` |
| Resultados | Visualizar y exportar conteos | Resultados | Ver ranking, exportar CSV/PDF | `elections`, `candidates`, `printing` |
| Asistencia legacy | Registrar en `eventos` + `asistencias` globales | Home asistencia (tab Clásicos), detalle `eventos`, Scanner/Registro con `AsistenciaEventRouteArgs.legacy` | Alta operativa día a día en colección legacy | `eventos`, `personas`, `asistencias`, `members` |
| Attendance modelo reporte | Eventos para faltantes/presentes con `members` | Home (tab Reporte), crear/reporte/detalle `attendance_events`, Scanner/Manual con `AsistenciaEventRouteArgs.attendance`, FAB lista en AppBar → hub | Registro escribe `attendance_events/{id}/asistencias`; `personaId` es id Firestore del doc `members` | `attendance_events`, subcolección `asistencias`, `members` |
| Socios | Administrar padrón sindical | Socios, Formulario, Importar | Listar por páginas, buscar, filtrar, **export CSV** (`MembersService.buildMembersExportCsv`), crear, editar, activar/desactivar, importar; **campo obligatorio `modalidad`** coherente con turnos (`Modalidad`) | `members`, `import_logs`, `audit_logs` |
| Auditoría | Trazabilidad de acciones | Audit Logs, Historial de Eventos | Consultar y filtrar registros | `audit_logs`; `events` queda como compatibilidad legacy |

## 4. Inventario detallado de pantallas

### Pantalla: Arranque / Control de sesión

**Ruta o ubicación:** `home` de `MaterialApp`, antes de rutas nombradas.

**Objetivo de la pantalla:** inicializar proveedor de autenticación y decidir si se muestra `HomeScreen` o `LoginScreen`.

**Elementos visibles:** indicador `CircularProgressIndicator` durante `auth.isLoading`.

**Acciones disponibles:** no aplica, es estado automático.

**Flujo paso a paso:**
1. `main()` inicializa Firebase.
2. Se crea `AuthProvider` y ejecuta `init()`.
3. Se escucha `authStateChanges`.
4. Si hay usuario, se muestra Home.
5. Si no hay usuario, se muestra Login.

**Validaciones esperadas:** Firebase debe estar inicializado; si falla, la app continúa pero los servicios Firebase pueden no estar disponibles.

**Datos utilizados:** Firebase Auth, documento `users/{uid}`.

**Estados posibles:** cargando, autenticado, no autenticado, error silencioso de Firebase/Auth.

**Observaciones técnicas o funcionales:** el arranque captura excepciones de Firebase e imprime diagnóstico, pero no muestra una pantalla funcional de error al usuario final.

**Problemas encontrados:** si Firebase falla, la app puede continuar hacia pantallas que dependen de Firebase sin mensaje claro.

**Huecos o pendientes por corregir:** falta pantalla de error/reintento de inicialización.

**Prioridad de corrección:** Media.

**Recomendación:** implementar estado de arranque con error visible, reintento y detalle operativo controlado.

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

**Objetivo de la pantalla:** mostrar acceso a módulos según rol del usuario.

**Elementos visibles:** app bar, botón perfil, botón logout, tarjeta de bienvenida, rol, tarjetas de módulos.

**Acciones disponibles:** ir a Voto, Asistencia, Gestión de Socios, Auditoría, Perfil, cerrar sesión.

**Flujo paso a paso:**
1. Se obtiene usuario desde `AuthProvider`.
2. Se muestra tarjeta de bienvenida.
3. Siempre se muestra Sistema de Voto.
4. Para `ADMIN` o `SUPERADMIN` se muestran Asistencia, Socios y Auditoría; para `OPERADOR_ASISTENCIA` se muestra Asistencia.
5. El usuario toca una tarjeta y navega al módulo.

**Validaciones esperadas:** rutas administrativas y operativas protegidas por rol además de ocultarse visualmente.

**Datos utilizados:** `AuthProvider.user`, `UserRole`.

**Estados posibles:** con usuario, sin usuario parcial, logout.

**Observaciones técnicas o funcionales:** corregido localmente. `main.dart` incorpora guard de autenticación y roles para rutas internas; Home fue alineado para mostrar Asistencia a `OPERADOR_ASISTENCIA`.

**Problemas encontrados:** mitigado localmente. Si un usuario autenticado abre una ruta no autorizada por nombre, se muestra pantalla de "Sin permisos".

**Huecos o pendientes por corregir:** falta prueba manual con cuentas reales por rol y prueba widget específica del guard.

**Prioridad de corrección:** Media.

**Recomendación:** mantener el wrapper `_RouteGuard`, agregar matriz rol-ruta y cubrir accesos directos con tests automatizados.

### Pantalla: Mi Perfil

**Ruta o ubicación:** `/profile`.

**Objetivo de la pantalla:** mostrar información de cuenta, información sindical vinculada al padrón, resumen global de asistencia/faltas y QR personal de asistencia.

**Elementos visibles:** app bar, logout, tabs `Información` y `Código QR`, avatar, datos de cuenta, datos de socio (**modalidad visible solo como `Modalidad {letra}`** vía `JustificacionHelper.etiquetaModalidad`, p. ej. `Modalidad N`; sin texto descriptivo *Turno Mañana/Tarde/Noche*), tarjeta **Resumen de Asistencia** con eventos convocados, asistencias, faltas injustificadas, eventos no convocados y últimos eventos, QR o mensajes de indisponibilidad.

**Acciones disponibles:** alternar pestañas, cerrar sesión, volver.

**Flujo paso a paso:**
1. Carga usuario actual.
2. Busca socio por email, employeeNumber/workerCode, documentId, escaneo completo y displayName.
3. En pestaña información muestra cuenta y socio si existe (**valor de modalidad** desde `members.modalidad`; en UI sólo formato **«Modalidad X»**, no etiquetas narrativas de turno).
4. Si hay socio vinculado, `UserProfileScreen` escucha `AttendanceService.watchMemberAttendanceSummary(member.id)` y actualiza en tiempo real la tarjeta de resumen.
5. El resumen cruza `attendance_events/{id}/asistencias`, `attendance_events.miembrosConvocados`, `attendance_events.modalidadesNoConvocadas` y fallback legacy `eventos`/`asistencias`/`personas`.
6. En QR genera código si existe `workerCode`.
7. Si no encuentra socio, muestra causas posibles.

**Validaciones esperadas:** usuario autenticado, socio activo, `workerCode` obligatorio para QR; el resumen sólo debe exponerse al socio dueño o a roles administrativos/operativos autorizados desde servicio.

**Datos utilizados:** `users`, `members`, `attendance_events`, `attendance_events/{id}/asistencias`, `eventos`, `asistencias`, `personas`, `QREncodingHelper`.

**Estados posibles:** cargando socio, socio encontrado, socio no encontrado, sin socios, socio sin workerCode, calculando resumen, resumen disponible, error/permisos del resumen, error de generación QR.

**Observaciones técnicas o funcionales:** el resumen se implementa como stream combinado: cambios en eventos, asistencias nuevas, eventos legacy o datos del socio disparan recalculo. Las faltas contabilizadas son injustificadas: asistencia ausente con `justificacion` se muestra como **Ausente justificado** y no suma a `totalFaltas`; socios en `modalidadesNoConvocadas` o fuera de una lista explícita `miembrosConvocados` se muestran como **No convocado** y tampoco suman faltas. Por compatibilidad, legacy considera convocados a todos los socios salvo eventos ya normalizados con `modalidadesNoConvocadas`. La pantalla aún contiene mucha lógica de búsqueda y diagnóstico dentro de la UI.

**Problemas encontrados:** uso intensivo de `debugPrint`; lógica compleja en widget; mensajes al usuario incluyen pasos administrativos extensos.

**Huecos o pendientes por corregir:** falta vínculo canónico `users.memberId` para reemplazar heurísticas de usuario↔socio y permitir reglas Firestore más estrictas en lectura de resúmenes.

**Prioridad de corrección:** Media.

**Recomendación:** mover resolución de socio a servicio dedicado, persistir relación usuario-socio canónica y cubrir el resumen con pruebas de integración/emulator.

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

**Observaciones técnicas o funcionales:** `getActiveElections` filtra fechas en cliente y no valida `isActive`; solo filtra `isVisibleToVoters` y rango de fecha.

**Problemas encontrados:** una elección con `isActive=false` podría aparecer al votante si está visible y en rango.

**Huecos o pendientes por corregir:** falta filtro por `isActive == true`.

**Prioridad de corrección:** Alta.

**Recomendación:** ajustar query/filtro de elecciones activas y cubrir con test.

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

**Observaciones técnicas o funcionales:** usa eventos de asistencia legacy (`eventos`), mientras el reporte nuevo usa `attendance_events`.

**Problemas encontrados:** no se valida que la fecha inicio sea anterior a fin hasta guardar; no se valida duración mínima o estado inicial.

**Huecos o pendientes por corregir:** falta definición funcional clara de `status: DRAFT` frente a `isActive`.

**Prioridad de corrección:** Media.

**Recomendación:** definir ciclo de vida de elección y unificar estados.

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

**Observaciones técnicas o funcionales:** mitigado (**E-008** / bitácora): la **eliminación** de un candidato **con votos** queda **bloqueada** en UI y en `ElectionService` (no se permite dejar contadores incoherentes por borrado accidental).

**Problemas encontrados:** puede seguir existiendo riesgo menor en **edición** de nombre/orden con elección ya en curso; está fuera del bloqueo explícito de eliminación.

**Huecos o pendientes por corregir:** prueba automatizada (widget o servicio) que confirme rechazo al eliminar candidato con `voteCount > 0`; validación de URL y duplicidad de nombres si negocio lo exige.

**Prioridad de corrección:** Media.

**Recomendación:** mantener cobertura de regresión sobre candidatos con votos; documentar política de “edición después de apertura” si aplica.

### Pantalla: Agregar Candidato

**Ruta o ubicación:** `/voto/add_candidate`.

**Objetivo de la pantalla:** registrar candidatos en una elección.

**Elementos visibles:** nombre, descripción, URL de imagen, orden, botón agregar.

**Acciones disponibles:** guardar candidato, volver.

**Flujo paso a paso:**
1. Recibe `electionId`.
2. Usuario ingresa datos.
3. Valida nombre.
4. Crea documento en `elections/{id}/candidates`.
5. Registra auditoría.

**Validaciones esperadas:** elección válida, nombre obligatorio, orden numérico, URL válida si se usa.

**Datos utilizados:** `candidates`, `audit_logs`.

**Estados posibles:** cargando, error, éxito.

**Observaciones técnicas o funcionales:** se garantiza campo `order`.

**Problemas encontrados:** no hay validación de URL ni duplicidad de candidato.

**Huecos o pendientes por corregir:** falta edición de imagen/orden en el diálogo de edición.

**Prioridad de corrección:** Baja.

**Recomendación:** validar URL y permitir ordenar candidatos desde edición.

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

**Huecos o pendientes por corregir:** no hay prueba automatizada de voto con reglas; el botón de resultados después de votar ya respeta `showResultsAutomatically` y fin de elección, pero falta prueba widget/integración.

**Prioridad de corrección:** Media.

**Recomendación:** corregir reglas de conteo, probar con Firebase Emulator y decidir política de visibilidad de resultados.

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

**Observaciones técnicas o funcionales:** el total mostrado se calcula por suma de candidatos, no por `election.totalVotes`.

**Problemas encontrados:** corregido localmente. Votantes ya no pueden ver resultados por ruta directa ni desde la pantalla de voto registrado si la elección no terminó o si `showResultsAutomatically` está desactivado.

**Huecos o pendientes por corregir:** falta prueba automatizada para acceso directo por ruta y política de publicación/cierre.

**Prioridad de corrección:** Media.

**Recomendación:** mantener regla funcional: resultados visibles para admin o al finalizar si `showResultsAutomatically` está activo.

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

**Observaciones técnicas o funcionales:** `EventService.getAllEvents()` fue adaptado para mapear `AuditLog` a `VotoEvent`; `EventService.logEvent()` permanece como método legacy para escrituras directas en `events` si algún cliente antiguo lo usa.

**Problemas encontrados:** corregido localmente el riesgo de pantalla vacía por colección `events` sin escrituras activas; falta validar con datos reales de `audit_logs`.

**Huecos o pendientes por corregir:** definir si `events` se elimina formalmente, se migra o se documenta como compatibilidad legacy.

**Prioridad de corrección:** Media.

**Recomendación:** mantener `audit_logs` como fuente canónica de auditoría, documentar `events` como legado y validar permisos/índices en Firestore real.

### Pantalla: Control de Asistencia

**Ruta o ubicación:** `/asistencia`.

**Objetivo de la pantalla:** hub del módulo de asistencia: acciones rápidas y dos listas de eventos (legacy vs reporte).

**Elementos visibles:** acciones rápidas Escanear, Asistencias, «Evento reporte», «Evento clásico», Personas, Exportar, Códigos QR, Importar Excel; **segmento** «Clásicos / Reporte»; lista inferior según segmento (stream `eventos` o stream `attendance_events`); **FAB crear** contextual (legacy o crear reporte).

**Acciones disponibles:** navegar a submódulos, abrir detalle legacy o detalle reporte según lista, crear el tipo de evento acorde al segmento.

**Flujo paso a paso:**
1. Segmento **Clásicos**: escucha `AsistenciaService.getAllEventos()` → colección **`eventos`**.
2. Segmento **Reporte**: escucha **`AttendanceService.getAllEvents()`** → **`attendance_events`**.
3. Toque en clásicos → `/asistencia/evento_detail` con `EventoAsistencia`.
4. Toque en reporte → `/asistencia/attendance_event_detail` con `String` id del doc.

**Validaciones esperadas:** acceso para admin/operador, lecturas Firestore según colección activa.

**Datos utilizados:** `eventos` y/o `attendance_events`.

**Estados posibles:** cargando, vacío segmentado (mensajes distintos por pestaña), error, con eventos.

**Observaciones técnicas o funcionales:** rutas hijas siguen usando guards en `main.dart`.

**Problemas encontrados:** corregido localmente. `/asistencia` y subrutas permiten `ADMIN`, `SUPERADMIN` y `OPERADOR_ASISTENCIA`; usuarios sin rol autorizado ven "Sin permisos".

**Huecos o pendientes por corregir:** falta prueba manual con cuenta real `OPERADOR_ASISTENCIA` y test widget de acceso directo por ruta.

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

### Pantalla: Crear Evento de Asistencia (reporte / `attendance_events`)

**Ruta o ubicación:** `/asistencia/crear_attendance_event`.

**Objetivo de la pantalla:** crear un documento en **`attendance_events`** con lugar, fecha, tipo, convocatoria «todos los socios activos» (lista `miembrosConvocados` vacía) o convocados específicos (IDs `members`), validando lista no vacía en modo específicos.

**Elementos visibles:** formulario nombre/descripción/fecha/lugar/tipo; switch convocatoria; selector múltiple de socios cuando aplica.

**Acciones disponibles:** guardar; al éxito **cierra esta ruta con `Navigator.pop(eventId)`** para quien espera resultado y, en el frame siguiente, abre **`/asistencia/attendance_event_detail`**.

**Datos utilizados:** `members` (consultas), colección **`attendance_events`** (escritura vía `AttendanceService.createEvent`).

### Pantalla: Detalle del Evento (reporte / `attendance_events`)

**Ruta o ubicación:** `/asistencia/attendance_event_detail` (`arguments`: id del doc).

**Objetivo de la pantalla:** ver metadatos del evento nuevo modelo, lista de registros en subcolección **`asistencias`**, FAB reporte/manual/escáner y botón lista en AppBar.

**Datos utilizados:** `attendance_events/{id}`, `attendance_events/{id}/asistencias`.

**Observaciones técnicas:** registro manual y escáner se abren con **`AsistenciaEventRouteArgs.attendance(eventId)`**; icono lista usa **`pushNamedAndRemoveUntil('/asistencia', hasta `route.isFirst`)`** para volver siempre al hub de asistencia.

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

**Elementos visibles:** buscador, filtro estado, **exportación CSV** (compartir/desde sistema), botón importar, lista paginada de socios (si hay modalidad, tarjeta muestra **`Modalidad {código}`**), botón **Cargar más socios**, menú desactivar/reactivar, FAB nuevo socio.

**Acciones disponibles:** buscar, filtrar, **exportar padrón (CSV con columna modalidad en orden estándar)**, crear, editar, activar/desactivar, importar.

**Flujo paso a paso:**
1. Carga la primera página de `members` con límite de 50 registros.
2. Permite cargar páginas adicionales con cursor Firestore.
3. Si el usuario busca texto, usa el flujo legacy de búsqueda flexible en cliente sobre `members`.
4. Muestra lista.
5. Permite abrir formulario.
6. Permite cambiar estado con confirmación.

**Validaciones esperadas:** permisos admin, búsqueda eficiente, estado correcto.

**Datos utilizados:** `members`, `audit_logs`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** mitigado 2026-05-01: el listado normal usa `MembersService.getMembersPage()` con `limit` y cursor `startAfterDocument`; búsqueda textual y exportación CSV conservan lectura completa por flexibilidad multi-campo y porque requieren dataset completo.

**Problemas encontrados:** paginación básica implementada para listado; búsqueda/exportación siguen leyendo completo.

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

**Elementos visibles:** instrucciones, selector archivo, botón importar, resumen de importación, errores/duplicados.

**Acciones disponibles:** seleccionar archivo, importar.

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

**Observaciones técnicas o funcionales:** `ImportService.requiredColumns` sigue siendo **`numero_socio`, `nombres`, `apellidos`**, pero el archivo debe incluir también la columna **`modalidad` (obligatoria)** con valores exactos tipo `A`, `B`, `N1`, …; encabezados alternativos: `mod`, `modulo`, `turno` (véase `columnMappings`). `documento` es opcional. **Ya no se persiste modalidad dentro de `additionalData.mod`;** campo canónico en doc `members` es `modalidad`. Si existe `additionalData.mod` antiguo, `Member.fromMap` puede mapearlo como respaldo hasta normalizar datos. `ImportService.parseCsv()` usa `CsvToListConverter`, normaliza saltos CRLF/CR/LF y conserva campos entre comillas con comas internas.

**Problemas encontrados:** corregido localmente el riesgo de datos mal partidos en CSV con comillas/comas internas; falta vista previa de filas antes de confirmar escritura masiva.

**Huecos o pendientes por corregir:** plantilla descargable desde la app; prevalidación/preview antes de importar; ampliar pruebas con comillas escapadas y saltos de línea dentro de campos.

**Prioridad de corrección:** Media.

**Recomendación:** mantener el contrato de columnas y parser CSV cubiertos por tests (`test/import_service_test.dart`) y agregar preview antes de escritura masiva.

**Plantilla XLSX:** ver generación con **`tool/generate_socios_template.dart`** (hojas `Plantilla_socios` + `Modalidades` con todos los códigos y columna **documentar_como** `Modalidad X`).

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
4. Agrega candidatos.
5. Votantes ven elección activa si visible y en rango.

**Errores posibles:** permisos, fechas inválidas, candidato sin `order`, evento no seleccionado.

**Mejoras:** validar `isActive`, bloquear cambios destructivos con votos existentes.

### Flujo: Emitir voto

1. Votante abre elección.
2. Sistema verifica si ya votó.
3. Sistema verifica fechas.
4. Si se requiere asistencia, verifica registro.
5. Usuario selecciona candidato.
6. Confirma.
7. Batch crea voto e incrementa contadores.
8. Se muestra éxito.

**Errores posibles:** permiso denegado por reglas, voto duplicado, falta asistencia, elección cerrada, candidato inexistente.

**Mejora crítica:** corregir reglas de actualización parcial con `diff`.

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
| Perfil | Resumen de asistencia | Stream reactivo con eventos convocados, asistencias, faltas injustificadas, no convocados y últimos eventos | Funcional/parcial | Cruza modelo nuevo y legacy; respeta `miembrosConvocados` y `modalidadesNoConvocadas`; falta prueba con Firebase real/emulator y vínculo canónico `users.memberId` | Alta |
| Perfil | QR personal | Genera QR desde socio | Parcial | Depende de matching heurístico con `members` y de `workerCode` | Media |
| Elecciones | Listar elecciones | Streams Firestore | Funcional/parcial | Votantes filtran `isVisibleToVoters`, `isActive` y rango de fechas; falta prueba con datos reales | Media |
| Elecciones | Crear/editar | CRUD elección | Funcional | Requiere unificar estados | Media |
| Candidatos | Agregar/editar/eliminar | Gestiona subcolección | Funcional/parcial | Eliminación bloqueada si el candidato tiene votos; falta test automatizado | Media |
| Voto | Emitir voto | Batch de voto y contadores | Parcial | Reglas locales compilan y validan voto propio/contadores; falta suite de reglas con emulator | Alta |
| Resultados | Ver conteos | Ranking en tiempo real | Funcional/parcial | Visibilidad para votantes respeta `showResultsAutomatically` y fin de elección; falta test automatizado | Media |
| Asistencia | Crear evento legacy | Crea `eventos` con `modalidadesNoConvocadas` | Funcional | Selector múltiple de modalidades no convocadas; lista vacía significa sin exclusiones | Alta |
| Asistencia | Scanner | QR/código/manual | Funcional/parcial | Legacy y modelo reporte vía rutas/contexto (`AsistenciaEventRouteArgs`); falta prueba de cámara/dispositivo | Media |
| Asistencia | Registro manual | Alta manual | Funcional/parcial | Modo legacy o `attendance_events`; buscador en hoja inferior; padrón muy grande ⇒ coste en cliente | Media |
| Asistencia | Exportar | CSV/PDF/XLSX | Funcional/parcial | Segmentos **Legacy / Reporte / Ambos**; modelo reporte vía `fetchAllAttendanceExportsRows` (subs en paralelo); falta **filtro fino** por evento/fecha dentro de cada origen y prueba manual con datos masivos | Media |
| Asistencia | Reporte faltantes | Calcula ausentes y no convocados | Funcional/parcial | Soporta `attendance_events` y fallback legacy; excluye `modalidadesNoConvocadas` de faltantes; falta prueba con datos reales | Media |
| Socios | CRUD | Listar por páginas, crear/editar/activar/desactivar | Funcional/parcial | **Modalidad obligatoria** en crear/actualizar; unicidad número, documento y `workerCode`; auditoría registra cambio de modalidad; listado `/members` paginado de forma incremental | Media |
| Socios | Importación masiva | CSV/Excel a `members` | Funcional/parcial | **Columna `modalidad` obligatoria** y validación estricta; `documento` opcional; duplicados y parser CSV robusto; falta preview y prueba con datos reales | Media |
| Socios | Exportación CSV | Padrón con columna modalidad | Funcional | `MembersService.buildMembersExportCsv`; celda **`modalidad` = sólo código** (`A`, `N1`, …); orden compatible con importación (`numero_socio`…`modalidad`…`estado`) | Baja/Media |
| Herramienta | Plantilla `socios.xlsx` | Regeneración local | Funcional | Script **`dart run tool/generate_socios_template.dart`**: hoja **`Plantilla_socios`** (cabeceras + ejemplo fila código en `modalidad`) y hoja **`Modalidades`** (todas las letras **`documentar_como`** = **`Modalidad X`**). Si `socios.xlsx` está abierto en Excel, puede generarse **`socios_plantilla.xlsx`** en raíz hasta poder sobrescribir. | Media |
| Auditoría | `audit_logs` | Registra acciones críticas | Parcial | Sin paginación, índices pendientes | Media |
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

### Clasificación por tipo

- Errores funcionales: corregidos localmente E-001, E-003, E-004, E-005, E-008, E-009, E-010, E-011, E-016, E-021, E-022, E-024 y E-025; pendientes funcionales relevantes: reporte/resumen con datos reales, reset con Firebase real, doble escaneo físico y prueba manual de cuenta sin perfil/historial.
- Errores visuales/UX: mensajes extensos en perfil/importación y falta de filtros; E-012 queda corregido localmente con pendiente de validación manual.
- Errores de navegación: E-014 corregido localmente, pendiente validación manual.
- Errores de validación: corregidos localmente E-002, E-006 (**incluye columna modalidad en import socios**), E-007, E-013, E-017, E-018 (**modalidad en padrón**), E-024 (**modalidades no convocadas opcionales**) y E-025 (**faltas injustificadas vs ausencias justificadas/no convocados**); faltan pruebas con archivos reales y emulator.
- Errores de permisos: E-001, E-002, E-014, E-019 y E-020 corregidos localmente, pendientes pruebas con emulator/usuarios reales.
- Errores de rendimiento: E-015 parcialmente mitigado por E-023 en el listado de socios; persisten lecturas completas en búsqueda/exportación y pantallas de asistencia/auditoría.
- Errores de contenido: instrucciones contradictorias de importación/QR corregidas en perfil; mantener revisión de copy operativo con usuarios reales.

## 8. Huecos funcionales pendientes por corregir

| ID | Hueco detectado | Módulo relacionado | Riesgo | Recomendación | Prioridad |
|---|---|---|---|---|---|
| H-013 | **Cerrado flujo escritura modelo nuevo en app (2026-05-01):** crear (`attendance_events`), detalle con FAB manual/QR, rutas **`AsistenciaEventRouteArgs`**, home segmentado. Persiste decisión organizativa si operación continúa usando solo legacy. | Asistencia / reporte nuevo | Divergencias si el mismo día se mezclan registros inconsistentes fuera del flujo indicado | Comunicación operativa: eventos nuevos uso tab **Reporte** y detalle modelo nuevo | Baja/Media |
| H-014 | Falta vínculo canónico `users.memberId` para consultas de perfil/resumen | Perfil / Seguridad | El servicio puede proteger por heurísticas, pero reglas Firestore no pueden restringir con precisión cada lectura de resumen por socio sin relación directa | Agregar `memberId` en `users/{uid}` al registrarse/importar o migrar, y luego endurecer reglas `members`/`collectionGroup('asistencias')` | Alta |
| H-001 | Falta validación manual/test específico del guard por rol | Navegación | Regresión futura en acceso a pantallas por URL/ruta | Crear pruebas widget por rol y ejecutar con cuentas reales | Media |
| H-002 | Cobertura baja de login/voto/asistencia | QA | Regresiones no detectadas en flujos críticos | Crear tests de widgets y servicios con mocks/emulator | Alta |
| H-003 | No hay Firebase Emulator tests para reglas | Seguridad | Reglas rotas en producción | Agregar suite de reglas y Java 21+ local | Alta |
| H-004 | Dos modelos de asistencia coexistiendo | Asistencia | Divergencias si operación no sigue pestañas en UI export/home | **`generateAttendanceReport`** y **`/asistencia/exportar`** contemplan legacy + **`attendance_events`** (pestaña Reporte/Ambos) | Media |
| H-005 | Mitigado parcialmente 2026-05-01: paginación básica en listado de socios (`/members`) | Socios/asistencia/auditoría | Lentitud con muchos datos en búsqueda/exportación y otros listados | Extender paginación a asistencia/auditoría y búsqueda indexada | Media |
| H-006 | No hay confirmación para algunas acciones sensibles | Exportaciones/estado | Acciones accidentales | Revisar UX de confirmaciones | Baja |
| H-007 | Mitigado 2026-05-01: buscador en modal de personas | Asistencia | Listas muy grandes cargan todas en cliente | Paginación o virtual scrolling con backend | Media |
| H-008 | Falta accesibilidad formal | UI | Dificultad para usuarios con lectores | Semántica, labels, contrastes, tamaños | Media |
| H-009 | Falta responsive verificado | Multiplataforma | Layouts pueden romperse | Pruebas visuales Web/Windows/mobile | Media |
| H-010 | Trazabilidad parcialmente consolidada | Auditoría | `events` sigue existiendo como legacy aunque la pantalla ya lee `audit_logs` | Documentar fuente canónica y política de migración/retención | Media |
| H-011 | Cuenta sin perfil ya bloqueada con mensaje; falta flujo de reparación | Auth | El usuario entiende el problema, pero depende de intervención administrativa | Pantalla/proceso admin para crear o reparar `users/{uid}` | Media |
| H-012 | Falta test de visibilidad de resultados | Votación | Regresión futura en publicación anticipada | Cubrir ruta directa y pantalla post-voto con tests | Media |

## 9. Recomendaciones de mejora

| Área | Problema detectado | Solución sugerida | Beneficio esperado | Prioridad |
|---|---|---|---|---|
| Seguridad | Reglas de voto y usuarios corregidas localmente, sin pruebas emulator | Mantener reglas con `diff`, validar con emulator y casos negativos | Voto funcional y menor riesgo de manipulación | Alta |
| Seguridad | Resumen de asistencia en perfil protegido en servicio, pero sin `users.memberId` canónico para reglas por socio | Persistir relación usuario-socio y endurecer lecturas Firestore por propietario/rol | Menor exposición de datos de asistencia entre socios | Alta |
| Arquitectura | Legacy + `attendance_events` con rutas y servicios diferenciados | Comunicar proceso operativo por tab; opcional migración de datos | Menos confusión campo vs reporte consolidado | Alta (gestión) |
| QA | Cobertura automatizada mínima | Ampliar pruebas reales de autenticación, home, rutas y formularios | Suite útil y confiable | Alta |
| UX | Rutas administrativas ya guardadas localmente, sin test por rol | Cubrir `_RouteGuard` con pruebas y matriz rol-ruta | Experiencia clara y segura | Media |
| Datos | WorkerCode cubierto en formulario/import; sin suite amplia dedicada | Mantener validaciones y ampliar pruebas de servicio/mock | Evita duplicidad crítica | Media |
| Rendimiento | Lecturas completas parcialmente mitigadas en `/members`; persisten búsqueda/exportación y otros listados | Extender paginación, filtros Firestore, cache y búsqueda indexada | Mejor desempeño con padrones grandes | Media |
| Importación | `ImportService`/personas legacy: CSV y Excel cubiertos para socios/personas; falta preview y plantillas descargables | Preview y plantilla desde la app | Menos errores operativos | Media |
| Auditoría | `audit_logs` ya alimenta ambas pantallas; `events` sigue legacy | Documentar responsabilidades, migración/retención y permisos | Trazabilidad completa | Media |
| Accesibilidad | No verificada | Agregar labels, contraste, navegación teclado | Cumplimiento y usabilidad | Media |
| Documentación | Falta matriz rol-permiso vigente | Documentar roles vs pantallas vs reglas | Mejor alineación producto/desarrollo | Alta |

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
| Exportaciones | Parcial | CSV/PDF/XLSX real; falta prueba manual de apertura y filtros por evento/fecha. |
| Pruebas automatizadas | Parcial | 10 pruebas pasan; cobertura aún mínima para flujos críticos. |
| Análisis estático | Completo/parcial | `flutter analyze --no-pub` sin issues al 2026-05-01. |

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
| TC-011 | Voto normal | Votante elegible selecciona candidato | Crea voto e incrementa contadores | Alta |
| TC-012 | Voto duplicado | Reingresar y votar de nuevo | Bloquea y muestra ya votó | Alta |
| TC-013 | Voto con asistencia requerida sin asistencia | Abrir elección vinculada | Bloquea voto | Alta |
| TC-014 | Voto con reglas emulator | Ejecutar batch como VOTER | Reglas permiten solo voto legítimo | Alta |
| TC-015 | Resultados visibilidad | Votante intenta ver resultados antes de tiempo | Respeta `showResultsAutomatically` | Media |
| TC-016 | Crear evento asistencia | Operador/admin crea evento y opcionalmente marca modalidades D/N1/N2 como no convocadas | Evento aparece en dashboard y persiste `modalidadesNoConvocadas` | Alta |
| TC-016B | Reporte con modalidades no convocadas | Crear evento legacy con D/N1/N2 excluidas; tener socios activos en esas modalidades sin asistencia | Esos socios aparecen como No convocado / Justificado por modalidad y no suman en faltantes | Alta |
| TC-016C | Resumen de asistencia en perfil | Entrar como socio; crear/registrar eventos nuevo y legacy con presente, ausente justificado, ausente sin justificación, modalidad no convocada y evento con `miembrosConvocados` que no incluya al socio | La tarjeta del perfil se actualiza en tiempo real; presentes suman asistencias, no convocados por modalidad/lista explícita no suman faltas y sólo ausentes injustificados suman `Faltas injustificadas` | Alta |
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

El mayor riesgo residual en datos de asistencia es **organizativo**: conviven **`eventos`** y **`attendance_events`** pero la aplicación ya enruta y persiste cada flujo coherentemente (**`AsistenciaEventRouteArgs`** + servicios); el reporte (**`generateAttendanceReport`**) consume ambos. Quedan mejoras como exportación única desde modelo nuevo si se desea vista global. El riesgo de seguridad de reglas de voto/usuarios fue corregido localmente y las reglas compilan en dry-run; falta suite emulator con casos negativos.

La completitud funcional estimada es alta en cobertura de pantallas y media-alta en robustez local. El nivel de completitud global estimado sube a 82-86%, condicionado por pruebas automatizadas adicionales, validación con Firebase real/emulator y pruebas manuales por rol/datos reales.

Prioridades antes de entrega o producción:

1. Validar reglas Firestore con Firebase Emulator y usuarios reales por rol.
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
| Crear evento asistencia | `/asistencia/crear_evento` |
| Crear evento reporte (`attendance_events`) | `/asistencia/crear_attendance_event` |
| Detalle evento | `/asistencia/evento_detail` |
| Detalle evento reporte (`attendance_events`) | `/asistencia/attendance_event_detail` (`arguments`: id doc) |
| Registro manual | `/asistencia/registro_manual` (`EventoAsistencia` \| `AsistenciaEventRouteArgs`) |
| Scanner | `/asistencia/scanner` (`EventoAsistencia` \| `AsistenciaEventRouteArgs`) |
| Scanner QR cámara | `MaterialPageRoute` interna |
| Personas asistencia | `/asistencia/personas` |
| Asistencias | `/asistencia/asistencias` |
| Exportar asistencia | `/asistencia/exportar` |
| Importar personas | `/asistencia/importar_personas` |
| Códigos QR | `/asistencia/qr_codes` |
| Reporte asistencia | `/attendance/report` |
| Gestión socios | `/members` |
| Formulario socio | `MaterialPageRoute` interna |
| Importar socios | `/members/import` |
| Audit logs | `/audit/logs` |

### B. Colecciones Firestore identificadas

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
| `AppUser` | `lib/core/models/user.dart` | id, email, displayName, role, employeeNumber |
| `Election` | `lib/core/models/election.dart` | title, dates, isActive, isVisibleToVoters, requireAttendance, totalVotes |
| `Candidate` | `lib/core/models/candidate.dart` | electionId, name, order, voteCount |
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

`flutter analyze --no-pub` se ejecutó nuevamente el 2026-05-01 y no encontró issues.

Resultado actual:

- Comando: `flutter analyze --no-pub`.
- Estado: correcto.
- Observación: la revisión estática local queda limpia después de las correcciones aplicadas.

### E. Resultados de pruebas

`flutter test --no-pub --reporter expanded` se ejecutó nuevamente el 2026-05-01 y pasó correctamente:

- `test/widget_test.dart`: valida que se muestre Login cuando no hay sesión activa.
- `test/import_service_test.dart`: valida contrato de columnas obligatorias, separación de `numero_socio` frente a `worker_code`, CSV con campos entre comillas/comas internas, obligatoriedad de `modalidad` y normalización/canonización de alias (`turno` → `modalidad`, `n1` → `N1`).
- `test/evento_asistencia_test.dart`: valida serialización canónica de `modalidadesNoConvocadas`, lectura de `modalidad` legacy como exclusión única y descarte de valores inválidos/duplicados.
- `test/scanner_screen_test.dart`: valida que el scanner muestre nombre/modalidad al registrar por código y no bloquee registros cuando la modalidad está sin asignar.
- Estado: 10 pruebas pasan.
- Acción recomendada: ampliar cobertura de rutas por rol, reglas Firestore, voto, asistencia e importación con datos representativos.

### F. Validación de reglas Firestore

- `firebase deploy --only firestore --dry-run` se ejecutó nuevamente el 2026-05-01: correcto (compilación local de reglas actuales, incluyendo E-019 y E-020).
- `firebase deploy --only firestore` (sin dry-run) al proyecto **`sistema-integrado-sindicato`** se ejecutó previamente el mismo día: **deploy complete** según ejecución en entorno de desarrollo. Tras E-019/E-020 se validó con dry-run, pero queda pendiente repetir deploy real antes de pruebas operativas con `ADMIN`.
- Limitación: no sustituye pruebas con Firebase Emulator; para emuladores suele hacer falta Java 21+ local.

### G. Bitácora de correcciones

_Se añaden entradas nuevas arriba; las anteriores se conservan como historial._

| Fecha | Corrección | Archivos | Validación | Estado |
|---|---|---|---|---|
| 2026-05-01 | Perfil de socio agrega **Resumen de Asistencia** reactivo: `MemberAttendanceSummary`/`AsistenciaDetalle`, `AttendanceService.watchMemberAttendanceSummary(memberId)` combina `attendance_events`, subcolección `asistencias`, `eventos`, `asistencias` legacy y `personas`; `UserProfileScreen` muestra convocados, asistencias, faltas injustificadas, no convocados por modalidad/lista explícita y últimos eventos. Se documenta pendiente `users.memberId` para endurecer reglas por propietario. | `lib/services/attendance_service.dart`, `lib/features/profile/user_profile_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` (10/10) | Aplicado localmente |
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
| 2026-05-01 | Alta evento reporte / detalle reporte: `pop(eventId)` + `pushNamed` al detalle; icono lista en AppBar usa `pushNamedAndRemoveUntil('/asistencia', hasta isFirst)` para llegar al hub sin depender de que `/asistencia` ya estuviera debajo en la pila. Detalle legacy pasa `AsistenciaEventRouteArgs.legacy` a registro manual y escáner. | `lib/features/asistencia/crear_attendance_event_screen.dart`, `lib/features/asistencia/evento_detail_screen.dart`, `lib/features/asistencia/attendance_event_detail_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` OK | Aplicado localmente |
| 2026-05-01 | Unificación modelo reporte (`attendance_events`): registro manual resuelve `personaId` en `members`, evita duplicados con subcolección, escribe vía `AttendanceService.registerAttendance`; rutas nombradas aceptan `AsistenciaEventRouteArgs`; home lista segmentada «Clásicos / Reporte», FAB contextual y nueva ruta detalle `/asistencia/attendance_event_detail`. | `lib/features/asistencia/registro_manual_screen.dart`, `lib/main.dart`, `lib/features/asistencia/asistencia_home_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub --reporter expanded` OK | Aplicado localmente |
| 2026-05-01 | Evento reporte (`attendance_events`): convocatoria «todos los socios activos» o selección múltiple de convocados con búsqueda y acciones rápidas sobre lista filtrada; validación si lista personalizada queda vacía. | `lib/features/asistencia/crear_attendance_event_screen.dart`, `expediente_tecnico_aplicacion.md` | `flutter analyze --no-pub`; `flutter test --no-pub` OK | Aplicado localmente |
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
- No se asume que reglas locales estén desplegadas en Firebase.
- Cuando el comportamiento depende de datos reales, se marca como pendiente de confirmar.
