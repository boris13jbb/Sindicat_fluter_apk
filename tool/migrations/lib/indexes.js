'use strict';

const { normalizeEmail, normalizeId } = require('./normalize');

/**
 * Índices de members para matching seguro (sin nombre).
 * @param {Array<{id: string, data: Record<string, unknown>}>} members
 */
function buildMemberIndexes(members) {
  const byId = new Map();
  const byWorkerCode = new Map();
  const byDocumentId = new Map();
  const byMemberNumber = new Map();
  const byEmail = new Map();

  for (const { id, data } of members) {
    const entry = { id, data };
    byId.set(id, entry);

    const workerCode = normalizeId(data.workerCode);
    if (workerCode) addToIndex(byWorkerCode, workerCode, entry);

    const documentId = normalizeId(data.documentId);
    if (documentId) addToIndex(byDocumentId, documentId, entry);

    const memberNumber = normalizeId(data.memberNumber);
    if (memberNumber) addToIndex(byMemberNumber, memberNumber, entry);

    const email = normalizeEmail(data.email);
    if (email) addToIndex(byEmail, email, entry);
  }

  return { byId, byWorkerCode, byDocumentId, byMemberNumber, byEmail };
}

/**
 * @param {Map<string, Array<{id: string, data: Record<string, unknown>}>>} map
 * @param {string} key
 * @param {{id: string, data: Record<string, unknown>}} entry
 */
function addToIndex(map, key, entry) {
  const list = map.get(key) ?? [];
  if (!list.some((e) => e.id === entry.id)) {
    list.push(entry);
  }
  map.set(key, list);
}

/**
 * @param {Map<string, Array<{id: string, data: Record<string, unknown>}>>} map
 * @param {string} key
 * @returns {Array<{id: string, data: Record<string, unknown>}>}
 */
function lookupIndex(map, key) {
  if (!key) return [];
  return map.get(key) ?? [];
}

/**
 * Une resultados únicos por member id.
 * @param {Array<Array<{id: string}>>} groups
 */
function uniqueMembers(groups) {
  const seen = new Set();
  const out = [];
  for (const group of groups) {
    for (const item of group) {
      if (!seen.has(item.id)) {
        seen.add(item.id);
        out.push(item);
      }
    }
  }
  return out;
}

module.exports = {
  buildMemberIndexes,
  lookupIndex,
  uniqueMembers,
};
