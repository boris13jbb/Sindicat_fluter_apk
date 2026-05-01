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
| Estado actual estimado | MVP avanzado / desarrollo funcional. No se recomienda producción sin corregir hallazgos críticos de reglas, pruebas, rutas protegidas y consistencia entre colecciones de asistencia. |
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
| `flutter analyze --no-pub` | Falló con 115 issues | Mayormente warnings e infos: imports no usados, APIs deprecadas, código no usado, casts innecesarios y scripts con `print`. |
| `flutter test --no-pub --reporter expanded` | Falló | `test/widget_test.dart` conserva el test de contador por defecto y espera textos `0` y `1`, inexistentes en la app real. |
| `flutter analyze` y `flutter test` iniciales | Timeout a 120s | Se reintentó con `--no-pub`; el segundo intento sí produjo resultados. |

### Limitaciones de la revisión

- No se ejecutó una sesión manual completa con usuario real, Firebase real ni datos reales de producción.
- No se validó cámara física para escaneo QR en dispositivos Android/iOS.
- No se verificó despliegue actual de reglas en Firebase Console.
- No se revisaron capturas de pantalla ni diseño visual en navegador/dispositivo.
- No se validaron índices Firestore reales.
- No se probaron credenciales, roles reales ni permisos desde usuarios distintos.
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
│   ├── Dashboard de asistencia
│   ├── Crear evento
│   ├── Detalle de evento
│   ├── Escanear QR / ingreso manual
│   ├── Escáner continuo con cámara
│   ├── Registro manual
│   ├── Personas
│   ├── Códigos QR
│   ├── Asistencias globales
│   ├── Exportar asistencias
│   ├── Importar personas legacy
│   └── Reporte de asistencia
├── Socios
│   ├── Listado de socios
│   ├── Crear / editar socio
│   └── Importación masiva
└── Auditoría
    ├── Audit logs
    └── Events legacy
