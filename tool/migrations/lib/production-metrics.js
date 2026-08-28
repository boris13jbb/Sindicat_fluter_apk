'use strict';

const crypto = require('crypto');
const { analyzeInventory, summarizeMetrics } = require('./inventory');
const { runDryRun } = require('./dry-run');
const { MIGRATION_VERSION } = require('./constants');

/**
 * Métricas extendidas para inventario read-only de producción.
 * @param {ReturnType<import('./production-reader').loadProductionSnapshots> extends Promise<infer T> ? T : never} snapshots
 */
function buildProductionMetrics(snapshots) {
  const analysis = analyzeInventory({
    personas: snapshots.personas,
    eventos: snapshots.eventos,
    asistencias: snapshots.asistencias,
    members: snapshots.members,
    users: snapshots.users,
    attendanceEvents: snapshots.attendanceEvents,
    modernAttendances: snapshots.modernAttendances,
  });

  const base = summarizeMetrics(analysis);
  const dryRun = runDryRun(snapshots, { apply: false });

  const membersActive = snapshots.members.filter(
    (m) => m.data?.status !== 'inactive' && m.data?.isActive !== false,
  ).length;
  const membersInactive = snapshots.members.length - membersActive;

  const usersDetailed = summarizeUsers(analysis.userResults);
  const personasDetailed = countByStatus(analysis.personaResults, 'status');
  const eventosDetailed = countByStatus(analysis.eventoResults, 'status');
  const asistenciasDetailed = summarizeAsistencias(analysis.asistenciaResults);

  const manualCases = countManualCases(analysis);

  const consistency = checkConsistency(asistenciasDetailed, snapshots);

  return {
    analysisVersion: 'production-readonly-v1',
    migrationVersion: MIGRATION_VERSION,
    collectionCounts: {
      users: snapshots.users.length,
      members: snapshots.members.length,
      personas: snapshots.personas.length,
      eventos: snapshots.eventos.length,
      attendance_events: snapshots.attendanceEvents.length,
      asistencias_root: snapshots.asistenciaPhysical?.rootCount ?? 'NO DETERMINADO',
      asistencias_evento_sub: snapshots.asistenciaPhysical?.subcollectionCount ?? 'NO DETERMINADO',
      asistencias_physical_total:
        snapshots.asistenciaPhysical?.physicalTotal ?? snapshots.asistencias.length,
      asistencias_logical_unique:
        snapshots.asistenciaPhysical?.logicalUnique ?? snapshots.asistencias.length,
      modern_attendances: snapshots.modernAttendances.length,
    },
    dualWrite: snapshots.dualWriteStats ?? {
      physicalTotal: 'NO DETERMINADO',
      logicalUnique: 'NO DETERMINADO',
      dualWritePairs: 'NO DETERMINADO',
      dualWriteExtraReplicas: 'NO DETERMINADO',
    },
    users: {
      total: snapshots.users.length,
      conMemberId: usersDetailed.ALREADY_LINKED + usersDetailed.INVALID,
      sinMemberId:
        usersDetailed.MATCH_EXACT +
        usersDetailed.MATCH_MULTIPLE +
        usersDetailed.NO_MATCH,
      memberIdValido: usersDetailed.ALREADY_LINKED,
      memberIdInexistente: usersDetailed.INVALID,
      matchExactoPosible: usersDetailed.MATCH_EXACT,
      ambiguo: usersDetailed.MATCH_MULTIPLE,
      sinMatch: usersDetailed.NO_MATCH,
    },
    members: {
      total: snapshots.members.length,
      activos: membersActive,
      inactivos: membersInactive,
    },
    personas: {
      total: snapshots.personas.length,
      ...mapPersonaLabels(personasDetailed),
    },
    eventos: {
      totalLegacy: snapshots.eventos.length,
      totalModernos: snapshots.attendanceEvents.length,
      ...mapEventoLabels(eventosDetailed),
    },
    asistencias: {
      registrosFisicosLegacy:
        snapshots.asistenciaPhysical?.physicalTotal ?? 'NO DETERMINADO',
      registrosLogicosUnicos:
        snapshots.asistenciaPhysical?.logicalUnique ?? snapshots.asistencias.length,
      modernasExistentes: snapshots.modernAttendances.length,
      ...asistenciasDetailed,
      dualWriteReplicas: snapshots.dualWriteStats?.dualWriteExtraReplicas ?? 'NO DETERMINADO',
    },
    dryRunProposed: {
      writes: dryRun.writeCount,
      deletes: dryRun.deleteCount,
    },
    manualCases,
    consistency,
    plan41C: buildPlan41C({
      personas: mapPersonaLabels(personasDetailed),
      users: usersDetailed,
      eventos: mapEventoLabels(eventosDetailed),
      asistencias: asistenciasDetailed,
    }),
    snapshotFingerprint: computeFingerprint(snapshots),
  };
}

