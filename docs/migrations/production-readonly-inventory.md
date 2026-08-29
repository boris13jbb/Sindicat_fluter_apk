# Fase 4.1B — Inventario read-only de Firestore producción

**Checkpoint tooling:** `v1.4.4-readonly-adc` (`b596d42`)
**Checkpoint documental:** `v1.4.6-4.1c-noop`
**Checkpoint anterior:** `v1.4.5-production-inventory` (`38d777f`)
**Proyecto Firebase:** `sistema-integrado-sindicato`
**Versión análisis:** `production-readonly-v1`
**Estado 4.1B:** inventario producción ejecutado y documentado (2026-08-28) — 0 escrituras
**Estado backup pre-4.1C:** verificado en GCS (2026-08-28)
**Estado 4.1C:** **NO-OP APROBADA** (2026-08-28) — sin migración; 0 writes / 0 updates / 0 deletes

---

## Objetivo

Primera fase autorizada a **leer** Firestore producción para inventario y dry-run real, sin escrituras ni `--apply`.

```text
ADC + impersonación read-only → script dedicado → inventario → métricas → reporte → plan 4.1C
```

---

## Capas de seguridad

| Capa | Control |
|------|---------|
| 1 | ADC con impersonación de SA `roles/datastore.viewer` |
| 2 | Script separado: `production_readonly_inventory.js` |
| 3 | Proxy Firestore bloquea `set/update/delete/batch/bulkWriter/runTransaction` |
| 4 | `--apply` rechazado explícitamente |
| 5 | Gates: `--production-readonly --project sistema-integrado-sindicato --confirm-readonly-analysis` |
| 6 | Reportes sanitizados en `tool/migrations/migration-reports/` (gitignored) |

**NO usar** credenciales Owner/Editor/Firebase Admin para inventario.

**NO crear ni usar** claves JSON permanentes de service account.

---

## Autenticación (ADC + impersonación)

### Service Account requerida

```text
sindicat-migration-readonly@sistema-integrado-sindicato.iam.gserviceaccount.com
```

### Rol IAM requerido (en la SA impersonada)

```text
roles/datastore.viewer
```

### Permisos del usuario que impersona

```text
roles/iam.serviceAccountTokenCreator
```

### API requerida

```text
IAM Service Account Credentials API (iamcredentials.googleapis.com)
```

### Preparación local (Windows / gcloud)

```powershell
gcloud auth application-default login `
  --impersonate-service-account=sindicat-migration-readonly@sistema-integrado-sindicato.iam.gserviceaccount.com
```

Verificar que ADC es de tipo `impersonated_service_account` (sin imprimir secretos).

### Variables que deben estar DESACTIVADAS para inventario

```text
GOOGLE_APPLICATION_CREDENTIALS        (debe estar sin definir)
PRODUCTION_READONLY_CREDENTIALS       (no soportada)
FIRESTORE_EMULATOR_HOST               (debe estar sin definir)
```

El tooling valida localmente (sin red) que el archivo ADC contiene impersonación hacia la SA read-only esperada.

---

## Identidad de backup (SEPARADA)

El export gestionado Firestore requiere permisos distintos:

```text
roles/datastore.importExportAdmin
```

**No mezclar** la identidad de backup con la de inventario read-only.

### Procedimiento de backup (antes de 4.1C)

Export **completo** de la base `(default)` (sin `--collection-ids`):

```bash
gcloud firestore export gs://<BUCKET>/<prefijo> --database='(default)'
```

**Estado actual:** backup **ejecutado y verificado** (2026-08-28). Ver sección [Backup verificado](#backup-verificado-pre-41c-2026-08-28).

El backup ya no bloquea técnicamente 4.1C (`backupVerified=true`), pero la migración sigue **bloqueada** hasta autorización explícita del propietario (`migrationAuthorized=false`).

**NO ejecutar migración automáticamente. NO ejecutar `--apply` sin autorización explícita.**

### Runbook de backup (referencia)

1. **Identidad:** usuario o SA con `roles/datastore.importExportAdmin` (no usar la SA read-only de inventario).
2. **Bucket GCS:** crear o reutilizar bucket en el mismo proyecto; anotar URI, p. ej. `gs://sindicat-firestore-backups`.
3. **Export:**

