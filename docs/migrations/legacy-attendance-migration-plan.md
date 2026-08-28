# Plan de migración legacy — asistencia (Fase 4.1A / 4.1B)

Documento operativo para migrar datos legacy de asistencia sin romper producción.

**Versión de migración:** `legacy-attendance-v1`  
**Checkpoint previo:** tag Git `v1.4-attendance-consolidated` (`334dee0`)

---

## 1. Qué se migrará (futuro 4.1B)

| Origen legacy | Destino moderno | Estrategia |
|---------------|-----------------|------------|
| `eventos/{id}` | `attendance_events/{id}` | Copia con **mismo ID** si no hay conflicto; campos trazabilidad |
| `asistencias/{id}` (raíz) | `attendance_events/{eventId}/asistencias/{safeDocSegment(memberId)}` | Copia transformada; `personaId` → `members.id` |
| `eventos/{id}/asistencias/{id}` | (réplica) | No migrar por separado si raíz ya migrada |
| `personas/{id}` | **No migrar colección** | Resolver vínculo a `members` existente |
| `users/{uid}` sin `memberId` | `users/{uid}.memberId` | Backfill solo con match seguro |

## 2. Qué NO se migrará automáticamente

- Registros con `MATCH_MULTIPLE` persona→member.
- Usuarios con `REQUIRES_REVIEW`.
- Eventos `AMBIGUO` (mismo ID moderno sin trazabilidad).
- Asistencias `ORPHAN` / `CONFLICT`.
- Cualquier match basado en **nombre** (prohibido).

## 3. Source of truth (post-migración objetivo)

| Entidad | Fuente oficial |
|---------|----------------|
| Usuario | `users/{uid}` |
| Miembro | `members/{memberId}` |
| Evento | `attendance_events/{eventId}` |
| Asistencia | `attendance_events/{eventId}/asistencias/{attendanceId}` |

Legacy temporal hasta retiro controlado:

- `personas`, `eventos`, `asistencias` (raíz y subcolección réplica).

---

## 4. Matriz de inventario (campos reales del código)

| Colección | Campos relevantes | Identificador | Relaciones | Destino moderno | Riesgo |
|-----------|-------------------|---------------|------------|-----------------|--------|
| `personas` | `id`, `nombres`, `apellidos`, `identificador`, `codigoQR` | `identificador` (workerCode/documentId) | Réplica de `members` | N/A (resolver a member) | Duplicados por identificador |
| `members` | `memberNumber`, `workerCode`, `documentId`, `email`, `status`, `modalidad` | `id` | Padrón canónico | — | Baja |
| `users` | `email`, `employeeNumber`, `memberId`, `role` | Firebase Auth `uid` | Opcional `memberId` | Backfill `memberId` | Elevación de vínculos incorrectos |
| `eventos` | `nombre`, `fecha`, `fechaFin`, `tipoReunion`, `activo`, `modalidadesNoConvocadas` | `id` | `asistencias.eventoId` | `attendance_events` | IDs colisionados |
| `attendance_events` | `nombre`, `fecha`, `tipo`, `miembrosConvocados`, `modalidadesNoConvocadas` | `id` | Subcolección `asistencias` | — | Baja |
| `asistencias` (raíz) | `eventoId`, `personaId`, `fechaRegistro`, `asistio`, `metodoRegistro`, `justificacion` | ID determinístico `safe(evento)_safe(persona)` | `eventos`, `personas` | Subcolección moderna | Huérfanos, duplicados |
| `eventos/{id}/asistencias` | Réplica legacy | Mismo ID que raíz | Dual-write Android | Incluida en migración raíz | Docs huérfanos |

---

## 5. Reglas de mapeo

### Persona → Member

1. `personas.id === members.id` → `MATCH_EXACT`
2. `personas.identificador === members.workerCode` → `MATCH_EXACT`
3. `personas.identificador === members.documentId` → `MATCH_EXACT`
4. `personas.identificador === members.memberNumber` → `MATCH_EXACT`
5. Múltiples coincidencias → `MATCH_MULTIPLE` → revisión manual
6. Sin coincidencia → `NO_MATCH`
7. **Nunca** usar `nombres`/`apellidos`

### User → Member (solo reporte en 4.1A)

1. `users.memberId` presente → `HAS_MEMBER_ID`
2. `users.uid === members.id` → `MATCH_POSSIBLE`
3. `users.employeeNumber` ↔ `memberNumber`/`workerCode` → `MATCH_POSSIBLE`
4. `email` normalizado ↔ `members.email` → `MATCH_POSSIBLE`
5. Múltiples → `REQUIRES_REVIEW`

### Evento legacy → moderno

1. `attendance_events/{sameId}` con `legacySource=eventos` → `EXISTE_EQUIVALENTE`
2. `legacyDocumentId === evento.id` en doc moderno → `EXISTE_EQUIVALENTE`
3. Sin equivalente, datos válidos → `REQUIERE_MIGRACION` (conservar ID)
4. Mismo ID sin trazabilidad → `AMBIGUO`
5. Sin `nombre`/`fecha` → `INVALIDO`

