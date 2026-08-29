# Plan de migración legacy — asistencia (Fase 4.1A / 4.1B)

Documento operativo para migrar datos legacy de asistencia sin romper producción.

**Versión de migración:** `legacy-attendance-v1`
**Checkpoint documental:** `v1.4.6-4.1c-noop`
**Checkpoint anterior:** `v1.4.5-production-inventory` (`38d777f`)
**Checkpoint tooling:** `v1.4.4-readonly-adc` (`b596d42`)

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

## 8. Backup plan y registro verificado

### Proyecto Firebase

- **Project ID:** `sistema-integrado-sindicato`
- **Base:** `(default)` — ubicación `nam5`
- **Export:** completo (sin `--collection-ids`)

### Backup ejecutado y verificado (2026-08-28)

| Campo | Valor |
|-------|-------|
| Bucket | `gs://sistema-integrado-sindicato-firestore-backups-2026` |
| Prefijo | `pre-4-1c-20260828-224919` |
| Output URI | `gs://sistema-integrado-sindicato-firestore-backups-2026/pre-4-1c-20260828-224919` |
| Metadata | `.../pre-4-1c-20260828-224919.overall_export_metadata` |
| Operation ID | `projects/sistema-integrado-sindicato/databases/(default)/operations/ASAwYTkyODgxMWQ3YmYtYTIxOC1hY2U0LTE1YzUtZTAwMDk3OTckGnNlbmlsZXBpcAkKMxI` |
| Estado | `SUCCESSFUL` |
| Documentos exportados | 651 |
| Objetos GCS | 6 |
| Firestore modificado durante export | 0 (sin import/restore) |

```bash
gcloud firestore export gs://sistema-integrado-sindicato-firestore-backups-2026/pre-4-1c-20260828-224919 --database='(default)'
```

Restauración (solo emergencia, entorno controlado — **no autorizada en 4.1B/4.1C sin aprobación explícita**):

```bash
gcloud firestore import gs://sistema-integrado-sindicato-firestore-backups-2026/pre-4-1c-20260828-224919 \
  --project=sistema-integrado-sindicato
```

### Checklist pre-migración real

- [x] Backup exportado y verificado (2026-08-28, GCS, metadata confirmado)
- [x] Dry-run en emulador con datos representativos
- [x] Dry-run read-only en producción (métricas, sin escrituras) — 2026-08-28, 0 escrituras
- [ ] Ventana de mantenimiento acordada
- [x] Plan de rollback documentado

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

## 13. Estado por fase

### 4.1A — completada

- [x] Inventario y mapeo definidos
- [x] Script dry-run (default seguro)
- [x] Tests locales en verde (dry-run, 0 escrituras)
- [x] Fixtures emulador
- [x] Backup plan documentado
- [x] CI Gate con Migration Tests (4.1B-0)

### 4.1B — completada (inventario producción)

- [x] Tooling ADC + impersonación (`v1.4.4-readonly-adc`)
- [x] Inventario read-only producción (2026-08-28): 557 docs raíz, 0 escrituras
- [x] Identidad: `sindicat-migration-readonly@sistema-integrado-sindicato.iam.gserviceaccount.com`
- [x] Fingerprint estable (`--double-run`: `sameFingerprint=true`, `dataChangedDuringAnalysis=false`)
- [x] Hallazgo: sin `eventos`/`asistencias` legacy; modelo moderno activo

Detalle: `docs/migrations/production-readonly-inventory.md`

### 4.1C — completada (NO-OP)

| Campo | Valor |
|-------|-------|
| Resultado | **NO-OP APROBADA** (2026-08-28) |
| Motivo | No existen registros legacy elegibles (`eventos`=0, `asistencias` legacy=0) |
| Fingerprint estable | Sí — idéntico al inventario 4.1B |
| Auto-migrables | 0 |
| Casos manuales / conflictos / huérfanos / duplicados | 0 |
| Dry-run propuesto | 0 writes, 0 updates, 0 deletes |
| Migración real | **NO ejecutada** |
| `--apply` | **NO ejecutado** |
| Writes / updates / deletes reales | 0 / 0 / 0 |
| Backup pre-4.1C | Verificado (`pre-4-1c-20260828-224919`) |
| Producción | Consistente |

**La fase 4.1C NO requiere migración.** La ausencia de writes es el resultado esperado. **NO** se implementó ni desbloqueó `--apply` únicamente para cerrar esta fase.

- [x] Backup Firestore exportado y verificado en GCS
- [x] Autorización explícita para evaluación 4.1C
- [x] Precheck read-only + dry-run contra producción (0 operaciones propuestas)
- [x] Cierre documental sin migración real

Detalle: `docs/migrations/production-readonly-inventory.md` (sección *Cierre 4.1C — NO-OP*)

### Follow-up independiente (fuera de 4.1C)

| Observación | Estado |
|-------------|--------|
| 1 usuario sin `memberId` con match exacto posible | **PENDIENTE PARA REVISIÓN INDEPENDIENTE** |
| Incluido en alcance 4.1C | **NO** |
| Modificado en 4.1C | **NO** |

### Fases posteriores

- [ ] Retiro legacy (tras estabilidad operativa)
- [ ] Revisión independiente backfill `users.memberId` (si procede)
