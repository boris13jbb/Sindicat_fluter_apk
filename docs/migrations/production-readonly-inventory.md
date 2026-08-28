# Fase 4.1B — Inventario read-only de Firestore producción

**Checkpoint previo:** `v1.4.2-preproduction-ready` (`2014457`)  
**Proyecto Firebase:** `sistema-integrado-sindicato`  
**Versión análisis:** `production-readonly-v1`

---

## Objetivo

Primera fase autorizada a **leer** Firestore producción para inventario y dry-run real, sin escrituras ni `--apply`.

```text
Credencial read-only → script dedicado → inventario → métricas → reporte sanitizado → plan 4.1C
```

---

## Capas de seguridad

| Capa | Control |
|------|---------|
| 1 | Service account con `roles/datastore.viewer` (solo lectura) |
| 2 | Script separado: `production_readonly_inventory.js` |
| 3 | Proxy Firestore bloquea `set/update/delete/batch/bulkWriter/runTransaction` |
| 4 | `--apply` rechazado explícitamente |
| 5 | Gates: `--production-readonly --project sistema-integrado-sindicato --confirm-readonly-analysis` |
| 6 | Reportes sanitizados en `tool/migrations/migration-reports/` (gitignored) |

**NO usar** credenciales Owner/Editor/Firebase Admin para inventario.

**NO guardar** JSON de service account dentro del repositorio.

---

## Identidad read-only (inventario)

### Rol IAM requerido

```text
roles/datastore.viewer
```

Permisos efectivos: `get`, `list`, `read` sobre documentos Firestore. **Sin escritura.**

### Crear service account (decisión administrativa — GCP Console o gcloud)

1. Crear SA dedicada, p. ej. `migration-readonly-inventory@sistema-integrado-sindicato.iam.gserviceaccount.com`
2. Asignar **solo** `roles/datastore.viewer` a nivel proyecto
3. Descargar clave JSON **fuera del repositorio**, p. ej.:

```text
%USERPROFILE%\.secrets\sindicat-migration-readonly.json
```

4. Verificar que **no** tiene roles `Editor`, `Owner`, `datastore.user`, `firebase.admin`

### Variable de entorno

```powershell
$env:PRODUCTION_READONLY_CREDENTIALS = "$env:USERPROFILE\.secrets\sindicat-migration-readonly.json"
```

Alternativa estándar (misma ruta externa):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "$env:USERPROFILE\.secrets\sindicat-migration-readonly.json"
```

---

## Identidad de backup (SEPARADA)

El export gestionado Firestore requiere permisos distintos:

```text
roles/datastore.importExportAdmin
```

**No mezclar** la identidad de backup con la de inventario read-only.

### Procedimiento de backup (antes de 4.1C)

```bash
gcloud firestore export gs://<BUCKET>/backups/pre-legacy-migration-YYYYMMDD \
  --project=sistema-integrado-sindicato \
  --collection-ids=personas,eventos,asistencias,members,users,attendance_events
```

Restauración (solo emergencia, entorno controlado):

```bash
gcloud firestore import gs://<BUCKET>/backups/pre-legacy-migration-YYYYMMDD \
  --project=sistema-integrado-sindicato
```

**Estado actual:** backup debe verificarse manualmente antes de 4.1C. Sin backup verificado → **4.1C BLOQUEADA**.

---

## Ejecución del inventario

### Requisitos

- Node.js 20+
- `npm ci` en `tool/migrations`
- `FIRESTORE_EMULATOR_HOST` **desactivado**
- Credencial read-only configurada

### Comando

```powershell
cd D:\Sindicat_fluter_apk\tool\migrations

$env:PRODUCTION_READONLY_CREDENTIALS = "$env:USERPROFILE\.secrets\sindicat-migration-readonly.json"

node production_readonly_inventory.js `
  --production-readonly `
  --project sistema-integrado-sindicato `
  --confirm-readonly-analysis `
  --double-run
```

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

## CI / GitHub Actions

El inventario de producción **NO** se ejecuta en CI. Los tests usan fixtures locales.

---

## Verificación post-ejecución

Confirmar en consola:

```text
writesAttempted: 0
deletesAttempted: 0
--apply: NO
```

---

## Plan 4.1C (informativo)

Tras inventario real, el reporte incluye:

```text
autoMigrables
revisionManual
noMigrar
blockedUntilBackupVerified: true
```

**NO ejecutar migración** hasta backup verificado y aprobación explícita.

---

## Referencias

- `tool/migrations/production_readonly_inventory.js`
- `docs/migrations/legacy-attendance-migration-plan.md`
- `docs/architecture/attendance-consolidation.md`
