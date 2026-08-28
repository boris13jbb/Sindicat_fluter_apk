'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { mergeLegacyAsistenciaSources } = require('./lib/production-reader');
const { createReadonlyFirestore, resetAudit, getAudit } = require('./lib/readonly-firestore');
const {
  resolveReadonlyCredentials,
  assertProjectMatch,
  assertNotEmulator,
} = require('./lib/credential-guard');
const { buildProductionMetrics, compareRuns } = require('./lib/production-metrics');
const { loadFixtures } = require('./lib/firestore-reader');
const { writeProductionReport, maskEmail } = require('./lib/production-report');

const fixturePath = path.join(__dirname, 'fixtures', 'emulator-fixtures.json');

describe('production read-only gates', () => {
  it('rejects missing credentials', () => {
    const prev = process.env.PRODUCTION_READONLY_CREDENTIALS;
    delete process.env.PRODUCTION_READONLY_CREDENTIALS;
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    assert.throws(
      () => resolveReadonlyCredentials({ repoRoot: path.join(__dirname, '..', '..') }),
      /Missing read-only credentials/,
    );
    if (prev) process.env.PRODUCTION_READONLY_CREDENTIALS = prev;
  });

  it('rejects credentials inside repository', () => {
    const inside = path.join(__dirname, 'fixtures', 'temp-cred.json');
    fs.writeFileSync(inside, '{"type":"service_account","client_email":"a@b.com","project_id":"x"}');
    try {
      assert.throws(
        () =>
          resolveReadonlyCredentials({
            repoRoot: path.join(__dirname, '..', '..'),
            credentialsPath: inside,
          }),
        /inside the repository/,
      );
    } finally {
      fs.unlinkSync(inside);
    }
  });

  it('blocks --apply via CLI parser', () => {
    const { spawnSync } = require('node:child_process');
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, 'production_readonly_inventory.js'), '--apply'],
      { encoding: 'utf8' },
    );
    assert.notEqual(result.status, 0);
    assert.match(result.stderr + result.stdout, /--apply is PROHIBITED/);
  });

  it('requires production readonly flags', () => {
    const { spawnSync } = require('node:child_process');
    const result = spawnSync(
      process.execPath,
      [
        path.join(__dirname, 'production_readonly_inventory.js'),
        '--project',
        'sistema-integrado-sindicato',
      ],
      { encoding: 'utf8' },
    );
    assert.notEqual(result.status, 0);
    assert.match(result.stderr + result.stdout, /Missing --production-readonly/);
  });
});

describe('readonly firestore proxy', () => {
  it('blocks set/update/delete and tracks audit', async () => {
    resetAudit();
    const mockDoc = {
      get: async () => ({ exists: true }),
    };
    const mockCollection = {
      doc: () => mockDoc,
      get: async () => ({ docs: [] }),
    };
    const mockDb = {
      collection: () => mockCollection,
    };

    const db = createReadonlyFirestore(mockDb);
    const doc = db.collection('users').doc('u1');
    assert.throws(() => doc.set({}), /blocked/);
    assert.throws(() => doc.update({}), /blocked/);
    assert.throws(() => doc.delete(), /blocked/);
    await assert.rejects(async () => db.batch().commit(), /blocked/);
    const audit = getAudit();
    assert.ok(audit.writesAttempted >= 3);
    assert.ok(audit.deletesAttempted >= 1);
  });
});

describe('dual-write asistencia merge', () => {
  it('deduplicates root and subcollection copies', () => {
    const root = [
      {
        id: 'ev1_persona1',
        source: 'asistencias_root',
        data: { eventoId: 'ev1', personaId: 'persona1' },
      },
    ];
    const sub = [
      {
        id: 'ev1_persona1',
        eventoId: 'ev1',
        source: 'eventos_subcollection',
        data: { eventoId: 'ev1', personaId: 'persona1' },
      },
    ];
    const merged = mergeLegacyAsistenciaSources(root, sub);
    assert.equal(merged.physical.physicalTotal, 2);
    assert.equal(merged.physical.logicalUnique, 1);
    assert.equal(merged.physical.dualWritePairs, 1);
    assert.equal(merged.logicalRecords.length, 1);
  });
});

describe('production metrics on fixtures', () => {
  it('builds metrics without writes', () => {
    const snapshots = loadFixtures(fixturePath);
    const metrics = buildProductionMetrics({
      ...snapshots,
      asistenciaPhysical: {
        rootCount: snapshots.asistencias.length,
        subcollectionCount: 0,
        physicalTotal: snapshots.asistencias.length,
        logicalUnique: snapshots.asistencias.length,
      },
      dualWriteStats: {
        physicalTotal: snapshots.asistencias.length,
        logicalUnique: snapshots.asistencias.length,
        dualWritePairs: 0,
        dualWriteExtraReplicas: 0,
      },
    });
    assert.equal(metrics.analysisVersion, 'production-readonly-v1');
    assert.ok(metrics.collectionCounts.users >= 0);
    assert.ok(metrics.snapshotFingerprint);
    assert.equal(metrics.plan41C.blockedUntilBackupVerified, true);
  });

  it('detects unchanged data between two metric runs', () => {
    const snapshots = loadFixtures(fixturePath);
    const first = buildProductionMetrics(snapshots);
    const second = buildProductionMetrics(snapshots);
    const cmp = compareRuns(first, second);
    assert.equal(cmp.dataChangedDuringAnalysis, false);
  });
});

describe('sanitized production report', () => {
  it('masks email and writes gitignored output', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'prod-report-'));
    const report = {
      identity: {
        type: 'service_account',
        serviceAccountEmail: 'readonly@sistema-integrado-sindicato.iam.gserviceaccount.com',
        projectId: 'sistema-integrado-sindicato',
        canRead: true,
        canWrite: false,
      },
      metrics: { users: { total: 1 } },
      security: { writesAttempted: 0, deletesAttempted: 0 },
    };
    const paths = writeProductionReport(report, { outputDir: tmp });
    assert.ok(fs.existsSync(paths.jsonPath));
    const raw = fs.readFileSync(paths.jsonPath, 'utf8');
    assert.ok(!raw.includes('readonly@sistema-integrado-sindicato'));
    assert.equal(maskEmail('readonly@test.com').includes('***'), true);
    fs.rmSync(tmp, { recursive: true, force: true });
  });
});

describe('project and emulator guards', () => {
  it('asserts project match', () => {
    assert.throws(
      () => assertProjectMatch('a', 'b'),
      /Project mismatch/,
    );
  });

  it('blocks emulator host in production mode', () => {
    const prev = process.env.FIRESTORE_EMULATOR_HOST;
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    assert.throws(() => assertNotEmulator(), /FIRESTORE_EMULATOR_HOST/);
    if (prev) process.env.FIRESTORE_EMULATOR_HOST = prev;
    else delete process.env.FIRESTORE_EMULATOR_HOST;
  });
});
