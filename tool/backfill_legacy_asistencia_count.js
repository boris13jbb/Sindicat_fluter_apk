'use strict';

/**
 * Administrative backfill for attendance_events/{eventId}.asistenciaCount
 *
 * Default: DRY-RUN (no writes).
 * Writes require --apply.
 * Production project additionally requires --confirm-production-backfill.
 *
 * Never auto-run from CI. Never decrease or overwrite a valid existing count.
 */

const { createRequire } = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

const PRODUCTION_PROJECT = 'sistema-integrado-sindicato';
const COLLECTION = 'attendance_events';
const SUBCOLLECTION = 'asistencias';
const PAGE_SIZE = 100;
const MAX_CONCURRENCY = 4;

const CLASS = {
  MISSING: 'MISSING',
  NULL: 'NULL',
  WRONG_TYPE: 'WRONG_TYPE',
  NEGATIVE: 'NEGATIVE',
  NON_INTEGER: 'NON_INTEGER',
  VALID_ZERO: 'VALID_ZERO',
  VALID_POSITIVE: 'VALID_POSITIVE',
};

const DECISION = {
  WOULD_UPDATE: 'WOULD_UPDATE',
  UPDATED: 'UPDATED',
  NO_CHANGE: 'NO_CHANGE',
  MISMATCH_BLOCKED: 'MISMATCH_BLOCKED',
  SKIP_CONCURRENT_CHANGE: 'SKIP_CONCURRENT_CHANGE',
  REFUSED: 'REFUSED',
};

/**
 * @param {unknown} value
 * @returns {keyof typeof CLASS}
 */
function classifyAsistenciaCount(value) {
  if (value === undefined) return CLASS.MISSING;
  if (value === null) return CLASS.NULL;
  if (typeof value !== 'number' || Number.isNaN(value)) return CLASS.WRONG_TYPE;
  if (!Number.isInteger(value)) return CLASS.NON_INTEGER;
  if (value < 0) return CLASS.NEGATIVE;
  if (value === 0) return CLASS.VALID_ZERO;
  return CLASS.VALID_POSITIVE;
}

function isLegacyOrInvalid(classification) {
  return (
    classification === CLASS.MISSING ||
    classification === CLASS.NULL ||
    classification === CLASS.WRONG_TYPE ||
    classification === CLASS.NEGATIVE ||
    classification === CLASS.NON_INTEGER
  );
}

function isValidCount(classification) {
  return (
    classification === CLASS.VALID_ZERO ||
    classification === CLASS.VALID_POSITIVE
  );
}

/**
 * Decide backfill action for one event (no I/O).
 * Valid existing counts are never auto-repaired.
 *
 * @param {{
 *   classification: string,
 *   storedCount: number|null,
 *   actualAttendanceCount: number,
 *   apply?: boolean,
 * }} input
 */
function decideEventAction(input) {
  const {
    classification,
    storedCount,
    actualAttendanceCount,
    apply = false,
  } = input;

  if (isLegacyOrInvalid(classification)) {
    return {
      decision: apply ? DECISION.UPDATED : DECISION.WOULD_UPDATE,
      proposedCount: actualAttendanceCount,
      eligibleForWrite: true,
    };
  }

  if (isValidCount(classification)) {
    if (storedCount === actualAttendanceCount) {
      return {
        decision: DECISION.NO_CHANGE,
        proposedCount: storedCount,
        eligibleForWrite: false,
      };
    }
    return {
      decision: DECISION.MISMATCH_BLOCKED,
      proposedCount: null,
      eligibleForWrite: false,
      reason: 'EXISTING_COUNT_MISMATCH',
    };
  }

  return {
    decision: DECISION.MISMATCH_BLOCKED,
    proposedCount: null,
    eligibleForWrite: false,
  };
}

/**
 * @param {string[]} argv
 */
