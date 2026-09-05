# Legacy `asistenciaCount` backfill (futuro)

**Estado:** documentado · **NO ejecutado** · sin escrituras a producción en este gate.

## Problema

Eventos `attendance_events/{id}` creados antes del contador pueden carecer de
`asistenciaCount` aunque tengan (o no) documentos en `asistencias/`.

Las Rules y Cloud Functions tratan el campo ausente como **fail-closed**
(no equivalente a 0). Hasta el backfill:

- edición histórica: DENIED
- sync Secure QR: `legacy-count-missing`
- registro manual cliente: `AttendanceLegacyCountException`
- delete: permitido solo si la subcolección está realmente vacía

## Backfill propuesto (fase futura autorizada)

1. Script **dry-run por defecto** (sin `--apply` no escribe).
2. Por cada evento sin `asistenciaCount` (o tipo inválido):
   - contar docs en `asistencias/`
   - reportar `eventId`, `proposedCount`, `hasSubdocs`
3. Con `--apply` (solo tras revisión humana + entorno autorizado):
   - `update({ asistenciaCount: N })` vía Admin SDK
4. Nunca bajar un count existente.
5. Nunca ejecutarse desde CI sin flag explícito ni contra producción sin
   autorización separada.

## Relación con release

Este documento no autoriza deploy de Rules/Functions ni backfill productivo.