### Asistencia legacy → moderna

1. Resolver `eventoId` → `targetEventId`
2. Resolver `personaId` → `memberId` (match seguro)
3. Doc destino: `safeDocSegment(memberId)` (igual que app moderna)
4. Si ya existe en subcolección → `ALREADY_MIGRATED`
5. Evento/persona inexistente → `ORPHAN` / `INVALID`

### Duplicados

Comparación conceptual: `eventoId + memberId + fechaRegistro + asistio`  
Clasificación: `UNIQUE`, `EXACT_DUPLICATE`, `PROBABLE_DUPLICATE`, `CONFLICT`

---

## 6. Trazabilidad (campos propuestos en destino)

```json
{
  "legacySource": "eventos|asistencias",
  "legacyDocumentId": "<id original>",
  "migrationVersion": "legacy-attendance-v1"
}
```

No se modifican documentos origen en la primera migración real.

---

## 7. Script de dry-run

**Ruta:** `tool/migrations/legacy_attendance_migration.js`

### Modos

| Modo | Comportamiento |
|------|----------------|
| Default / `--dry-run` | Solo lectura + reporte (0 escrituras) |
| `--use-fixtures` | Inventario sobre JSON de emulador |
| `--apply` | **Bloqueado en 4.1A**; futuro requiere `--project sistema-integrado-sindicato --confirm-migration` |

### Ejemplos

```powershell
cd D:\Sindicat_fluter_apk\tool\migrations
npm install
npm run dry-run:fixtures
```

Con emulador (solo lectura):

```powershell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
$env:GCLOUD_PROJECT = "demo-sindicat-migration"
node legacy_attendance_migration.js --dry-run
```

### Reportes

Salida en `migration-reports/` (gitignored):

- `legacy-attendance-dry-run-YYYYMMDD-HHMM.json`
- `legacy-attendance-dry-run-YYYYMMDD-HHMM-summary.csv`

---

## 8. Backup plan (antes de 4.1B — NO ejecutado aún)

### Proyecto Firebase

- **Project ID:** `sistema-integrado-sindicato`
- **Colecciones a respaldar:** `personas`, `eventos`, `asistencias`, `members`, `users`, `attendance_events` (+ subcolecciones `asistencias`)

### Opción A — Export gestionado (recomendado)

Requisitos: permisos `roles/datastore.importExportAdmin`, bucket GCS.

```bash
gcloud firestore export gs://<BUCKET>/backups/pre-legacy-migration-YYYYMMDD \
  --project=sistema-integrado-sindicato \
  --collection-ids=personas,eventos,asistencias,members,users,attendance_events
```

Verificación: listar objetos en GCS y metadata del export en consola Firebase.

Restauración (solo emergencia, entorno controlado):

```bash
gcloud firestore import gs://<BUCKET>/backups/pre-legacy-migration-YYYYMMDD \
  --project=sistema-integrado-sindicato
```

### Opción B — Export JSON por script (lectura)

Usar el mismo lector del dry-run en modo read-only y guardar snapshot cifrado fuera del repo.

### Checklist pre-migración real

- [ ] Backup exportado y verificado
- [ ] Dry-run en emulador con datos representativos
- [ ] Dry-run read-only en producción (métricas, sin escrituras)
- [ ] Ventana de mantenimiento acordada
- [ ] Plan de rollback documentado

---

## 9. Rollback

1. **No borrar origen** en primera migración → legacy sigue operativo.
2. Si se copió a moderno: eliminar solo docs con `migrationVersion=legacy-attendance-v1` (fase posterior, script dedicado).
3. Restaurar desde export GCS si corrupción masiva.

---

## 10. Validación post-migración (futuro 4.1B)

- Comparar conteos dry-run vs post-apply.
- Muestreo manual de 20 registros por categoría.
- `tool/verify.ps1` en verde.
- Smoke: hub asistencia, scanner, export, perfil socio.

---

## 11. Cuándo retirar legacy

Solo cuando:

1. Métricas dry-run sin `ORPHAN`/`CONFLICT` críticos.
2. 30 días operación estable solo con `attendance_events`.
3. Export histórico archivado.
4. App deja de escribir dual-write (fase código posterior).

---

## 12. Deuda técnica documentada (permanece)

1. `personas` como réplica de `members`
2. `eventos` legacy activos
3. `asistencias` raíz + subcolección réplica
4. Dual-write `createAsistencia`
5. Históricos en UI
6. Backfill `users.memberId`
7. Paginación lecturas legacy
8. Endurecimiento reglas legacy

Ver también: `docs/architecture/attendance-consolidation.md`

---

## 13. Fase 4.1A — estado

- [x] Inventario y mapeo definidos
- [x] Script dry-run (default seguro)
- [x] Tests (13/13) incl. 0 escrituras en dry-run
- [x] Fixtures emulador
- [x] Backup plan documentado
- [ ] Migración real (4.1B)
- [ ] Retiro legacy (fase posterior)
