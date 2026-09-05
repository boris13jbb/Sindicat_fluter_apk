'use strict';

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const fs = require('fs');
const os = require('os');

const {
  CLASS,
  DECISION,
  classifyAsistenciaCount,
  decideEventAction,
  parseArgs,
  assertExecutionAllowed,
  runBackfill,
  main,
  initializeAdminApp,
  PRODUCTION_PROJECT,
} = require('./backfill_legacy_asistencia_count');

describe('classifyAsistenciaCount', () => {
  it('MISSING when undefined', () => {
    assert.equal(classifyAsistenciaCount(undefined), CLASS.MISSING);
  });

  it('NULL when null', () => {
    assert.equal(classifyAsistenciaCount(null), CLASS.NULL);
  });

  it('WRONG_TYPE for string/boolean/object', () => {
    assert.equal(classifyAsistenciaCount('3'), CLASS.WRONG_TYPE);
    assert.equal(classifyAsistenciaCount(true), CLASS.WRONG_TYPE);
    assert.equal(classifyAsistenciaCount({}), CLASS.WRONG_TYPE);
  });

  it('NEGATIVE for negative integers', () => {
    assert.equal(classifyAsistenciaCount(-1), CLASS.NEGATIVE);
  });

  it('NON_INTEGER for floats', () => {
    assert.equal(classifyAsistenciaCount(1.5), CLASS.NON_INTEGER);
  });

  it('VALID_ZERO / VALID_POSITIVE', () => {
    assert.equal(classifyAsistenciaCount(0), CLASS.VALID_ZERO);
    assert.equal(classifyAsistenciaCount(3), CLASS.VALID_POSITIVE);
  });
});

describe('decideEventAction proposals', () => {
  it('1. missing + 0 attendance -> propose 0', () => {
    const r = decideEventAction({
      classification: CLASS.MISSING,
      storedCount: null,
      actualAttendanceCount: 0,
    });
    assert.equal(r.decision, DECISION.WOULD_UPDATE);
    assert.equal(r.proposedCount, 0);
    assert.equal(r.eligibleForWrite, true);
  });

  it('2. missing + 3 attendance -> propose 3', () => {
    const r = decideEventAction({
      classification: CLASS.MISSING,
      storedCount: null,
      actualAttendanceCount: 3,
    });
    assert.equal(r.proposedCount, 3);
    assert.equal(r.decision, DECISION.WOULD_UPDATE);
  });

  it('3. null -> propose real count', () => {
    const r = decideEventAction({
      classification: CLASS.NULL,
      storedCount: null,
      actualAttendanceCount: 2,
    });
    assert.equal(r.proposedCount, 2);
    assert.equal(r.eligibleForWrite, true);
  });

  it('4. wrong type -> propose real count', () => {
    const r = decideEventAction({
      classification: CLASS.WRONG_TYPE,
      storedCount: null,
      actualAttendanceCount: 1,
    });
    assert.equal(r.proposedCount, 1);
  });

  it('5. negative -> invalid/propose', () => {
    const r = decideEventAction({
      classification: CLASS.NEGATIVE,
      storedCount: null,
      actualAttendanceCount: 4,
    });
    assert.equal(r.proposedCount, 4);
    assert.equal(r.eligibleForWrite, true);
  });

  it('6. non-integer -> invalid/propose', () => {
    const r = decideEventAction({
      classification: CLASS.NON_INTEGER,
      storedCount: null,
      actualAttendanceCount: 5,
    });
    assert.equal(r.proposedCount, 5);
  });

  it('7. valid 0 / actual 0 -> NO_CHANGE', () => {
    const r = decideEventAction({
      classification: CLASS.VALID_ZERO,
      storedCount: 0,
      actualAttendanceCount: 0,
    });
    assert.equal(r.decision, DECISION.NO_CHANGE);
    assert.equal(r.eligibleForWrite, false);
  });

  it('8. valid 3 / actual 3 -> NO_CHANGE', () => {
    const r = decideEventAction({
      classification: CLASS.VALID_POSITIVE,
      storedCount: 3,
      actualAttendanceCount: 3,
    });
    assert.equal(r.decision, DECISION.NO_CHANGE);
  });

  it('9. valid 1 / actual 2 -> MISMATCH_BLOCKED', () => {
    const r = decideEventAction({
      classification: CLASS.VALID_POSITIVE,
      storedCount: 1,
      actualAttendanceCount: 2,
    });
    assert.equal(r.decision, DECISION.MISMATCH_BLOCKED);
    assert.equal(r.eligibleForWrite, false);
    assert.equal(r.reason, 'EXISTING_COUNT_MISMATCH');
  });

  it('10. valid 3 / actual 1 -> MISMATCH_BLOCKED', () => {
    const r = decideEventAction({
      classification: CLASS.VALID_POSITIVE,
      storedCount: 3,
      actualAttendanceCount: 1,
    });
    assert.equal(r.decision, DECISION.MISMATCH_BLOCKED);
  });
});