/**
 * @param {Array<Record<string, unknown>>} userResults
 */
function summarizeUsers(userResults) {
  /** @type {Record<string, number>} */
  const out = {
    ALREADY_LINKED: 0,
    MATCH_EXACT: 0,
    MATCH_MULTIPLE: 0,
    NO_MATCH: 0,
    INVALID: 0,
  };

  for (const row of userResults) {
    switch (row.status) {
      case 'HAS_MEMBER_ID':
        out.ALREADY_LINKED += 1;
        break;
      case 'INVALID_MEMBER_ID':
        out.INVALID += 1;
        break;
      case 'MATCH_POSSIBLE':
        out.MATCH_EXACT += 1;
        break;
      case 'REQUIRES_REVIEW':
        out.MATCH_MULTIPLE += 1;
        break;
      case 'NO_MATCH':
        out.NO_MATCH += 1;
        break;
      default:
        out.INVALID += 1;
    }
  }
  return out;
}

/**
 * @param {Array<Record<string, unknown>>} asistenciaResults
 */
function summarizeAsistencias(asistenciaResults) {
  /** @type {Record<string, number>} */
  const out = {
    MIGRATABLE: 0,
    ALREADY_MIGRATED: 0,
    EXACT_DUPLICATE: 0,
    PROBABLE_DUPLICATE: 0,
    ORPHAN_EVENT: 0,
    ORPHAN_PERSON: 0,
    MEMBER_UNRESOLVED: 0,
    CONFLICT: 0,
    INVALID: 0,
  };

  for (const row of asistenciaResults) {
    const action = String(row.action);
    const duplicate = String(row.duplicate);
    const reason = String(row.reason || '');

    if (action === 'MIGRABLE') out.MIGRATABLE += 1;
    else if (action === 'ALREADY_MIGRATED') out.ALREADY_MIGRATED += 1;
    else if (action === 'CONFLICT') {
      if (reason.includes('member')) out.MEMBER_UNRESOLVED += 1;
      else out.CONFLICT += 1;
    } else if (action === 'INVALID') {
      if (reason.includes('evento')) out.ORPHAN_EVENT += 1;
      else if (reason.includes('persona')) out.ORPHAN_PERSON += 1;
      else out.INVALID += 1;
    }

    if (duplicate === 'EXACT_DUPLICATE') out.EXACT_DUPLICATE += 1;
    if (duplicate === 'PROBABLE_DUPLICATE') out.PROBABLE_DUPLICATE += 1;
  }

  return out;
}

/**
 * @param {Array<Record<string, unknown>>} rows
 * @param {string} field
 */
function countByStatus(rows, field) {
  /** @type {Record<string, number>} */
  const out = {};
  for (const row of rows) {
    const key = String(row[field]);
    out[key] = (out[key] || 0) + 1;
  }
  return out;
}

function mapPersonaLabels(counts) {
  return {
    MATCH_EXACT: counts.MATCH_EXACT ?? 0,
    MATCH_MULTIPLE: counts.MATCH_MULTIPLE ?? 0,
    NO_MATCH: counts.NO_MATCH ?? 0,
    INVALID: counts.INVALID ?? 0,
    ALREADY_MIGRATED: counts.ALREADY_MIGRATED ?? 0,
  };
}

function mapEventoLabels(counts) {
  return {
    EXISTE_EQUIVALENTE: counts.EXISTE_EQUIVALENTE ?? 0,
    REQUIERE_MIGRACION: counts.REQUIERE_MIGRACION ?? 0,
    AMBIGUO: counts.AMBIGUO ?? 0,
    INVALIDO: counts.INVALIDO ?? 0,
    ALREADY_MIGRATED: counts.ALREADY_MIGRATED ?? 0,
  };
}

/**
 * @param {Record<string, number>} asistencias
 * @param {Record<string, unknown>} snapshots
 */
function checkConsistency(asistencias, snapshots) {
  const logical =
    typeof snapshots.asistenciaPhysical?.logicalUnique === 'number'
      ? snapshots.asistenciaPhysical.logicalUnique
      : null;

  const classifiedTotal =
    asistencias.MIGRATABLE +
    asistencias.ALREADY_MIGRATED +
    asistencias.ORPHAN_EVENT +
    asistencias.ORPHAN_PERSON +
    asistencias.MEMBER_UNRESOLVED +
    asistencias.CONFLICT +
    asistencias.INVALID;

  const closes =
    logical == null ? 'NO DETERMINADO' : classifiedTotal === logical;

  return {
    logicalUnique: logical ?? 'NO DETERMINADO',
    classifiedTotal,
    closes,
    delta: logical == null ? 'NO DETERMINADO' : logical - classifiedTotal,
    note:
      'EXACT_DUPLICATE/PROBABLE_DUPLICATE are orthogonal flags; totals use action categories.',
  };
}