```

### Módulos y dependencias

| Módulo | Propósito | Pantallas asociadas | Acciones disponibles | Dependencias |
|---|---|---|---|---|
| Autenticación | Controlar acceso y sesión | Login, Registro | Iniciar sesión, registrarse, recuperar contraseña, cerrar sesión | Firebase Auth, `users`, `AuthProvider` |
| Inicio | Navegar a módulos según rol | Home | Abrir voto, asistencia, socios, auditoría, perfil | `AuthProvider`, `UserRole` |
| Perfil | Mostrar datos de cuenta y QR del socio | Mi Perfil | Ver información, ver QR, cerrar sesión | `users`, `members`, `QREncodingHelper` |
| Elecciones | Administración y consulta de elecciones | Elecciones, Crear, Editar, Agregar Candidato | CRUD de elecciones y candidatos | `elections`, `candidates`, `AuditService` |
| Votación | Emitir un voto único por usuario | Votar | Seleccionar candidato, confirmar voto, ver resultados | `votes`, `candidates`, `elections`, `asistencias`, `members` |
| Resultados | Visualizar y exportar conteos | Resultados | Ver ranking, exportar CSV/PDF | `elections`, `candidates`, `printing` |
| Asistencia legacy | Registrar asistencias operativas | Asistencia, Evento, Scanner, Registro Manual, Personas, QR, Exportar | Crear eventos, registrar asistencia, importar personas, generar QR, exportar | `eventos`, `personas`, `asistencias`, `members` |
| Attendance nuevo | Reporte automático de faltas | Reporte de Asistencia | Calcular presentes/faltantes | `attendance_events`, `members` |
| Socios | Administrar padrón sindical | Socios, Formulario, Importar | Buscar, filtrar, crear, editar, activar/desactivar, importar | `members`, `import_logs`, `audit_logs` |
| Auditoría | Trazabilidad de acciones | Audit Logs, Historial de Eventos | Consultar y filtrar registros | `audit_logs`, `events` |

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

**Observaciones técnicas o funcionales:** existe validación de campos obligatorios, pero no validación de formato de email.

**Problemas encontrados:** el botón `Enviar` del diálogo de recuperación puede quedar deshabilitado si el campo inicia vacío, porque el `TextField` no dispara `setState` ni listener dentro del diálogo.

**Huecos o pendientes por corregir:** falta validación de formato email y manejo visible para usuario autenticado sin documento `users`.

**Prioridad de corrección:** Media.

**Recomendación:** agregar listener al controlador de recuperación, validar email con regex y mostrar mensajes estandarizados.

### Pantalla: Registro

**Ruta o ubicación:** `/signup`.

**Objetivo de la pantalla:** crear una cuenta con email, contraseña y número de trabajador.

**Elementos visibles:** app bar, nombre completo, número de trabajador, email, contraseña, confirmar contraseña, mensaje de longitud mínima, botón crear cuenta.

**Acciones disponibles:** crear cuenta, volver.

**Flujo paso a paso:**
1. El usuario completa datos.
2. La UI valida número de trabajador, email no vacío, contraseña mínima y confirmación.
3. `AuthProvider.signUpWithEmployeeNumber` llama a `AuthService`.
4. Se crea usuario en Firebase Auth.
5. Se crea documento en `users/{uid}`.
6. Se redirige a Home si la sesión queda activa.

**Validaciones esperadas:** número de trabajador obligatorio y único, email válido, contraseña mínima, confirmación igual, rol seguro por defecto.

**Datos utilizados:** `email`, `displayName`, `employeeNumber`, `role`, Firebase Auth, `users`.

**Estados posibles:** formulario incompleto, cargando, error, éxito.

**Observaciones técnicas o funcionales:** `AuthProvider` usa rol `VOTER` por defecto, mientras `AuthService` tiene default `USER`; en el flujo actual de UI se pasa `VOTER`.

**Problemas encontrados:** reglas Firestore actuales permiten `create` de `users/{uid}` sin validar que el rol sea `VOTER`, contradiciendo el criterio de seguridad documentado en AGENTS.

**Huecos o pendientes por corregir:** falta validación de formato email y unicidad de número de trabajador frente a `members`.

**Prioridad de corrección:** Alta.

**Recomendación:** reforzar regla de creación de usuario para impedir escalamiento de rol y validar relación con padrón si el negocio lo requiere.

### Pantalla: Home / Dashboard principal

**Ruta o ubicación:** `/home`.

**Objetivo de la pantalla:** mostrar acceso a módulos según rol del usuario.

**Elementos visibles:** app bar, botón perfil, botón logout, tarjeta de bienvenida, rol, tarjetas de módulos.

**Acciones disponibles:** ir a Voto, Asistencia, Gestión de Socios, Auditoría, Perfil, cerrar sesión.

**Flujo paso a paso:**
1. Se obtiene usuario desde `AuthProvider`.
2. Se muestra tarjeta de bienvenida.
3. Siempre se muestra Sistema de Voto.
4. Para `ADMIN` o `SUPERADMIN` se muestran Asistencia, Socios y Auditoría.
5. El usuario toca una tarjeta y navega al módulo.

**Validaciones esperadas:** rutas administrativas deberían protegerse por rol además de ocultarse visualmente.

**Datos utilizados:** `AuthProvider.user`, `UserRole`.

**Estados posibles:** con usuario, sin usuario parcial, logout.

**Observaciones técnicas o funcionales:** la UI oculta módulos administrativos, pero muchas rutas no tienen guardia propia.

**Problemas encontrados:** usuarios podrían intentar abrir rutas administrativas por nombre; la protección queda delegada a Firestore y a checks parciales por pantalla.

**Huecos o pendientes por corregir:** falta middleware/guard de rutas por rol.

**Prioridad de corrección:** Alta.

**Recomendación:** crear un wrapper de ruta protegida por rol y aplicarlo a rutas administrativas.

### Pantalla: Mi Perfil

**Ruta o ubicación:** `/profile`.

**Objetivo de la pantalla:** mostrar información de cuenta y QR personal de asistencia.

**Elementos visibles:** app bar, logout, tabs `Información` y `Código QR`, avatar, datos de cuenta, datos de socio, QR o mensajes de indisponibilidad.

**Acciones disponibles:** alternar pestañas, cerrar sesión, volver.

**Flujo paso a paso:**
1. Carga usuario actual.
2. Busca socio por email, employeeNumber/workerCode, documentId, escaneo completo y displayName.
3. En pestaña información muestra cuenta y socio si existe.
4. En QR genera código si existe `workerCode`.
5. Si no encuentra socio, muestra causas posibles.

**Validaciones esperadas:** usuario autenticado, socio activo, `workerCode` obligatorio para QR.

**Datos utilizados:** `users`, `members`, `QREncodingHelper`.

**Estados posibles:** cargando socio, socio encontrado, socio no encontrado, sin socios, socio sin workerCode, error de generación QR.

**Observaciones técnicas o funcionales:** la pantalla contiene mucha lógica de búsqueda y diagnóstico dentro de la UI.

**Problemas encontrados:** uso intensivo de `debugPrint`; lógica compleja en widget; mensajes al usuario incluyen pasos administrativos extensos.

**Huecos o pendientes por corregir:** falta endpoint/servicio único para resolver socio actual.

**Prioridad de corrección:** Media.

**Recomendación:** mover resolución de socio a servicio dedicado y simplificar mensajes visibles.

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

**Observaciones técnicas o funcionales:** al eliminar candidato se advierte pérdida de votos asociados, pero el servicio elimina solo el documento del candidato y no recalcula `totalVotes`.

**Problemas encontrados:** eliminación de candidato puede dejar contadores inconsistentes si tenía votos.

**Huecos o pendientes por corregir:** no hay bloqueo para editar/eliminar candidatos en elecciones con votos.

**Prioridad de corrección:** Alta.

**Recomendación:** impedir cambios destructivos si existen votos o recalcular resultados mediante función controlada.

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

**Huecos o pendientes por corregir:** no hay prueba automatizada de voto con reglas; `showResultsAutomatically` no controla el botón de resultados después de votar.

**Prioridad de corrección:** Alta.

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

**Problemas encontrados:** votantes pueden acceder a resultados por ruta o desde pantalla de voto registrado sin validar `showResultsAutomatically`.

**Huecos o pendientes por corregir:** falta control de visibilidad de resultados para votantes.

**Prioridad de corrección:** Media.

**Recomendación:** aplicar regla funcional: resultados visibles solo para admin o al finalizar si `showResultsAutomatically` está activo.

### Pantalla: Historial de Eventos de Voto

**Ruta o ubicación:** `/voto/event_history`.

**Objetivo de la pantalla:** listar eventos legacy de votación desde colección `events`.

**Elementos visibles:** app bar, filtro por entidad, lista de eventos con tipo, descripción, fecha, usuario y error.

**Acciones disponibles:** filtrar, reintentar, volver.

**Flujo paso a paso:**
1. Escucha `events` ordenado por timestamp.
2. Si hay filtro, filtra en cliente por entidad.
3. Muestra tarjetas o estado vacío.

**Validaciones esperadas:** permisos de lectura, índice por timestamp.

**Datos utilizados:** `events`.

**Estados posibles:** cargando, vacío, error de permisos, error de índice, offline, con datos.

**Observaciones técnicas o funcionales:** `EventService.logEvent` no aparece usado en el código revisado.

**Problemas encontrados:** la pantalla puede quedar siempre vacía si ningún flujo escribe en `events`; la app usa principalmente `audit_logs`.

**Huecos o pendientes por corregir:** definir si `events` sigue vigente o migrar a `audit_logs`.

**Prioridad de corrección:** Media.

**Recomendación:** consolidar auditoría en una sola colección o escribir ambos registros de forma deliberada.

### Pantalla: Control de Asistencia

**Ruta o ubicación:** `/asistencia`.

**Objetivo de la pantalla:** dashboard del módulo de asistencia y listado de eventos recientes.

**Elementos visibles:** acciones rápidas Escanear, Asistencias, Personas, Exportar, Códigos QR, Importar Excel; lista de eventos; FAB crear.

**Acciones disponibles:** navegar a submódulos, abrir evento, crear evento.

**Flujo paso a paso:**
1. Escucha `eventos`.
2. Muestra acciones rápidas.
3. Si no hay eventos muestra estado vacío y botón crear.
4. Si hay eventos muestra tarjetas.

**Validaciones esperadas:** acceso para admin/operador, lectura de eventos.

**Datos utilizados:** `eventos`.

**Estados posibles:** cargando, vacío, error, con eventos.

**Observaciones técnicas o funcionales:** la pantalla no valida rol internamente.

**Problemas encontrados:** ruta administrativa sin guard de rol en UI.

**Huecos o pendientes por corregir:** falta soporte explícito para `OPERADOR_ASISTENCIA` en Home; reglas sí contemplan operador pero Home solo muestra asistencia a admin/superadmin.

**Prioridad de corrección:** Alta.

**Recomendación:** alinear navegación UI con roles de reglas: permitir operador y bloquear no autorizados.

### Pantalla: Crear Evento de Asistencia

**Ruta o ubicación:** `/asistencia/crear_evento`.

**Objetivo de la pantalla:** crear eventos legacy de asistencia.

**Elementos visibles:** nombre, descripción, tipo ordinaria/extraordinaria, selector fecha/hora, modalidad de turno, justificación automática, botón guardar.

**Acciones disponibles:** seleccionar tipo, fecha, modalidad, guardar.

**Flujo paso a paso:**
1. Usuario ingresa nombre.
2. Opcionalmente ingresa descripción.
3. Selecciona tipo y fecha.
4. Selecciona modalidad.
5. Guarda en `eventos`.

**Validaciones esperadas:** nombre obligatorio, fecha válida, permisos operador/admin.

**Datos utilizados:** `eventos`.

**Estados posibles:** formulario, cargando, éxito, error.

**Observaciones técnicas o funcionales:** no usa `Form` ni `TextFormField`, validación manual del nombre.

**Problemas encontrados:** modalidad es opcional, pero luego se usa para justificar asistencias; falta decidir si debe ser obligatoria.

**Huecos o pendientes por corregir:** lugar/convocados no existen en legacy, pero reporte nuevo espera esos campos en `attendance_events`.

**Prioridad de corrección:** Media.

**Recomendación:** unificar modelo de evento o mapear legacy a nuevo modelo.

### Pantalla: Detalle del Evento

**Ruta o ubicación:** `/asistencia/evento_detail`.

**Objetivo de la pantalla:** ver datos de un evento y sus registros de asistencia.

**Elementos visibles:** datos del evento, modalidad, tipo, lista de registros, botones editar modalidad/eliminar evento, FAB reporte, FAB registro manual, FAB escanear.

**Acciones disponibles:** editar modalidad, eliminar evento, eliminar asistencia, abrir reporte, registro manual, escanear QR.

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

**Problemas encontrados:** el reporte se abre con `/attendance/report` usando ID legacy de `eventos`, pero `AttendanceReportScreen` busca en `attendance_events`, por lo que puede fallar con "Evento no encontrado".

**Huecos o pendientes por corregir:** falta paginación y batch de lookup de miembros.

**Prioridad de corrección:** Alta.

**Recomendación:** corregir reporte para usar `eventos/asistencias` o migrar eventos legacy a `attendance_events`.

### Pantalla: Scanner / Ingreso de código

**Ruta o ubicación:** `/asistencia/scanner`.

**Objetivo de la pantalla:** registrar asistencia mediante QR, código de barras o ingreso manual.

**Elementos visibles:** botón escanear QR, selector de evento si no se recibe argumento, instrucciones, campo código, mensaje, botón registrar asistencia.

**Acciones disponibles:** seleccionar evento, escanear con cámara, ingresar código, registrar asistencia.

**Flujo paso a paso:**
1. Sincroniza `members` hacia `personas`.
2. Si no viene evento, carga `eventos` y selecciona uno.
3. Usuario escanea o pega código.
4. `registrarAsistenciaDesdeEscaneo` parsea QR.
5. Busca/crea persona y crea asistencia.

**Validaciones esperadas:** evento seleccionado, código no vacío, persona identificable, no duplicado.

**Datos utilizados:** `eventos`, `members`, `personas`, `asistencias`.

**Estados posibles:** sin eventos, evento seleccionado, código vacío, cargando, éxito, duplicado/error.

**Observaciones técnicas o funcionales:** contiene un getter `_evento` que intenta buscar evento por ID pero devuelve `null`.

**Problemas encontrados:** el botón manual usa `onPressed: _evento != null ? _registrar : null`; cuando la pantalla se abre sin evento, `_evento` queda `null` aunque `_eventoReal` sí tenga selección. Esto puede dejar deshabilitado el registro manual.

**Huecos o pendientes por corregir:** falta prueba del scanner abierto desde Home sin evento.

**Prioridad de corrección:** Alta.

**Recomendación:** reemplazar condición por `_eventoReal != null` y eliminar `_getEventoFromId` incompleto.

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
5. Muestra éxito o error y reanuda escaneo.

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

**Objetivo de la pantalla:** registrar presente/ausente manualmente para una persona existente o nueva.

**Elementos visibles:** información del evento, selector persona existente/nueva persona, campos nombre/apellidos/número trabajador, switch asistió/no asistió, justificación, botón guardar.

**Acciones disponibles:** sincronizar miembros, seleccionar persona, crear persona, registrar asistencia, marcar ausencia.

**Flujo paso a paso:**
1. Sincroniza miembros activos a `personas`.
2. Usuario elige persona existente o nueva.
3. Define asistió/no asistió.
4. Ingresa justificación obligatoria.
5. Verifica duplicado.
6. Guarda en `asistencias` y subcolección `eventos/{id}/asistencias`.

**Validaciones esperadas:** persona seleccionada o nueva completa, número trabajador obligatorio, justificación obligatoria, no duplicado.

**Datos utilizados:** `members`, `personas`, `asistencias`, `eventos`.

**Estados posibles:** cargando personas, vacío, error, formulario inválido, duplicado, éxito.

**Observaciones técnicas o funcionales:** combina fuentes modernas y legacy.

**Problemas encontrados:** usa `firstOrNull`; compila con Flutter actual, pero conviene asegurar compatibilidad mínima real del SDK.

**Huecos o pendientes por corregir:** falta búsqueda dentro del dropdown si hay muchos socios.

**Prioridad de corrección:** Media.

**Recomendación:** reemplazar dropdown simple por buscador/paginación para padrones grandes.

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

**Objetivo de la pantalla:** copiar CSV y exportar Excel/PDF de asistencias.

**Elementos visibles:** total de registros, botón copiar CSV, lista de registros, botones Excel/PDF.

**Acciones disponibles:** copiar CSV, generar Excel, generar PDF.

**Flujo paso a paso:**
1. Escucha asistencias globales.
2. Serializa datos.
3. Copia CSV al portapapeles o genera bytes.
4. Comparte archivo con `Printing.sharePdf`.

**Validaciones esperadas:** lista no vacía, generación completada, permisos de compartir.

**Datos utilizados:** `asistencias`, `eventos`, `personas`, `printing`.

**Estados posibles:** cargando, vacío, error, generando, éxito.

**Observaciones técnicas o funcionales:** `generateExcelExportStatic` genera CSV en bytes, pero se comparte como `.xlsx`.

**Problemas encontrados:** posible inconsistencia de formato real del archivo Excel.

**Huecos o pendientes por corregir:** falta filtro de exportación por evento/fecha.

**Prioridad de corrección:** Media.

**Recomendación:** generar XLSX real con librería Excel o renombrar exportación como CSV.

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

**Problemas encontrados:** seleccionar CSV puede fallar o no procesarse correctamente; textos de instrucciones son demasiado específicos y no genéricos.

**Huecos o pendientes por corregir:** falta parser CSV real y mapeo configurable de columnas.

**Prioridad de corrección:** Media.

**Recomendación:** separar importador legacy CSV/Excel y mostrar plantilla descargable.

### Pantalla: Reporte de Asistencia

**Ruta o ubicación:** `/attendance/report`.

**Objetivo de la pantalla:** calcular convocados, presentes, faltantes y tasa de asistencia.

**Elementos visibles:** información de evento, estadísticas, barra de asistencia, lista completa/faltantes.

**Acciones disponibles:** alternar vista de faltantes, reintentar carga.

**Flujo paso a paso:**
1. Recibe `eventId`.
2. `AttendanceService` busca en `attendance_events`.
3. Obtiene convocados o todos los miembros activos.
4. Lee subcolección `attendance_events/{eventId}/asistencias`.
5. Calcula presentes y ausentes.

**Validaciones esperadas:** evento existente en `attendance_events`, miembros activos, asistencias en subcolección nueva.

**Datos utilizados:** `attendance_events`, subcolección `asistencias`, `members`.

**Estados posibles:** cargando, error, sin datos, con reporte.

**Observaciones técnicas o funcionales:** se navega desde detalle legacy con ID de `eventos`, no necesariamente existente en `attendance_events`.

**Problemas encontrados:** alta probabilidad de error "Evento no encontrado" al abrir desde eventos legacy.

**Huecos o pendientes por corregir:** no hay pantalla de creación para `attendance_events` en rutas revisadas.

**Prioridad de corrección:** Alta.

**Recomendación:** unificar el módulo de asistencia o adaptar el reporte a `eventos/asistencias`.

### Pantalla: Gestión de Socios

**Ruta o ubicación:** `/members`.

**Objetivo de la pantalla:** administrar padrón sindical.

**Elementos visibles:** buscador, filtro estado, botón importar, lista de socios, menú desactivar/reactivar, FAB nuevo socio.

**Acciones disponibles:** buscar, filtrar, crear, editar, activar/desactivar, importar.

**Flujo paso a paso:**
1. Escucha `members`.
2. Filtra y ordena en cliente.
3. Muestra lista.
4. Permite abrir formulario.
5. Permite cambiar estado con confirmación.

**Validaciones esperadas:** permisos admin, búsqueda eficiente, estado correcto.

**Datos utilizados:** `members`, `audit_logs`.

**Estados posibles:** cargando, vacío, error, con datos.

**Observaciones técnicas o funcionales:** filtros se hacen en cliente para evitar índices compuestos.

**Problemas encontrados:** sin paginación; lectura completa de padrón.

**Huecos o pendientes por corregir:** falta eliminación permanente desde UI aunque existe en servicio.

**Prioridad de corrección:** Media.

**Recomendación:** implementar paginación y búsqueda indexada si el padrón crece.

### Pantalla: Formulario de Socio

**Ruta o ubicación:** pantalla interna `MemberFormScreen`, abierta desde `/members`.

**Objetivo de la pantalla:** crear o editar socio.

**Elementos visibles:** número socio, nombres, apellidos, workerCode, documento, email, teléfono, botón crear/actualizar.

**Acciones disponibles:** guardar, volver.

**Flujo paso a paso:**
1. Si es edición precarga datos.
2. Valida obligatorios.
3. Construye `Member`.
4. Crea o actualiza documento en `members`.
5. Registra auditoría.

**Validaciones esperadas:** número socio único, workerCode único, documento único, email válido.

**Datos utilizados:** `members`, `audit_logs`, usuario autenticado.

**Estados posibles:** formulario, cargando, error, éxito.

**Observaciones técnicas o funcionales:** valida email opcional y obliga workerCode.

**Problemas encontrados:** `MembersService.createMember` valida duplicado por número socio y documento, pero no por `workerCode`.

**Huecos o pendientes por corregir:** falta validación de unicidad de workerCode y formato teléfono/documento.

**Prioridad de corrección:** Alta.

**Recomendación:** agregar índice lógico/validación de workerCode y test de duplicados.

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
6. Verifica duplicados por número socio.
7. Inserta en batches.
8. Guarda `import_logs` y `audit_logs`.

**Validaciones esperadas:** columnas obligatorias, email válido, duplicados, auth.

**Datos utilizados:** archivo local, `members`, `import_logs`, `audit_logs`.

**Estados posibles:** sin archivo, archivo seleccionado, procesando, éxito, éxito parcial, error.

**Observaciones técnicas o funcionales:** la UI dice que `documento` es opcional, pero `ImportService.requiredColumns` exige `documento`.

**Problemas encontrados:** inconsistencia funcional entre instrucciones y servicio; parser CSV manual no soporta comillas/comas internas; duplicados por workerCode no se validan.

**Huecos o pendientes por corregir:** falta plantilla descargable y validación previa antes de importar.

**Prioridad de corrección:** Alta.

**Recomendación:** alinear columnas obligatorias, usar parser CSV robusto y validar workerCode/documentId/memberNumber.

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
3. El sistema valida campos obligatorios.
4. Firebase Auth valida credenciales.
5. Se carga `users/{uid}`.
6. Se redirige a Home.

**Flujos alternativos:** credenciales inválidas, usuario sin documento Firestore, Firebase no inicializado, red no disponible.

**Errores posibles:** `invalid-email`, `user-not-found`, `wrong-password`, error genérico de conexión.

**Mejoras recomendadas:** validación email, pantalla de recuperación funcional, error claro si falta perfil.

### Flujo: Registro de usuario votante

1. Usuario abre Registro.
2. Completa nombre, número trabajador, email y contraseña.
3. Se crea cuenta Firebase Auth.
4. Se crea documento `users`.
5. Se asigna rol `VOTER` desde UI.

**Riesgo:** reglas actuales no restringen rol en `create`.

**Mejora:** regla `allow create` debe validar `request.resource.data.role == 'VOTER'`.

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

**Errores posibles:** columnas no encontradas, documento requerido aunque UI lo marque opcional, CSV con comillas/comas, duplicados no detectados por workerCode.

**Mejora:** alinear especificación y parser robusto.

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
| Login | Iniciar sesión | Acceso por email/password | Parcial | Funciona por diseño, falta validar email y error de perfil faltante | Alta |
| Login | Recuperar contraseña | Envía correo Firebase | Parcial | Botón puede quedar deshabilitado por falta de listener | Media |
| Registro | Crear usuario | Crea Firebase Auth y `users` | Parcial | Riesgo en reglas por rol no restringido | Alta |
| Home | Navegación por rol | Muestra módulos según rol | Parcial | Falta guard global de rutas | Alta |
| Perfil | QR personal | Genera QR desde socio | Parcial | Depende de matching heurístico con `members` | Media |
| Elecciones | Listar elecciones | Streams Firestore | Parcial | Votantes no filtran `isActive` | Alta |
| Elecciones | Crear/editar | CRUD elección | Funcional | Requiere unificar estados | Media |
| Candidatos | Agregar/editar/eliminar | Gestiona subcolección | Parcial | Eliminar candidato puede romper conteos | Alta |
| Voto | Emitir voto | Batch de voto y contadores | Riesgo crítico | Reglas pueden bloquear o permitir inconsistencias | Alta |
| Resultados | Ver conteos | Ranking en tiempo real | Parcial | Visibilidad para votantes no usa `showResultsAutomatically` | Media |
| Asistencia | Crear evento legacy | Crea `eventos` | Funcional | Modelo distinto a `attendance_events` | Alta |
| Asistencia | Scanner | QR/código/manual | Parcial | Botón manual puede quedar deshabilitado | Alta |
| Asistencia | Registro manual | Alta manual con justificación | Parcial | Selector no escala | Media |
| Asistencia | Exportar | CSV/PDF/Excel | Parcial | Excel puede ser CSV con extensión XLSX | Media |
| Asistencia | Reporte faltantes | Calcula ausentes | No funcional/parcial | Usa `attendance_events` pero se invoca desde `eventos` | Alta |
| Socios | CRUD | Crear/editar/activar/desactivar | Parcial | Falta unicidad workerCode | Alta |
| Socios | Importación masiva | CSV/Excel a `members` | Parcial | UI y servicio discrepan en documento obligatorio | Alta |
| Auditoría | `audit_logs` | Registra acciones críticas | Parcial | Sin paginación, índices pendientes | Media |
| Auditoría | `events` legacy | Historial de eventos voto | Pendiente | No se encontró uso de `logEvent` | Media |

## 7. Errores, inconsistencias y problemas encontrados

| ID | Pantalla/Módulo | Problema | Descripción | Impacto | Prioridad | Recomendación |
|---|---|---|---|---|---|---|
| E-001 | Firestore reglas / Voto | Regla de actualización parcial incorrecta | Usa `request.resource.data.keys().hasOnly` para updates de documentos con más campos. | Votos de VOTER pueden fallar con `permission-denied`. | Alta | Usar `request.resource.data.diff(resource.data).affectedKeys().hasOnly(...)`. |
| E-002 | Firestore reglas / Users | Creación de usuario sin restricción de rol | `allow create` no valida `role == 'VOTER'`. | Riesgo de escalamiento si cliente manipula payload. | Alta | Restringir campos y rol en create. |
| E-003 | Elecciones | Votantes ven elecciones inactivas | `getActiveElections` no filtra `isActive`. | Puede permitir votar en elección desactivada. | Alta | Agregar filtro `isActive`. |
| E-004 | Scanner | Botón manual deshabilitado | Usa `_evento` incompleto en vez de `_eventoReal`. | Registro manual desde scanner sin evento puede no funcionar. | Alta | Cambiar condición a `_eventoReal != null`. |
| E-005 | Reporte asistencia | Colección equivocada | Pantalla de reporte busca `attendance_events`, pero se abre desde `eventos`. | Reporte puede fallar siempre desde flujo legacy. | Alta | Unificar fuentes o adaptar reporte. |
| E-006 | Socios importación | Documento opcional vs obligatorio | UI dice `documento` opcional, servicio lo exige. | Importaciones rechazadas inesperadamente. | Alta | Alinear contrato. |
| E-007 | Socios | Falta unicidad workerCode | Create/import no validan duplicados por workerCode de forma consistente. | Sobrescrituras o socios duplicados. | Alta | Validar workerCode y usar ID consistente. |
| E-008 | Candidatos | Eliminar candidato con votos | No recalcula votos ni bloquea acción. | Resultados inconsistentes. | Alta | Bloquear eliminación si tiene votos o recalcular. |
| E-009 | Tests | Test por defecto inválido | Busca contador `0/1`. | Suite de pruebas falla. | Media | Reemplazar por smoke test real. |
| E-010 | Login | Recuperación de contraseña | Botón Enviar puede no habilitarse al escribir. | Usuario no puede solicitar reset. | Media | Listener/setState en diálogo. |
| E-011 | `events` | Historial sin escrituras | `EventService.logEvent` no se usa. | Historial de eventos vacío. | Media | Consolidar con `audit_logs`. |
| E-012 | Exportar asistencia | XLSX no real | Genera CSV bytes con extensión `.xlsx`. | Confusión o error al abrir archivo. | Media | Generar XLSX real o exportar como CSV. |
| E-013 | CSV import | Parser manual | No soporta comillas/comas internas. | Datos corruptos en importaciones reales. | Media | Usar paquete CSV robusto. |
| E-014 | Permisos UI | Rutas sin guard | Módulos ocultos en Home, pero rutas pueden abrirse. | UX confusa y errores Firestore. | Alta | Implementar guard por rol. |
| E-015 | Performance | Lecturas completas | Members/personas/asistencias se cargan completos en varias pantallas. | Rendimiento bajo en padrones grandes. | Media | Paginación, filtros, índices. |

### Clasificación por tipo

- Errores funcionales: E-001, E-003, E-004, E-005, E-008, E-009, E-010.
- Errores visuales/UX: E-012, mensajes extensos en perfil/importación, falta de filtros.
- Errores de navegación: E-014.
- Errores de validación: E-002, E-006, E-007, E-013.
- Errores de permisos: E-001, E-002, E-014.
- Errores de rendimiento: E-015.
- Errores de contenido: instrucciones contradictorias en importación.

## 8. Huecos funcionales pendientes por corregir

| ID | Hueco detectado | Módulo relacionado | Riesgo | Recomendación | Prioridad |
|---|---|---|---|---|---|
| H-001 | No hay guard central de rutas por rol | Navegación | Acceso a pantallas no autorizadas por URL/ruta | Crear widget `RoleGuard` | Alta |
| H-002 | No hay pruebas reales de login/voto/asistencia | QA | Regresiones no detectadas | Crear tests de widgets y servicios con mocks/emulator | Alta |
| H-003 | No hay Firebase Emulator tests para reglas | Seguridad | Reglas rotas en producción | Agregar suite de reglas | Alta |
| H-004 | Dos modelos de asistencia coexistiendo | Asistencia | Reportes y elegibilidad inconsistentes | Migración o adaptador único | Alta |
| H-005 | No hay paginación | Socios/asistencia/auditoría | Lentitud con muchos datos | Implementar paginación | Media |
| H-006 | No hay confirmación para algunas acciones sensibles | Exportaciones/estado | Acciones accidentales | Revisar UX de confirmaciones | Baja |
| H-007 | No hay búsqueda avanzada en registro manual | Asistencia | Difícil operar con muchos socios | Selector searchable | Media |
| H-008 | Falta accesibilidad formal | UI | Dificultad para usuarios con lectores | Semántica, labels, contrastes, tamaños | Media |
| H-009 | Falta responsive verificado | Multiplataforma | Layouts pueden romperse | Pruebas visuales Web/Windows/mobile | Media |
| H-010 | Falta trazabilidad homogénea | Auditoría | Logs duplicados/incompletos | Unificar `events` y `audit_logs` | Media |
| H-011 | Falta recuperación de usuario sin perfil | Auth | Sesión válida sin datos funcionales | Flujo de reparación/admin | Media |
| H-012 | Falta control de visibilidad de resultados | Votación | Resultados visibles antes de tiempo | Usar `showResultsAutomatically` | Media |

## 9. Recomendaciones de mejora

| Área | Problema detectado | Solución sugerida | Beneficio esperado | Prioridad |
|---|---|---|---|---|
| Seguridad | Reglas de voto y usuarios débiles | Reescribir reglas con `diff`, validar campos permitidos y roles | Voto funcional y menor riesgo de manipulación | Alta |
| Arquitectura | Asistencia legacy vs nueva | Definir una fuente canónica o adaptador | Menos errores en reportes/elegibilidad | Alta |
| QA | Test por defecto falla | Reemplazar por pruebas reales de autenticación, home, rutas y formularios | Suite útil y confiable | Alta |
| UX | Rutas administrativas no guardadas | Guard por rol con pantalla "sin permisos" | Experiencia clara y segura | Alta |
| Datos | WorkerCode no único | Índice funcional y validación antes de crear/importar | Evita duplicidad crítica | Alta |
| Rendimiento | Lecturas completas | Paginación, filtros Firestore, cache | Mejor desempeño con padrones grandes | Media |
| Importación | CSV manual e instrucciones inconsistentes | Parser robusto, plantilla y prevalidación | Menos errores operativos | Alta |
| Auditoría | Dos colecciones de auditoría | Consolidar o documentar responsabilidades | Trazabilidad completa | Media |
| Accesibilidad | No verificada | Agregar labels, contraste, navegación teclado | Cumplimiento y usabilidad | Media |
| Documentación | Falta matriz rol-permiso vigente | Documentar roles vs pantallas vs reglas | Mejor alineación producto/desarrollo | Alta |

## 10. Checklist técnico-funcional

| Ítem | Estado | Observación |
|---|---|---|
| Login funcional | Parcial | Flujo implementado, falta validación email y reset presenta riesgo. |
| Registro funcional | Parcial | Implementado, reglas deben restringir rol. |
| Validaciones de formularios | Parcial | Hay obligatorios, faltan formatos/unicidad en varios módulos. |
| Manejo de errores | Parcial | Hay mensajes, pero algunos son genéricos o solo `debugPrint`. |
| Responsive design | Pendiente | No se verificó visualmente; algunos layouts tienen adaptaciones. |
| Roles y permisos | Parcial | UI oculta módulos; faltan guards y reglas tienen hallazgos. |
| Seguridad básica | Parcial | Firebase Auth y reglas existen; requieren correcciones críticas. |
| Estados de carga | Completo/parcial | Existen en la mayoría de pantallas. |
| Estados vacíos | Completo/parcial | Implementados en listados principales. |
| Mensajes al usuario | Parcial | Presentes, pero algunos son excesivos o inconsistentes. |
| Navegación consistente | Parcial | Rutas nombradas claras; falta protección y adaptación operador. |
| Auditoría | Parcial | `audit_logs` activo; `events` legacy no conectado. |
| Exportaciones | Parcial | CSV/PDF; Excel requiere revisión de formato real. |
| Pruebas automatizadas | Pendiente | Test actual falla y no cubre app real. |
| Análisis estático | Parcial | 115 issues en `flutter analyze --no-pub`. |

## 11. Casos de prueba sugeridos

| ID | Caso de prueba | Pasos | Resultado esperado | Prioridad |
|---|---|---|---|---|
| TC-001 | Login exitoso | Ingresar email/password válidos | Redirige a Home y muestra rol | Alta |
| TC-002 | Login inválido | Ingresar credenciales erróneas | Muestra error claro | Alta |
| TC-003 | Recuperar contraseña | Abrir diálogo, escribir email, enviar | Botón se habilita y muestra éxito/error | Media |
| TC-004 | Registro votante | Completar registro válido | Crea usuario con rol VOTER | Alta |
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
| TC-016 | Crear evento asistencia | Operador/admin crea evento | Evento aparece en dashboard | Alta |
| TC-017 | Scanner sin evento inicial | Abrir scanner desde dashboard, seleccionar evento, ingresar código | Botón registrar se habilita y guarda | Alta |
| TC-018 | Scanner QR duplicado | Escanear mismo QR dos veces | Segundo intento informa duplicado | Alta |
| TC-019 | Registro manual existente | Seleccionar socio, guardar asistencia | Crea registro con justificación | Alta |
| TC-020 | Registro manual nueva persona duplicada | Crear persona con identificador existente | Bloquea y muestra error | Alta |
| TC-021 | Reporte desde evento legacy | Abrir reporte desde detalle `eventos` | Debe cargar datos o mostrar error controlado | Alta |
| TC-022 | Importar socios CSV válido | Cargar plantilla válida | Importa filas y muestra resumen | Alta |
| TC-023 | Importar socios sin documento | Usar archivo sin documento si UI dice opcional | Comportamiento alineado con especificación | Alta |
| TC-024 | WorkerCode duplicado | Importar dos filas mismo workerCode | Bloquea duplicado | Alta |
| TC-025 | Exportar asistencia PDF | Generar PDF con datos | Archivo se comparte sin error | Media |
| TC-026 | Exportar Excel | Generar Excel | Archivo abre correctamente como XLSX o CSV declarado | Media |
| TC-027 | Auditoría create/update | Crear socio/elección | `audit_logs` registra acción | Media |
| TC-028 | Filtros auditoría | Aplicar filtros combinados | Lista correcta o índice documentado | Media |
| TC-029 | Responsive mobile | Probar pantallas principales en ancho pequeño | Sin overflow ni botones cortados | Media |
| TC-030 | Accesibilidad básica | Navegar con lector/teclado | Controles identificables | Baja |

## 12. Conclusión general

La aplicación tiene una base funcional amplia y una arquitectura entendible por módulos. Están implementados los flujos principales de autenticación, votación, asistencia, socios, QR, exportaciones y auditoría. Sin embargo, el estado actual debe considerarse MVP avanzado en desarrollo, no listo para producción sin correcciones.

El mayor riesgo está en la seguridad y consistencia del flujo de votación: las reglas Firestore actuales para incrementos de contadores probablemente no expresan correctamente una actualización parcial segura. Además, la aplicación mezcla dos modelos de asistencia (`eventos/personas/asistencias` y `attendance_events`), lo que afecta reportes y elegibilidad.

La completitud funcional estimada es alta en cobertura de pantallas, pero media en robustez productiva. El nivel de completitud global estimado es 70-75%, condicionado por correcciones críticas, pruebas automatizadas y validación con Firebase real/emulator.

Prioridades antes de entrega o producción:

1. Corregir reglas Firestore de votos y creación de usuarios.
2. Crear tests reales y eliminar el test de contador por defecto.
3. Unificar o adaptar el modelo de asistencia.
4. Proteger rutas por rol.
5. Corregir scanner manual sin evento.
6. Alinear importación de socios y unicidad de `workerCode`.
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
| Detalle evento | `/asistencia/evento_detail` |
| Registro manual | `/asistencia/registro_manual` |
| Scanner | `/asistencia/scanner` |
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
| `events` | Historial legacy de eventos de voto |
| `import_logs` | Resultado de importaciones |

### C. Modelos principales

| Modelo | Archivo | Campos clave |
|---|---|---|
| `AppUser` | `lib/core/models/user.dart` | id, email, displayName, role, employeeNumber |
| `Election` | `lib/core/models/election.dart` | title, dates, isActive, isVisibleToVoters, requireAttendance, totalVotes |
| `Candidate` | `lib/core/models/candidate.dart` | electionId, name, order, voteCount |
| `Member` | `lib/core/models/member.dart` | memberNumber, firstName, lastName, workerCode, documentId, status |
| `EventoAsistencia` | `lib/core/models/asistencia/evento.dart` | nombre, fecha, tipoReunion, modalidad |
| `PersonaAsistencia` | `lib/core/models/asistencia/persona.dart` | nombres, apellidos, identificador, codigoQR |
| `AsistenciaRegistro` | `lib/core/models/asistencia/asistencia.dart` | eventoId, personaId, metodoRegistro, justificacion, asistio |
| `AuditLog` | `lib/core/models/audit_log.dart` | action, entityType, entityId, userId, timestamp |
| `VotoEvent` | `lib/core/models/voto_event.dart` | type, entityType, result, timestamp |
| `ImportLog` | `lib/core/models/import_log.dart` | fileName, totalRows, successfulImports, errors, duplicates |

### D. Resultados de análisis estático

`flutter analyze --no-pub` encontró 115 issues. Los más relevantes para gestión técnica:

- Warnings por imports no usados en pantallas de asistencia/QR/main.
- Campo no usado `_accentColor`.
- Elementos no usados como `_buildEjemploColumna`.
- Uso de APIs deprecadas: `value` en `DropdownButtonFormField`, `WillPopScope`, `withOpacity`.
- Riesgo `use_build_context_synchronously` en `qr_codes_screen.dart`.
- Casts y operadores innecesarios.
- Scripts con `print` e imports relativos a `lib`.

### E. Resultados de pruebas

`flutter test --no-pub --reporter expanded` falla en `test/widget_test.dart`:

- Caso: `Counter increments smoke test`.
- Motivo: espera encontrar texto `0`, pero la aplicación real no es contador.
- Acción recomendada: reemplazar por smoke test real que inicialice la app con mocks o use Firebase emulator.

### F. Supuestos utilizados

- El nombre funcional se tomó de `MaterialApp.title`, README y `pubspec.yaml`.
- El alcance de usuario se infiere del dominio sindical y roles en código.
- No se asume existencia de datos en Firestore.
- No se asume que reglas locales estén desplegadas en Firebase.
- Cuando el comportamiento depende de datos reales, se marca como pendiente de confirmar.