describe('guards', () => {
  it('16. no project -> fail closed', () => {
    assert.throws(
      () =>
        assertExecutionAllowed({
          projectId: null,
          apply: false,
          confirmProductionBackfill: false,
          isEmulator: false,
        }),
      /FAIL-CLOSED/,
    );
  });

  it('15. production --apply without confirmation -> REFUSED', () => {
    assert.throws(
      () =>
        assertExecutionAllowed({
          projectId: PRODUCTION_PROJECT,
          apply: true,
          confirmProductionBackfill: false,
          isEmulator: false,
        }),
      /REFUSED/,
    );
  });

  it('production dry-run without confirm is allowed', () => {
    assert.doesNotThrow(() =>
      assertExecutionAllowed({
        projectId: PRODUCTION_PROJECT,
        apply: false,
        confirmProductionBackfill: false,
        isEmulator: false,
      }),
    );
  });

  it('emulator --apply without production confirm is allowed', () => {
    assert.doesNotThrow(() =>
      assertExecutionAllowed({
        projectId: PRODUCTION_PROJECT,
        apply: true,
        confirmProductionBackfill: false,
        isEmulator: true,
      }),
    );
  });

  it('parseArgs defaults to dry-run', () => {
    const a = parseArgs(['--project=demo']);
    assert.equal(a.apply, false);
    assert.equal(a.projectId, 'demo');
  });
});

describe('main CLI guards (no network)', () => {
  it('15b. main production --apply without confirm exits refused', async () => {
    const prevHost = process.env.FIRESTORE_EMULATOR_HOST;
    const prevExit = process.exitCode;
    delete process.env.FIRESTORE_EMULATOR_HOST;
    process.exitCode = 0;
    try {
      const result = await main([
        `--project=${PRODUCTION_PROJECT}`,
        '--apply',
      ]);
      assert.equal(result.ok, false);
      assert.equal(result.code, 'PRODUCTION_APPLY_REFUSED');
      assert.equal(process.exitCode, 3);
    } finally {
      if (prevHost !== undefined) process.env.FIRESTORE_EMULATOR_HOST = prevHost;
      else delete process.env.FIRESTORE_EMULATOR_HOST;
      process.exitCode = prevExit;
    }
  });

  it('16b. main without project fails closed', async () => {
    const prevExit = process.exitCode;
    process.exitCode = 0;
    try {
      const result = await main([]);
      assert.equal(result.ok, false);
      assert.equal(result.code, 'NO_PROJECT');
      assert.equal(process.exitCode, 2);
    } finally {
      process.exitCode = prevExit;
    }
  });
});

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

