'use strict';

const { TRACE_FIELDS } = require('./constants');
const { normalizeId } = require('./normalize');
const { lookupIndex, uniqueMembers } = require('./indexes');

/**
 * Matching persona → member (sin usar nombre).
 * @param {{id: string, data: Record<string, unknown>}} persona
 * @param {ReturnType<import('./indexes').buildMemberIndexes>} indexes
 */
function matchPersonaToMember(persona, indexes) {
  const { id, data } = persona;
  const identificador = normalizeId(data.identificador);

  if (data[TRACE_FIELDS.migrationVersion]) {
    return result('ALREADY_MIGRATED', [indexes.byId.get(id)].filter(Boolean), 'migrationVersion on persona');
  }

  if (!identificador && !id) {
    return result('INVALID', [], 'missing persona id and identificador');
  }

  const direct = indexes.byId.get(id);
  if (direct) {
    return result('MATCH_EXACT', [direct], 'persona.id === members.id');
  }

  const candidates = uniqueMembers([
    lookupIndex(indexes.byWorkerCode, identificador),
    lookupIndex(indexes.byDocumentId, identificador),
    lookupIndex(indexes.byMemberNumber, identificador),
  ]);

  if (candidates.length === 1) {
    const via = matchViaField(identificador, candidates[0], indexes);
    return result('MATCH_EXACT', candidates, via);
  }
  if (candidates.length > 1) {
    return result('MATCH_MULTIPLE', candidates, 'identificador matches multiple members');
  }

  return result('NO_MATCH', [], 'no stable identifier match');
}

/**
 * @param {'MATCH_EXACT'|'MATCH_MULTIPLE'|'NO_MATCH'|'INVALID'|'ALREADY_MIGRATED'} status
 * @param {Array<{id: string}>} matches
 * @param {string} reason
 */
function result(status, matches, reason) {
  return {
    status,
    memberIds: matches.map((m) => m.id),
    reason,
  };
}

function matchViaField(identificador, member, indexes) {
  const { id, data } = member;
  if (normalizeId(data.workerCode) === identificador) return 'identificador === workerCode';
  if (normalizeId(data.documentId) === identificador) return 'identificador === documentId';
  if (normalizeId(data.memberNumber) === identificador) return 'identificador === memberNumber';
  return `matched member ${id}`;
}

module.exports = { matchPersonaToMember };
