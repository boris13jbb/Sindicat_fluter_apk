'use strict';

const { buildMemberIndexes } = require('./indexes');
const { matchPersonaToMember } = require('./match-persona');
const { analyzeUserMemberLink } = require('./match-user');
const { buildModernEventIndexes, classifyEvento } = require('./match-evento');
const { buildModernAttendanceKeySet, classifyAsistencia } = require('./match-asistencia');

/**
 * Ejecuta inventario + clasificación sobre snapshots en memoria.
 * @param {{
 *   personas: Array<{id: string, data: Record<string, unknown>}>,
 *   eventos: Array<{id: string, data: Record<string, unknown>}>,
 *   asistencias: Array<{id: string, data: Record<string, unknown>}>,
 *   members: Array<{id: string, data: Record<string, unknown>}>,
 *   users: Array<{id: string, data: Record<string, unknown>}>,
 *   attendanceEvents: Array<{id: string, data: Record<string, unknown>}>,
 *   modernAttendances: Array<{id: string, eventId: string, data: Record<string, unknown>}>,
 * }} snapshots
 */
function analyzeInventory(snapshots) {
  const memberIndexes = buildMemberIndexes(snapshots.members);
  const { byId: modernById, byLegacyId: modernByLegacyId } = buildModernEventIndexes(
    snapshots.attendanceEvents,
  );

  const personaResults = snapshots.personas.map((p) => ({
    personaId: p.id,
    ...matchPersonaToMember(p, memberIndexes),
  }));

  const personaMemberMap = new Map(
    personaResults.map((r) => [r.personaId, { status: r.status, memberIds: r.memberIds }]),
  );

  const userResults = snapshots.users.map((u) => ({
    userId: u.id,
    ...analyzeUserMemberLink(u, memberIndexes),
  }));

  const eventoResults = snapshots.eventos.map((e) => ({
    eventoId: e.id,
    ...classifyEvento(e, modernById, modernByLegacyId),
  }));

  const eventoMap = new Map(
    eventoResults.map((r) => [r.eventoId, { status: r.status, targetEventId: r.targetEventId }]),
  );

  const eventoExists = new Set(snapshots.eventos.map((e) => e.id));
  const personaExists = new Set(snapshots.personas.map((p) => p.id));
  const modernAttendanceKeys = buildModernAttendanceKeySet(snapshots.modernAttendances);

  const asistenciaResults = snapshots.asistencias.map((a) => ({
    asistenciaId: a.id,
    ...classifyAsistencia(a, {
      eventoMap,
      personaMemberMap,
      modernAttendanceKeys,
      eventoExists,
      personaExists,
    }),
  }));

  return {
    personaResults,
    userResults,
    eventoResults,
    asistenciaResults,
    counts: {
      personas: snapshots.personas.length,
      users: snapshots.users.length,
      members: snapshots.members.length,
      eventos: snapshots.eventos.length,
      attendanceEvents: snapshots.attendanceEvents.length,
      asistenciasLegacy: snapshots.asistencias.length,
      modernAttendances: snapshots.modernAttendances.length,
    },
  };
}

/**
 * @param {ReturnType<analyzeInventory>} analysis
 */
function summarizeMetrics(analysis) {
  const persona = countBy(analysis.personaResults, 'status', {
    MATCH_EXACT: 'matchExacto',
    NO_MATCH: 'sinMatch',
    MATCH_MULTIPLE: 'ambiguos',
    INVALID: 'invalidos',
    ALREADY_MIGRATED: 'yaMigrados',
  });

  const users = {
    total: analysis.userResults.length,
    conMemberId: analysis.userResults.filter((u) => u.status === 'HAS_MEMBER_ID').length,
    sinMemberId: analysis.userResults.filter((u) => u.status !== 'HAS_MEMBER_ID').length,
    matchPosible: analysis.userResults.filter((u) => u.status === 'MATCH_POSSIBLE').length,
    requiereRevision: analysis.userResults.filter((u) => u.status === 'REQUIRES_REVIEW').length,
  };

  const eventos = countBy(analysis.eventoResults, 'status', {
    EXISTE_EQUIVALENTE: 'yaExistentesModernos',
    REQUIERE_MIGRACION: 'migrables',
    AMBIGUO: 'ambiguos',
    INVALIDO: 'invalidos',
  });

  const asistencias = countBy(analysis.asistenciaResults, 'action', {
    MIGRABLE: 'migrables',
    ALREADY_MIGRATED: 'yaExistentes',
    INVALID: 'invalidas',
    CONFLICT: 'conflictivas',
  });

  const duplicates = countBy(analysis.asistenciaResults, 'duplicate', {
    EXACT_DUPLICATE: 'duplicadasExactas',
    PROBABLE_DUPLICATE: 'duplicadasProbables',
    ORPHAN: 'huerfanas',
  });

  return {
    personas: { total: analysis.personaResults.length, ...persona },
    users,
    eventos: { total: analysis.eventoResults.length, ...eventos },
    asistencias: { total: analysis.asistenciaResults.length, ...asistencias, ...duplicates },
  };
}

/**
 * @param {Array<Record<string, unknown>>} rows
 * @param {string} field
 * @param {Record<string, string>} keyMap
 */
function countBy(rows, field, keyMap) {
  /** @type {Record<string, number>} */
  const out = {};
  for (const label of Object.values(keyMap)) {
    out[label] = 0;
  }
  for (const row of rows) {
    const raw = row[field];
    const label = keyMap[String(raw)];
    if (label) out[label] += 1;
  }
  return out;
}

module.exports = { analyzeInventory, summarizeMetrics };