```bash
gcloud firestore export gs://<BUCKET>/<prefijo> --database='(default)'
```

4. **Verificar:** presencia de `*.overall_export_metadata` bajo el prefijo exportado.
5. **Registrar:** fecha, URI, Operation ID y responsable antes de autorizar 4.1C.

---

## Backup verificado pre-4.1C (2026-08-28)

| Campo | Valor |
|-------|-------|
| Bucket | `gs://sistema-integrado-sindicato-firestore-backups-2026` |
| Prefijo | `pre-4-1c-20260828-224919` |
| Output URI | `gs://sistema-integrado-sindicato-firestore-backups-2026/pre-4-1c-20260828-224919` |
| Metadata | `.../pre-4-1c-20260828-224919.overall_export_metadata` |
| Operation ID | `projects/sistema-integrado-sindicato/databases/(default)/operations/ASAwYTkyODgxMWQ3YmYtYTIxOC1hY2U0LTE1YzUtZTAwMDk3OTckGnNlbmlsZXBpcAkKMxI` |
| Estado | `SUCCESSFUL` (`done: true`) |
| Inicio | `2026-08-29T03:51:30.482430Z` |
| Fin | `2026-08-29T03:52:02.502551Z` |
| Documentos exportados | 651 |
| Objetos GCS | 6 |
| `.overall_export_metadata` | Sí |
| Verificación física | Sí |

**Comando ejecutado:**

```bash
gcloud firestore export gs://sistema-integrado-sindicato-firestore-backups-2026/pre-4-1c-20260828-224919 --database='(default)'
```

**Efecto en Firestore:** 0 documentos creados, 0 actualizados, 0 eliminados. Sin import ni restore.

---

## Resultado del inventario (2026-08-28)

Primera ejecución autorizada con ADC + impersonación read-only.

### Identidad y autenticación

| Campo | Valor |
|-------|-------|
| Proyecto | `sistema-integrado-sindicato` |
| Service Account (impersonada) | `sindicat-migration-readonly@sistema-integrado-sindicato.iam.gserviceaccount.com` |
| Método | ADC + Service Account Impersonation (`applicationDefault`) |
| Rol SA | `roles/datastore.viewer` |

### Conteos por colección

| Colección | Documentos |
|-----------|------------|
| `users` | 4 |
| `members` | 273 |
| `personas` | 273 |
| `eventos` | 0 |
| `attendance_events` | 7 |
| `asistencias` (legacy raíz) | 0 |
| Asistencias modernas | 5 |
| **Total docs raíz observados** | **557** |

### Clasificación y consistencia

| Métrica | Valor |
|---------|-------|
| Personas `MATCH_EXACT` | 273 / 273 |
| Casos ambiguos | 0 |
| Casos manuales | 0 |
| Auto-migrables (plan 4.1C) | 0 |
| Fingerprint | `7b2f43e48af9365f6b616e5dd0f8bffd271b517f5f836bf5022026a6cef7071c` |
| Double-run `sameFingerprint` | `true` |
| Double-run `sameCounts` | `true` |
| `dataChangedDuringAnalysis` | `false` |

**Hallazgos:** sin `eventos`/`asistencias` legacy; producción operativa en modelo moderno; 1 usuario sin `memberId` (1 match exacto posible).

### Seguridad del inventario

```text
writesAttempted: 0
deletesAttempted: 0
--apply: NO
migración: NO
```

Reportes locales (gitignored): `tool/migrations/migration-reports/production-readonly-inventory-20260828-2113.{json,csv}`

### Puerta 4.1C — cerrada (NO-OP)

```text
backupVerified: true
migrationAuthorized: true   # autorización explícita recibida para evaluación 4.1C
migrationExecuted: false    # NO-OP: no había datos elegibles
resultado: NO-OP APROBADA
```

**La fase 4.1C NO requiere migración.** La ausencia de writes es el resultado esperado. **NO** se implementó ni desbloqueó `--apply` para esta fase.