describe(
  'emulator integration',
  { skip: hasEmulator ? false : 'FIRESTORE_EMULATOR_HOST not set' },
  () => {
    const projectId = 'backfill-asistencia-count-test';
    let admin;
    let db;
    let firestoreNs;

    async function clearCollection() {
      const snap = await db.collection('attendance_events').get();
      for (const doc of snap.docs) {
        const sub = await doc.ref.collection('asistencias').listDocuments();
        for (const s of sub) {
          await s.delete();
        }
        await doc.ref.delete();
      }
    }

    /**
     * Fixture equivalent to production audit shape:
     * 12 events, all missing asistenciaCount;
     * 9×0, 1×1, 1×2, 1×3 attendances.
     */
    async function seedProductionLikeFixture() {
      const specs = [
        ...Array.from({ length: 9 }, (_, i) => ({
          id: `zero-${String(i + 1).padStart(2, '0')}`,
          n: 0,
        })),
        { id: 'pos-01', n: 1 },
        { id: 'pos-02', n: 2 },
        { id: 'pos-03', n: 3 },
      ];

      for (const spec of specs) {
        // Intentionally omit asistenciaCount (legacy missing).
        await db.collection('attendance_events').doc(spec.id).set({
          activo: true,
          // name omitted from reports; present only as fixture noise
          nombre: `fixture-${spec.id}`,
        });
        for (let i = 0; i < spec.n; i += 1) {
          await db
            .collection('attendance_events')
            .doc(spec.id)
            .collection('asistencias')
            .doc(`a${i}`)
            .set({ memberId: `m${i}` });
        }
      }
      return specs;
    }

    before(async () => {
      admin = initializeAdminApp({ projectId, isEmulator: true });
      db = admin.firestore();
      firestoreNs = admin.firestore;
      await clearCollection();
    });

    after(async () => {
      await clearCollection();
      if (admin?.apps?.length) {
        await Promise.all(admin.apps.filter(Boolean).map((a) => a.delete()));
      }
    });

    beforeEach(async () => {
      await clearCollection();
    });

    it('11. dry-run -> zero writes', async () => {
      await seedProductionLikeFixture();
      const report = await runBackfill({
        db,
        firestoreNs,
        apply: false,
        projectId,
        isEmulator: true,
      });
      assert.equal(report.mode, 'DRY-RUN');
      assert.equal(report.writesEnabled, false);
      assert.equal(report.summary.TOTAL_EVENTS, 12);
      assert.equal(report.summary.WOULD_UPDATE, 12);
      assert.equal(report.summary.PROPOSED_ZERO, 9);
      assert.equal(report.summary.PROPOSED_POSITIVE, 3);
      assert.equal(report.summary.TOTAL_PROPOSED_ATTENDANCE_COUNT, 6);
      assert.equal(report.summary.UPDATED, 0);
      assert.equal(report.summary.MISMATCH_BLOCKED, 0);

      // Confirm still missing on a sample doc.
      const sample = await db.collection('attendance_events').doc('zero-01').get();
      assert.equal(sample.data().asistenciaCount, undefined);
    });

    it('12+13. apply then second apply idempotent', async () => {
      await seedProductionLikeFixture();

      const first = await runBackfill({
        db,
        firestoreNs,
        apply: true,
        projectId,
        isEmulator: true,
      });
      assert.equal(first.summary.UPDATED, 12);
      assert.equal(first.summary.WOULD_UPDATE, 0);

      const zero01 = await db.collection('attendance_events').doc('zero-01').get();
      assert.equal(zero01.data().asistenciaCount, 0);
      const pos03 = await db.collection('attendance_events').doc('pos-03').get();
      assert.equal(pos03.data().asistenciaCount, 3);

      const second = await runBackfill({
        db,
        firestoreNs,
        apply: true,
        projectId,
        isEmulator: true,
      });
      assert.equal(second.summary.UPDATED, 0);
      assert.equal(second.summary.NO_CHANGE, 12);
    });

    it('14. concurrent change -> SKIP / no overwrite', async () => {
      await db.collection('attendance_events').doc('race-1').set({
        activo: true,
      });
      await db
        .collection('attendance_events')
        .doc('race-1')
        .collection('asistencias')
        .doc('a0')
        .set({ memberId: 'm0' });

      // Simulate another writer setting a valid count before our apply tx.
      const { applyAsistenciaCountTransactional } = require('./backfill_legacy_asistencia_count');

      // First, mutate to a valid count (concurrent change).
      await db.collection('attendance_events').doc('race-1').update({
        asistenciaCount: 99,
      });

      const result = await applyAsistenciaCountTransactional(
        db,
        'race-1',
        1,
        firestoreNs,
      );
      assert.equal(result.decision, DECISION.SKIP_CONCURRENT_CHANGE);

      const after = await db.collection('attendance_events').doc('race-1').get();
      assert.equal(after.data().asistenciaCount, 99);
    });

    it('null / wrong type / negative / non-integer propose real counts via dry-run', async () => {
      await db.collection('attendance_events').doc('null-1').set({
        asistenciaCount: null,
      });
      await db
        .collection('attendance_events')
        .doc('null-1')
        .collection('asistencias')
        .doc('a0')
        .set({});

      await db.collection('attendance_events').doc('wrong-1').set({
        asistenciaCount: '2',
      });
      await db
        .collection('attendance_events')
        .doc('wrong-1')
        .collection('asistencias')
        .doc('a0')
        .set({});
      await db
        .collection('attendance_events')
        .doc('wrong-1')
        .collection('asistencias')
        .doc('a1')
        .set({});

      await db.collection('attendance_events').doc('neg-1').set({
        asistenciaCount: -3,
      });

      await db.collection('attendance_events').doc('float-1').set({
        asistenciaCount: 1.7,
      });
      await db
        .collection('attendance_events')
        .doc('float-1')
        .collection('asistencias')
        .doc('a0')
        .set({});

      const report = await runBackfill({
        db,
        firestoreNs,
        apply: false,
        projectId,
        isEmulator: true,
      });

      const byId = Object.fromEntries(report.rows.map((r) => [r.eventId, r]));
      assert.equal(byId['null-1'].proposedCount, 1);
      assert.equal(byId['null-1'].decision, DECISION.WOULD_UPDATE);
      assert.equal(byId['wrong-1'].proposedCount, 2);
      assert.equal(byId['neg-1'].proposedCount, 0);
      assert.equal(byId['float-1'].proposedCount, 1);
    });

    it('writes sanitized report file', async () => {
      await seedProductionLikeFixture();
      const reportPath = path.join(
        os.tmpdir(),
        `backfill-report-${Date.now()}.json`,
      );
      const result = await main([
        `--project=${projectId}`,
        `--report=${reportPath}`,
      ]);
      assert.equal(result.ok, true);
      const raw = fs.readFileSync(reportPath, 'utf8');
      assert.ok(!raw.includes('fixture-'));
      assert.ok(!raw.includes('memberId'));
      const parsed = JSON.parse(raw);
      assert.equal(parsed.summary.WOULD_UPDATE, 12);
      assert.equal(parsed.writesEnabled, false);
      fs.unlinkSync(reportPath);
    });
  },
);