function parseArgs(argv) {
  /** @type {{
   *   projectId: string|null,
   *   apply: boolean,
   *   confirmProductionBackfill: boolean,
   *   reportPath: string|null,
   *   help: boolean,
   * }} */
  const out = {
    projectId: null,
    apply: false,
    confirmProductionBackfill: false,
    reportPath: null,
    help: false,
  };

  for (const arg of argv) {
    if (arg === '--apply') {
      out.apply = true;
    } else if (arg === '--confirm-production-backfill') {
      out.confirmProductionBackfill = true;
    } else if (arg === '--help' || arg === '-h') {
      out.help = true;
    } else if (arg.startsWith('--project=')) {
      out.projectId = arg.slice('--project='.length).trim() || null;
    } else if (arg.startsWith('--report=')) {
      out.reportPath = arg.slice('--report='.length).trim() || null;
    } else if (arg.startsWith('-')) {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return out;
}

/**
 * Fail-closed project / apply authorization.
 * @param {{
 *   projectId: string|null,
 *   apply: boolean,
 *   confirmProductionBackfill: boolean,
 *   isEmulator: boolean,
 * }} opts
 */
function assertExecutionAllowed(opts) {
  const { projectId, apply, confirmProductionBackfill, isEmulator } = opts;

  if (!projectId) {
    const err = new Error(
      'FAIL-CLOSED: --project=<projectId> is required. Refusing to infer active gcloud project.',
    );
    err.code = 'NO_PROJECT';
    throw err;
  }

  if (apply && !isEmulator && projectId === PRODUCTION_PROJECT) {
    if (!confirmProductionBackfill) {
      const err = new Error(
        'REFUSED: production --apply requires --confirm-production-backfill. ' +
          'Dry-run is allowed without that flag.',
      );
      err.code = 'PRODUCTION_APPLY_REFUSED';
      throw err;
    }
  }
}

/**
 * @template T, R
 * @param {T[]} items
 * @param {number} limit
 * @param {(item: T, index: number) => Promise<R>} fn
 * @returns {Promise<R[]>}
 */
async function mapPool(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;

  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i], i);
    }
  }

  const workers = Array.from(
    { length: Math.min(limit, Math.max(items.length, 1)) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}

/**
 * Prefer aggregation count(); fallback to select().get() size (IDs only).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} eventId
 * @param {typeof import('firebase-admin').firestore} firestoreNs
 */
async function countAsistencias(db, eventId, firestoreNs) {
  const col = db
    .collection(COLLECTION)
    .doc(eventId)
    .collection(SUBCOLLECTION);

  try {
    if (typeof col.count === 'function') {
      const agg = await col.count().get();
      const n = agg.data().count;
      if (typeof n === 'number' && Number.isInteger(n) && n >= 0) {
        return n;
      }
    }
  } catch {
    // fall through
  }

  const snap = await col.select(firestoreNs.FieldPath.documentId()).get();
  return snap.size;
}

/**
 * Deterministic pagination by documentId.
 * @param {FirebaseFirestore.Firestore} db
 * @param {typeof import('firebase-admin').firestore} firestoreNs
 */
async function listAttendanceEvents(db, firestoreNs) {
  /** @type {Array<{ id: string, data: Record<string, unknown> }>} */
  const events = [];
  let lastDoc = null;

  for (;;) {
    let q = db
      .collection(COLLECTION)
      .orderBy(firestoreNs.FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      events.push({ id: doc.id, data: doc.data() || {} });
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_SIZE) break;
  }

  return events;
}

/**
 * Empty summary counters.
 */
function emptySummary() {
  return {
    TOTAL_EVENTS: 0,
    LEGACY_MISSING: 0,
    LEGACY_NULL: 0,
    INVALID_COUNT: 0,
    VALID_COUNT: 0,
    PROPOSED_ZERO: 0,
    PROPOSED_POSITIVE: 0,
    TOTAL_PROPOSED_ATTENDANCE_COUNT: 0,
    NO_CHANGE: 0,
    MISMATCH_BLOCKED: 0,
    CONCURRENT_SKIP: 0,
    WOULD_UPDATE: 0,
    UPDATED: 0,
  };
}

/**
 * Apply one eligible update under transaction (TOCTOU-safe).
 * Only writes asistenciaCount. Never touches other fields.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} eventId
 * @param {number} expectedProposedCount
 * @param {typeof import('firebase-admin').firestore} firestoreNs
 */
async function applyAsistenciaCountTransactional(
  db,
  eventId,
  expectedProposedCount,
  firestoreNs,
) {
  const eventRef = db.collection(COLLECTION).doc(eventId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(eventRef);
    if (!snap.exists) {
      return { decision: DECISION.SKIP_CONCURRENT_CHANGE, reason: 'EVENT_GONE' };
    }

    const data = snap.data() || {};
    const classification = classifyAsistenciaCount(data.asistenciaCount);
    if (!isLegacyOrInvalid(classification)) {
      return {
        decision: DECISION.SKIP_CONCURRENT_CHANGE,
        reason: 'COUNT_NO_LONGER_LEGACY',
      };
    }

    let actual;
    try {
      // Aggregation is not available inside transactions; use ID-only select.
      const attSnap = await tx.get(
        eventRef
          .collection(SUBCOLLECTION)
          .select(firestoreNs.FieldPath.documentId()),
      );
      actual = attSnap.size;
    } catch {
      throw new Error(`Failed to recount asistencias for ${eventId}`);
    }

    if (actual !== expectedProposedCount) {
      return {
        decision: DECISION.SKIP_CONCURRENT_CHANGE,
        reason: 'ATTENDANCE_COUNT_CHANGED',
        actual,
        expectedProposedCount,
      };
    }

    tx.update(eventRef, { asistenciaCount: actual });
    return { decision: DECISION.UPDATED, writtenCount: actual };
  });
}