/**
 * @param {Record<string, unknown>} analysis
 */
function countManualCases(analysis) {
  const persona = (analysis.personaResults || []).filter((r) =>
    ['MATCH_MULTIPLE', 'NO_MATCH', 'INVALID'].includes(r.status),
  ).length;
  const users = (analysis.userResults || []).filter((r) =>
    ['REQUIRES_REVIEW', 'NO_MATCH', 'INVALID_MEMBER_ID'].includes(r.status),
  ).length;
  const eventos = (analysis.eventoResults || []).filter((r) =>
    ['AMBIGUO', 'INVALIDO'].includes(r.status),
  ).length;
  const asistencias = (analysis.asistenciaResults || []).filter((r) =>
    ['CONFLICT', 'INVALID'].includes(r.action),
  ).length;

  return {
    MATCH_MULTIPLE: (analysis.personaResults || []).filter((r) => r.status === 'MATCH_MULTIPLE')
      .length,
    NO_MATCH:
      (analysis.personaResults || []).filter((r) => r.status === 'NO_MATCH').length +
      (analysis.userResults || []).filter((r) => r.status === 'NO_MATCH').length,
    AMBIGUO: (analysis.eventoResults || []).filter((r) => r.status === 'AMBIGUO').length,
    ORPHAN: (analysis.asistenciaResults || []).filter((r) => r.duplicate === 'ORPHAN').length,
    CONFLICT: (analysis.asistenciaResults || []).filter((r) => r.action === 'CONFLICT').length,
    INVALID:
      (analysis.personaResults || []).filter((r) => r.status === 'INVALID').length +
      (analysis.eventoResults || []).filter((r) => r.status === 'INVALIDO').length +
      (analysis.asistenciaResults || []).filter((r) => r.action === 'INVALID').length,
    totalManualReview: persona + users + eventos + asistencias,
  };
}

/**
 * @param {Record<string, unknown>} input
 */
function buildPlan41C(input) {
  const autoMigrable =
    (input.eventos.REQUIERE_MIGRACION || 0) + (input.asistencias.MIGRATABLE || 0);

  const revisionManual =
    (input.personas.MATCH_MULTIPLE || 0) +
    (input.personas.NO_MATCH || 0) +
    (input.users.MATCH_MULTIPLE || 0) +
    (input.users.NO_MATCH || 0) +
    (input.users.INVALID || 0) +
    (input.eventos.AMBIGUO || 0) +
    (input.eventos.INVALIDO || 0) +
    (input.asistencias.ORPHAN_EVENT || 0) +
    (input.asistencias.ORPHAN_PERSON || 0) +
    (input.asistencias.MEMBER_UNRESOLVED || 0) +
    (input.asistencias.CONFLICT || 0) +
    (input.asistencias.INVALID || 0);

  const noMigrar =
    (input.eventos.EXISTE_EQUIVALENTE || 0) +
    (input.asistencias.ALREADY_MIGRATED || 0) +
    (input.personas.ALREADY_MIGRATED || 0);

  return {
    autoMigrables: autoMigrable,
    revisionManual,
    noMigrar,
    blockedUntilBackupVerified: true,
    note: 'Plan informativo — NO ejecutar en Fase 4.1B.',
  };
}

/**
 * Huella SHA-256 de IDs de documentos (sin contenido sensible).
 * @param {Record<string, Array<{id: string}>>} snapshots
 */
function computeFingerprint(snapshots) {
  const parts = [];
  for (const key of [
    'personas',
    'eventos',
    'asistencias',
    'members',
    'users',
    'attendanceEvents',
    'modernAttendances',
  ]) {
    const rows = snapshots[key] || [];
    const ids = rows.map((r) => r.id).sort();
    parts.push(`${key}:${ids.join(',')}`);
  }
  return crypto.createHash('sha256').update(parts.join('|')).digest('hex');
}

/**
 * Compara dos ejecuciones read-only.
 * @param {Record<string, unknown>} first
 * @param {Record<string, unknown>} second
 */
function compareRuns(first, second) {
  const sameFingerprint = first.snapshotFingerprint === second.snapshotFingerprint;
  const sameCounts =
    JSON.stringify(first.collectionCounts) === JSON.stringify(second.collectionCounts);

  return {
    sameFingerprint,
    sameCounts,
    dataChangedDuringAnalysis: !sameFingerprint || !sameCounts,
    firstFingerprint: first.snapshotFingerprint,
    secondFingerprint: second.snapshotFingerprint,
  };
}

module.exports = {
  buildProductionMetrics,
  summarizeUsers,
  summarizeAsistencias,
  compareRuns,
  computeFingerprint,
};
