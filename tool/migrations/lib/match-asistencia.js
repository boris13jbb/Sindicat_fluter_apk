'use strict';

const { legacyAsistenciaId, modernAsistenciaDocId, normalizeId } = require('./normalize');
const { TRACE_FIELDS } = require('./constants');

/**
 * @param {{id: string, data: Record<string, unknown>}} asistencia
 * @param {{
 *   eventoMap: Map<string, {status: string, targetEventId: string|null}>,
 *   personaMemberMap: Map<string, {status: string, memberIds: string[]}>,
 *   modernAttendanceKeys: Set<string>,
 *   eventoExists: Set<string>,
 *   personaExists: Set<string>,
 * }} ctx
 */
function classifyAsistencia(asistencia, ctx) {
  const { id, data } = asistencia;
  const eventoId = normalizeId(data.eventoId);
  const personaId = normalizeId(data.personaId);
  const fechaRegistro = Number(data.fechaRegistro ?? data.horaRegistro ?? 0);

  if (!eventoId || !personaId) {
    return base('INVALID', 'ORPHAN', 'missing eventoId or personaId');
  }

  if (!ctx.eventoExists.has(eventoId)) {
    return base('INVALID', 'ORPHAN', 'evento not found');
  }

  const eventoMapping = ctx.eventoMap.get(eventoId);
  const targetEventId = eventoMapping?.targetEventId ?? eventoId;

  const personaMatch = ctx.personaMemberMap.get(personaId);
  if (!personaMatch || personaMatch.status === 'NO_MATCH' || personaMatch.status === 'INVALID') {
    if (!ctx.personaExists.has(personaId)) {
      return base('INVALID', 'ORPHAN', 'persona not found');
    }
    return base('CONFLICT', 'ORPHAN', 'persona without resolvable member');
  }
  if (personaMatch.status === 'MATCH_MULTIPLE') {
    return base('CONFLICT', 'PROBABLE_DUPLICATE', 'ambiguous persona→member');
  }

  const memberId =
    personaMatch.status === 'ALREADY_MIGRATED' || personaMatch.status === 'MATCH_EXACT'
      ? personaMatch.memberIds[0]
      : null;

  if (!memberId) {
    return base('CONFLICT', 'ORPHAN', 'member not resolved');
  }

  const modernKey = `${targetEventId}/${modernAsistenciaDocId(memberId)}`;
  const legacyKey = legacyAsistenciaId(eventoId, personaId);

  if (ctx.modernAttendanceKeys.has(modernKey)) {
    return {
      action: 'ALREADY_MIGRATED',
      duplicate: 'EXACT_DUPLICATE',
      targetEventId,
      targetMemberId: memberId,
      targetDocId: modernAsistenciaDocId(memberId),
      legacyKey,
      modernKey,
      fechaRegistro,
      reason: 'modern attendance doc already exists',
    };
  }

  if (id !== legacyKey && ctx.modernAttendanceKeys.has(`${targetEventId}/${safeFromLegacyId(id)}`)) {
    return base('CONFLICT', 'CONFLICT', 'id mismatch with existing modern doc');
  }

  return {
    action: 'MIGRABLE',
    duplicate: 'UNIQUE',
    targetEventId,
    targetMemberId: memberId,
    targetDocId: modernAsistenciaDocId(memberId),
    legacyKey,
    modernKey,
    fechaRegistro,
    reason: 'ready for copy transform',
    trace: {
      [TRACE_FIELDS.legacySource]: 'asistencias',
      [TRACE_FIELDS.legacyDocumentId]: id,
    },
  };
}

function safeFromLegacyId(id) {
  return id;
}

function base(action, duplicate, reason) {
  return {
    action,
    duplicate,
    targetEventId: null,
    targetMemberId: null,
    targetDocId: null,
    legacyKey: null,
    modernKey: null,
    fechaRegistro: null,
    reason,
  };
}

/**
 * @param {Array<{id: string, data: Record<string, unknown>}>} modernAttendances
 */
function buildModernAttendanceKeySet(modernAttendances) {
  const keys = new Set();
  for (const row of modernAttendances) {
    const eventId = normalizeId(row.data.eventoId) || row.eventId;
    const personaId = normalizeId(row.data.personaId);
    if (eventId && personaId) {
      keys.add(`${eventId}/${modernAsistenciaDocId(personaId)}`);
    }
    if (row.eventId && row.id) {
      keys.add(`${row.eventId}/${row.id}`);
    }
  }
  return keys;
}

module.exports = { classifyAsistencia, buildModernAttendanceKeySet };