/**
 * @param {{
 *   db: FirebaseFirestore.Firestore,
 *   firestoreNs: typeof import('firebase-admin').firestore,
 *   apply: boolean,
 *   projectId: string,
 *   isEmulator: boolean,
 * }} opts
 */
async function runBackfill(opts) {
  const { db, firestoreNs, apply, projectId, isEmulator } = opts;
  const summary = emptySummary();
  /** @type {Array<Record<string, unknown>>} */
  const rows = [];

  const events = await listAttendanceEvents(db, firestoreNs);
  summary.TOTAL_EVENTS = events.length;

  const counted = await mapPool(events, MAX_CONCURRENCY, async (ev) => {
    const actualAttendanceCount = await countAsistencias(
      db,
      ev.id,
      firestoreNs,
    );
    const raw = Object.prototype.hasOwnProperty.call(ev.data, 'asistenciaCount')
      ? ev.data.asistenciaCount
      : undefined;
    const classification = classifyAsistenciaCount(raw);
    const storedCount = isValidCount(classification) ? raw : null;
    const action = decideEventAction({
      classification,
      storedCount,
      actualAttendanceCount,
      apply: false,
    });

    return {
      eventId: ev.id,
      classification,
      storedCount,
      actualAttendanceCount,
      ...action,
    };
  });

  for (const row of counted) {
    if (row.classification === CLASS.MISSING) summary.LEGACY_MISSING += 1;
    else if (row.classification === CLASS.NULL) summary.LEGACY_NULL += 1;
    else if (
      row.classification === CLASS.WRONG_TYPE ||
      row.classification === CLASS.NEGATIVE ||
      row.classification === CLASS.NON_INTEGER
    ) {
      summary.INVALID_COUNT += 1;
    } else if (isValidCount(row.classification)) {
      summary.VALID_COUNT += 1;
    }

    if (row.decision === DECISION.NO_CHANGE) {
      summary.NO_CHANGE += 1;
    } else if (row.decision === DECISION.MISMATCH_BLOCKED) {
      summary.MISMATCH_BLOCKED += 1;
    } else if (row.eligibleForWrite) {
      if (row.proposedCount === 0) summary.PROPOSED_ZERO += 1;
      else if (typeof row.proposedCount === 'number' && row.proposedCount > 0) {
        summary.PROPOSED_POSITIVE += 1;
      }
      if (typeof row.proposedCount === 'number') {
        summary.TOTAL_PROPOSED_ATTENDANCE_COUNT += row.proposedCount;
      }
    }
  }

  if (!apply) {
    for (const row of counted) {
      let decision = row.decision;
      if (row.eligibleForWrite) {
        decision = DECISION.WOULD_UPDATE;
        summary.WOULD_UPDATE += 1;
      }
      rows.push({
        eventId: row.eventId,
        storedClassification: row.classification,
        actualAttendanceCount: row.actualAttendanceCount,
        proposedCount: row.proposedCount,
        decision,
        ...(row.reason ? { reason: row.reason } : {}),
      });
    }

    return {
      mode: 'DRY-RUN',
      writesEnabled: false,
      projectId,
      isEmulator,
      summary,
      rows,
    };
  }

  // APPLY path — only eligible legacy/invalid rows; concurrency capped.
  const eligible = counted.filter((r) => r.eligibleForWrite);
  const applyResults = await mapPool(
    eligible,
    MAX_CONCURRENCY,
    async (row) => {
      const result = await applyAsistenciaCountTransactional(
        db,
        row.eventId,
        row.proposedCount,
        firestoreNs,
      );
      return { row, result };
    },
  );

  const appliedById = new Map(
    applyResults.map(({ row, result }) => [row.eventId, result]),
  );

  for (const row of counted) {
    if (!row.eligibleForWrite) {
      if (row.decision === DECISION.NO_CHANGE) {
        // already counted
      } else if (row.decision === DECISION.MISMATCH_BLOCKED) {
        // already counted
      }
      rows.push({
        eventId: row.eventId,
        storedClassification: row.classification,
        actualAttendanceCount: row.actualAttendanceCount,
        proposedCount: row.proposedCount,
        decision: row.decision,
        ...(row.reason ? { reason: row.reason } : {}),
      });
      continue;
    }

    const result = appliedById.get(row.eventId);
    if (!result || result.decision === DECISION.SKIP_CONCURRENT_CHANGE) {
      summary.CONCURRENT_SKIP += 1;
      rows.push({
        eventId: row.eventId,
        storedClassification: row.classification,
        actualAttendanceCount: row.actualAttendanceCount,
        proposedCount: row.proposedCount,
        decision: DECISION.SKIP_CONCURRENT_CHANGE,
        ...(result?.reason ? { reason: result.reason } : {}),
      });
    } else if (result.decision === DECISION.UPDATED) {
      summary.UPDATED += 1;
      rows.push({
        eventId: row.eventId,
        storedClassification: row.classification,
        actualAttendanceCount: row.actualAttendanceCount,
        proposedCount: result.writtenCount,
        decision: DECISION.UPDATED,
      });
    } else {
      rows.push({
        eventId: row.eventId,
        storedClassification: row.classification,
        actualAttendanceCount: row.actualAttendanceCount,
        proposedCount: row.proposedCount,
        decision: result.decision || DECISION.SKIP_CONCURRENT_CHANGE,
      });
    }
  }

  return {
    mode: 'APPLY',
    writesEnabled: true,
    projectId,
    isEmulator,
    summary,
    rows,
  };
}

