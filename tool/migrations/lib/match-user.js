'use strict';

const { normalizeEmail, normalizeId } = require('./normalize');
const { lookupIndex, uniqueMembers } = require('./indexes');

/**
 * Analiza users sin memberId (solo reporte).
 * @param {{id: string, data: Record<string, unknown>}} user
 * @param {ReturnType<import('./indexes').buildMemberIndexes>} indexes
 */
function analyzeUserMemberLink(user, indexes) {
  const { id, data } = user;
  const existingMemberId = normalizeId(data.memberId);

  if (existingMemberId) {
    const linked = indexes.byId.get(existingMemberId);
    return {
      status: linked ? 'HAS_MEMBER_ID' : 'INVALID_MEMBER_ID',
      memberIds: linked ? [existingMemberId] : [],
      reason: linked ? 'users.memberId present' : 'users.memberId points to missing member',
    };
  }

  const direct = indexes.byId.get(id);
  if (direct) {
    return {
      status: 'MATCH_POSSIBLE',
      memberIds: [direct.id],
      reason: 'users.uid === members.id',
    };
  }

  const employeeNumber = normalizeId(data.employeeNumber);
  const email = normalizeEmail(data.email);

  const candidates = uniqueMembers([
    lookupIndex(indexes.byMemberNumber, employeeNumber),
    lookupIndex(indexes.byWorkerCode, employeeNumber),
    lookupIndex(indexes.byEmail, email),
  ]);

  if (candidates.length === 1) {
    return {
      status: 'MATCH_POSSIBLE',
      memberIds: [candidates[0].id],
      reason: employeeNumber
        ? 'employeeNumber matches member'
        : 'email matches member',
    };
  }
  if (candidates.length > 1) {
    return {
      status: 'REQUIRES_REVIEW',
      memberIds: candidates.map((c) => c.id),
      reason: 'multiple member candidates',
    };
  }

  return {
    status: 'NO_MATCH',
    memberIds: [],
    reason: 'no stable link found',
  };
}

module.exports = { analyzeUserMemberLink };