### Cierre 4.1C — NO-OP (2026-08-28)

| Campo | Valor |
|-------|-------|
| Resultado | **NO-OP APROBADA** |
| Motivo | No existen registros legacy elegibles para migrar |
| Fingerprint inventario (4.1B) | `7b2f43e48af9365f6b616e5dd0f8bffd271b517f5f836bf5022026a6cef7071c` |
| Fingerprint precheck 4.1C | `7b2f43e48af9365f6b616e5dd0f8bffd271b517f5f836bf5022026a6cef7071c` |
| Datos cambiaron | **NO** |
| `eventos` legacy | 0 |
| `asistencias` legacy | 0 |
| Auto-migrables | 0 |
| Casos manuales | 0 |
| Conflictos | 0 |
| Huérfanos | 0 |
| Duplicados | 0 |
| Dry-run writes propuestos | 0 |
| Dry-run updates propuestos | 0 |
| Dry-run deletes propuestos | 0 |
| Writes reales | 0 |
| Updates reales | 0 |
| Deletes reales | 0 |
| `--apply` ejecutado | **NO** |
| Backup verificado | **SÍ** (`pre-4-1c-20260828-224919`) |
| Producción consistente | **SÍ** |

Reporte precheck 4.1C (gitignored): `tool/migrations/migration-reports/production-readonly-inventory-20260828-2303.{json,csv}`

### Follow-up independiente (fuera de 4.1C)

| Observación | Detalle |
|-------------|---------|
| Usuario sin `memberId` | 1 usuario con match exacto posible |
| Incluido en 4.1C | **NO** — fuera del alcance de migración legacy |
| Modificado en 4.1C | **NO** |
| Estado | **PENDIENTE PARA REVISIÓN INDEPENDIENTE** |

---

## Pre-flight obligatorio

Antes del primer inventario real:

1. ADC configurado con impersonación read-only.
2. `GOOGLE_APPLICATION_CREDENTIALS` sin definir.
3. Tests locales en verde (`npm test` en `tool/migrations`).
4. Autorización explícita para lectura de producción.

---

## Ejecución del inventario (solo tras autorización)

### Requisitos

- Node.js 20+
- `npm ci` en `tool/migrations`
- ADC impersonado configurado
- Pre-flight aprobado

### Comando

```powershell
cd D:\Sindicat_fluter_apk\tool\migrations

npm run inventory:production-readonly -- `
  --production-readonly `
  --project sistema-integrado-sindicato `
  --confirm-readonly-analysis `
  --double-run
```

**NO usar** `--credentials` ni rutas JSON.

### Salida

Reportes locales (gitignored):

```text
tool/migrations/migration-reports/production-readonly-inventory-YYYYMMDD-HHMM.json
tool/migrations/migration-reports/production-readonly-inventory-YYYYMMDD-HHMM.csv
```

---

## Qué analiza

| Colección | Métricas |
|-----------|----------|
| `users` | total, con/sin memberId, match posible, ambiguos |
| `members` | total, activos/inactivos |
| `personas` | MATCH_EXACT, MATCH_MULTIPLE, NO_MATCH, INVALID, ALREADY_MIGRATED |
| `eventos` | vs `attendance_events` |
| `asistencias` | raíz + `eventos/{id}/asistencias` (dual-write deduplicado) |
| `attendance_events/.../asistencias` | modernas existentes |

---

## Script legacy

`legacy_attendance_migration.js` **no puede** leer producción directamente. Usar `--use-fixtures` o el inventario oficial ADC.

---

## CI / GitHub Actions

El inventario de producción **NO** se ejecuta en CI. Los tests usan fixtures/mocks locales.

---

## Verificación post-ejecución

```text
writesAttempted: 0
deletesAttempted: 0
--apply: NO
```

---

## Referencias

- `tool/migrations/production_readonly_inventory.js`
- `tool/migrations/lib/credential-guard.js`
- `tool/migrations/lib/production-admin.js`
- `docs/migrations/legacy-attendance-migration-plan.md`
