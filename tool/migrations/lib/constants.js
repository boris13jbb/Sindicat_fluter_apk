/** @typedef {'MATCH_EXACT'|'MATCH_MULTIPLE'|'NO_MATCH'|'INVALID'|'ALREADY_MIGRATED'} PersonaMatchStatus */
/** @typedef {'EXISTE_EQUIVALENTE'|'REQUIERE_MIGRACION'|'AMBIGUO'|'INVALIDO'} EventoMapStatus */
/** @typedef {'UNIQUE'|'PROBABLE_DUPLICATE'|'EXACT_DUPLICATE'|'CONFLICT'} DuplicateStatus */

const MIGRATION_VERSION = 'legacy-attendance-v1';

const COLLECTIONS = {
  personas: 'personas',
  eventos: 'eventos',
  asistencias: 'asistencias',
  members: 'members',
  users: 'users',
  attendanceEvents: 'attendance_events',
};

const TRACE_FIELDS = {
  legacySource: 'legacySource',
  legacyDocumentId: 'legacyDocumentId',
  migrationVersion: 'migrationVersion',
};

module.exports = {
  MIGRATION_VERSION,
  COLLECTIONS,
  TRACE_FIELDS,
};