function loadFirebaseAdmin() {
  const functionsRequire = createRequire(
    path.join(__dirname, '..', 'functions', 'package.json'),
  );
  return functionsRequire('firebase-admin');
}

/**
 * @param {{ projectId: string, isEmulator: boolean }} opts
 */
function initializeAdminApp(opts) {
  const admin = loadFirebaseAdmin();

  // Reuse existing default app when project matches (tests / repeated CLI).
  const existing = admin.apps.find((a) => a && a.name === '[DEFAULT]');
  if (existing) {
    const existingProject = existing.options?.projectId;
    if (existingProject && existingProject !== opts.projectId) {
      throw new Error(
        `Firebase Admin already initialized for project ${existingProject}; ` +
          `requested ${opts.projectId}. Restart process to switch.`,
      );
    }
    return admin;
  }

  if (opts.isEmulator) {
    admin.initializeApp({ projectId: opts.projectId });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: opts.projectId,
    });
  }

  return admin;
}

function printBanner(ctx) {
  console.log('========================================');
  console.log('LEGACY asistenciaCount BACKFILL');
  console.log('========================================');
  console.log(`MODE: ${ctx.mode}`);
  console.log(`WRITES ENABLED: ${ctx.writesEnabled ? 'YES' : 'NO'}`);
  console.log(`PROJECT: ${ctx.projectId}`);
  console.log(`ENVIRONMENT: ${ctx.isEmulator ? 'EMULATOR' : 'LIVE'}`);
  console.log('========================================');
}

function printSummary(summary) {
  console.log('');
  console.log('--- SUMMARY ---');
  for (const key of Object.keys(summary)) {
    console.log(`${key}: ${summary[key]}`);
  }
}

