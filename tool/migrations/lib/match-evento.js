'use strict';

const { TRACE_FIELDS } = require('./constants');
const { normalizeId } = require('./normalize');

/**
 * @param {{id: string, data: Record<string, unknown>}} evento
 * @param {Map<string, {id: string, data: Record<string, unknown>}>} modernById
 * @param {Map<string, string>} modernByLegacyId
 */
function classifyEvento(evento, modernById, modernByLegacyId) {
  const { id, data } = evento;
  const nombre = normalizeId(data.nombre);
  const fecha = Number(data.fecha ?? 0);

  if (!id || !nombre || !fecha) {
    return { status: 'INVALIDO', targetEventId: null, reason: 'missing id, nombre or fecha' };
  }

  if (modernById.has(id)) {
    const modern = modernById.get(id);
    if (hasLegacyTrace(modern.data, id)) {
      return { status: 'EXISTE_EQUIVALENTE', targetEventId: id, reason: 'same id with legacy trace' };
    }
    return { status: 'AMBIGUO', targetEventId: id, reason: 'attendance_events doc exists with same id but no trace' };
  }

  const traced = modernByLegacyId.get(id);
  if (traced) {
    return { status: 'EXISTE_EQUIVALENTE', targetEventId: traced, reason: 'legacyDocumentId trace' };
  }

  return { status: 'REQUIERE_MIGRACION', targetEventId: id, reason: 'preserve legacy evento id' };
}

/**
 * @param {Record<string, unknown>} data
 * @param {string} legacyId
 */
function hasLegacyTrace(data, legacyId) {
  const source = normalizeId(data[TRACE_FIELDS.legacySource]);
  const legacyDoc = normalizeId(data[TRACE_FIELDS.legacyDocumentId]);
  return (
    source === 'eventos' &&
    (legacyDoc === legacyId || legacyDoc === '')
  ) || data[TRACE_FIELDS.migrationVersion];
}

/**
 * Índice de eventos modernos por legacyDocumentId.
 * @param {Array<{id: string, data: Record<string, unknown>}>} modernEvents
 */
function buildModernEventIndexes(modernEvents) {
  const byId = new Map();
  const byLegacyId = new Map();

  for (const ev of modernEvents) {
    byId.set(ev.id, ev);
    const legacyDoc = normalizeId(ev.data[TRACE_FIELDS.legacyDocumentId]);
    if (legacyDoc) {
      byLegacyId.set(legacyDoc, ev.id);
    }
  }

  return { byId, byLegacyId };
}

module.exports = { classifyEvento, buildModernEventIndexes, hasLegacyTrace };
