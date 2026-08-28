# Fase 4.1B — Inventario read-only de Firestore producción

**Checkpoint previo:** `v1.4.3-readonly-tooling` (`7e5fadd`)
**Proyecto Firebase:** `sistema-integrado-sindicato`  
**Versión análisis:** `production-readonly-v1`

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

```bash
gcloud firestore export gs://<BUCKET>/backups/pre-legacy-migration-YYYYMMDD \
  --project=sistema-integrado-sindicato \
  --collection-ids=personas,eventos,asistencias,members,users,attendance_events
```

**Estado actual:** backup debe verificarse manualmente antes de 4.1C. Sin backup verificado → **4.1C BLOQUEADA**.

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