function printPrivacyRows(rows) {
  console.log('');
  console.log('--- EVENTS (sanitized) ---');
  for (const row of rows) {
    console.log(
      [
        `eventId=${row.eventId}`,
        `classification=${row.storedClassification}`,
        `actual=${row.actualAttendanceCount}`,
        `proposed=${row.proposedCount === null || row.proposedCount === undefined ? 'n/a' : row.proposedCount}`,
        `decision=${row.decision}`,
        row.reason ? `reason=${row.reason}` : null,
      ]
        .filter(Boolean)
        .join(' | '),
    );
  }
}

/**
 * @param {object} report
 * @param {string} reportPath
 */
function writeReport(report, reportPath) {
  const dir = path.dirname(reportPath);
  fs.mkdirSync(dir, { recursive: true });
  const sanitized = {
    tool: 'backfill_legacy_asistencia_count',
    generatedAt: new Date().toISOString(),
    mode: report.mode,
    writesEnabled: report.writesEnabled,
    projectId: report.projectId,
    isEmulator: report.isEmulator,
    summary: report.summary,
    rows: report.rows.map((r) => ({
      eventId: r.eventId,
      storedClassification: r.storedClassification,
      actualAttendanceCount: r.actualAttendanceCount,
      proposedCount: r.proposedCount,
      decision: r.decision,
      ...(r.reason ? { reason: r.reason } : {}),
    })),
  };
  fs.writeFileSync(reportPath, `${JSON.stringify(sanitized, null, 2)}\n`, 'utf8');
  console.log(`REPORT_WRITTEN: ${reportPath}`);
}

function printHelp() {
  console.log(`Usage:
  node tool/backfill_legacy_asistencia_count.js --project=<projectId> [options]

Options:
  --project=<id>                 Required. Never inferred from gcloud.
  --apply                        Enable writes (default: dry-run).
  --confirm-production-backfill  Required with --apply on ${PRODUCTION_PROJECT}.
  --report=<path>                Write sanitized JSON report.
  --help                         Show this help.

Default mode is DRY-RUN (WRITES ENABLED: NO).
Emulator: set FIRESTORE_EMULATOR_HOST; --apply allowed without production confirm.
`);
}

async function main(argv = process.argv.slice(2)) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (err) {
    console.error(String(err.message || err));
    process.exitCode = 2;
    return { ok: false, code: 'BAD_ARGS' };
  }

  if (args.help) {
    printHelp();
    return { ok: true, code: 'HELP' };
  }

  const isEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

  try {
    assertExecutionAllowed({
      projectId: args.projectId,
      apply: args.apply,
      confirmProductionBackfill: args.confirmProductionBackfill,
      isEmulator,
    });
  } catch (err) {
    console.error(String(err.message || err));
    process.exitCode = err.code === 'PRODUCTION_APPLY_REFUSED' ? 3 : 2;
    return {
      ok: false,
      code: err.code || 'REFUSED',
      message: err.message,
    };
  }

  const mode = args.apply ? 'APPLY' : 'DRY-RUN';
  const writesEnabled = Boolean(args.apply);
  printBanner({
    mode,
    writesEnabled,
    projectId: args.projectId,
    isEmulator,
  });

  const admin = initializeAdminApp({
    projectId: args.projectId,
    isEmulator,
  });
  const db = admin.firestore();
  const firestoreNs = admin.firestore;

  const report = await runBackfill({
    db,
    firestoreNs,
    apply: args.apply,
    projectId: args.projectId,
    isEmulator,
  });

  printSummary(report.summary);
  printPrivacyRows(report.rows);

  if (args.reportPath) {
    writeReport(report, args.reportPath);
  }

  return { ok: true, report };
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}

module.exports = {
  PRODUCTION_PROJECT,
  CLASS,
  DECISION,
  PAGE_SIZE,
  MAX_CONCURRENCY,
  classifyAsistenciaCount,
  isLegacyOrInvalid,
  isValidCount,
  decideEventAction,
  parseArgs,
  assertExecutionAllowed,
  mapPool,
  countAsistencias,
  listAttendanceEvents,
  applyAsistenciaCountTransactional,
  runBackfill,
  emptySummary,
  main,
  initializeAdminApp,
  loadFirebaseAdmin,
};
