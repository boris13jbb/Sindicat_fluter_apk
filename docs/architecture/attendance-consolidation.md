# Consolidación de asistencia, eventos y personas (Fase 4)

Documento de arquitectura tras la auditoría y consolidación parcial del dominio de asistencia en **VotaSind**.

## Antes

El sistema operaba con **dos stacks Firestore en paralelo**:

| Stack | Colecciones | Servicio principal | UI |
|-------|-------------|-------------------|-----|
| **Moderno** | `attendance_events` + subcolección `asistencias` | `AttendanceService` | Crear evento, detalle operativo, scanner con `attendanceEventId` |
| **Legacy** | `eventos`, `personas`, `asistencias` (raíz) + `eventos/{id}/asistencias` | `AsistenciaService` | Históricos, import CSV personas, export combinado, elecciones antiguas |

Además:

- Modelos operativos (`AttendanceEvent`, `MemberAttendanceSummary`, `AttendanceReport`) vivían dentro de `attendance_service.dart`.
- Varias pantallas consultaban Firestore directamente (`attendance_events`, `personas`).
- Existía pantalla huérfana `crear_evento_screen.dart` (sin ruta ni imports).
- `watchAndSyncMembers()` en `AsistenciaService` no tenía consumidores.

### Relación users / members / personas

```text
Firebase Auth
      ↓
users/{uid}          ← roles, memberId opcional
      ↓ memberId
members/{id}         ← padrón sindical (canónico)
      ↓ sync opcional
personas/{id}        ← réplica legacy para Android/QR antiguo
```

## Problemas

| Categoría | Detalle |
|-----------|---------|
| **Duplicación** | Dos servicios con CRUD de eventos/asistencias; lógica de merge members+personas repetida en 3 pantallas |
| **Datos** | Misma asistencia puede existir en subcolección moderna o en `asistencias` raíz legacy |
| **Arquitectura** | Modelos de dominio mezclados con capa de servicio; UI con acceso directo a Firestore |
| **Seguridad** | Fase 1.2 endureció `members`/`users`; legacy `personas`/`eventos` mantienen reglas operador — no debilitadas |
| **Performance** | Lecturas `.get()` completas de `personas` en listados (mitigado centralizando en servicio) |
| **Código muerto** | `crear_evento_screen.dart`, `watchAndSyncMembers()` |

## Después

### Source of truth

| Entidad | Fuente oficial | Notas |
|---------|----------------|-------|
| **Usuario (auth)** | `users/{uid}` | Roles, `memberId`, `employeeNumber`; no mover roles a `members` |
| **Miembro / padrón** | `members/{id}` | Convocatorias, reportes, registro moderno (`personaId` = `members.id`) |
| **Persona legacy** | `personas/{id}` | Solo compatibilidad; lectura vía `AsistenciaService.fetchAllLegacyPersonas()` |
| **Evento operativo** | `attendance_events/{id}` | Flujo canónico para eventos nuevos |
| **Evento legacy** | `eventos/{id}` | Solo históricos y vínculos con elecciones antiguas |
| **Asistencia moderna** | `attendance_events/{eventId}/asistencias/{id}` | ID determinístico por evento+socio |
| **Asistencia legacy** | `asistencias/{id}` + réplica en subcolección | Dual-write en `AsistenciaService.createAsistencia` |

### Servicios

| Servicio | Responsabilidad |
|----------|-----------------|
| **`AttendanceService`** | Eventos operativos, registro moderno, reportes, resúmenes por socio (merge legacy+moderno), `watchEventById` |
| **`AsistenciaService`** | Puente legacy: eventos/personas/asistencias antiguas, export PDF/Excel, sync `members→personas`, delegación a `AttendanceService` en escaneo moderno |
| **`MembersService`** | CRUD padrón `members` |
| **`MemberLookupService`** | Búsqueda segura vía Cloud Functions (Fase 1.2) |

### Modelos (ubicación canónica)

| Modelo | Archivo |
|--------|---------|
| `AttendanceEvent` | `lib/core/models/asistencia/attendance_event.dart` |
| `MemberAttendanceSummary`, `AsistenciaDetalle` | `lib/core/models/asistencia/member_attendance_summary.dart` |
| `AttendanceReport`, `AttendanceHubDashboardData` | `lib/core/models/asistencia/attendance_report_models.dart` |
| `EventoAsistencia`, `PersonaAsistencia`, `AsistenciaRegistro` | `lib/core/models/asistencia/` (existentes) |

## Compatibilidad legacy (temporal)

Se mantiene **Fase A — compatibilidad dual**:

1. `AsistenciaService.registrarAsistenciaDesdeEscaneo` escribe en moderno si hay `attendanceEventId`.
2. `AttendanceService.watchMemberAttendanceSummary` agrega eventos legacy y modernos.
3. Exportación y pestaña **Históricos** siguen leyendo `eventos`.
4. `sincronizarMiembrosConPersonas()` conserva réplica `personas` para datos antiguos.

**No se ejecutó migración de datos en producción.**

## Código eliminado

- `lib/features/asistencia/crear_evento_screen.dart` — sin referencias; ruta `/asistencia/crear_evento` ya apuntaba a `CrearAttendanceEventScreen`.
- `AsistenciaService.watchAndSyncMembers()` — sin consumidores.

## Código legacy conservado (y por qué)

| Elemento | Motivo |
|----------|--------|
| `AsistenciaService` completo | Datos históricos en `eventos`/`asistencias`/`personas` |
| `evento_detail_screen.dart` | Detalle de eventos legacy |
| `importar_personas_screen.dart` | Importación CSV a `personas` (hasta migración de datos) |
| Dual-write `createAsistencia` | Compatibilidad Android y registros existentes |
| `election_service` consultas legacy | Elegibilidad por asistencia en elecciones antiguas |

## Migraciones pendientes (NO ejecutadas)

1. **Script idempotente** para copiar `eventos` → `attendance_events` donde aplique (solo lectura previa + dry-run).
2. **Normalizar** `asistencias` raíz hacia subcolecciones modernas con mapeo `personas.id` → `members.id`.
3. **Retirar** colección `personas` cuando no queden referencias en producción.
4. **Backfill** `users.memberId` para cuentas históricas (ver `docs/security-members.md`).

## Reglas de desarrollo

- Nuevos eventos → siempre `attendance_events` vía `AttendanceService`.
- UI no debe usar `FirebaseFirestore.instance` directamente; usar servicios.
- No debilitar reglas `members`/`users` de Fase 1.2.
- Cambios en colecciones de asistencia → actualizar `firebase_rules_test/`.

## Referencias

- `lib/services/attendance_service.dart` — servicio operativo
- `lib/services/asistencia_service.dart` — puente legacy
- `docs/security-members.md` — seguridad padrón
- `AGENTS.md` — convenciones del proyecto
