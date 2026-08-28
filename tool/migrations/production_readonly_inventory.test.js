'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { mergeLegacyAsistenciaSources } = require('./lib/production-reader');
const { createReadonlyFirestore, resetAudit, getAudit } = require('./lib/readonly-firestore');
const {
  EXPECTED_READONLY_SERVICE_ACCOUNT,
  resolveReadonlyAdc,
  assertProjectMatch,
  assertNotEmulator,
  assertNoLegacyCredentialEnv,
  assertLegacyNotProductionLive,
} = require('./lib/credential-guard');
const { initializeReadonlyAdmin } = require('./lib/production-admin');
const { buildProductionMetrics, compareRuns } = require('./lib/production-metrics');
const { loadFixtures } = require('./lib/firestore-reader');
const { writeProductionReport, maskEmail } = require('./lib/production-report');

const fixturePath = path.join(__dirname, 'fixtures', 'emulator-fixtures.json');

const VALID_ADC = {
  type: 'impersonated_service_account',
  service_account_impersonation_url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${EXPECTED_READONLY_SERVICE_ACCOUNT}:generateAccessToken`,
  source_credentials: { type: 'authorized_user' },
};

function writeAdcFixture(dir, payload = VALID_ADC) {
  const file = path.join(dir, 'application_default_credentials.json');
  fs.writeFileSync(file, JSON.stringify(payload), 'utf8');
  return file;
}

describe('production read-only ADC gates', () => {
  it('rejects PRODUCTION_READONLY_CREDENTIALS env', () => {
    const prev = process.env.PRODUCTION_READONLY_CREDENTIALS;
    process.env.PRODUCTION_READONLY_CREDENTIALS = 'C:\\outside\\key.json';
    try {
      assert.throws(() => assertNoLegacyCredentialEnv(), /PRODUCTION_READONLY_CREDENTIALS/);
    } finally {
      if (prev) process.env.PRODUCTION_READONLY_CREDENTIALS = prev;
      else delete process.env.PRODUCTION_READONLY_CREDENTIALS;
    }
  });

  it('rejects GOOGLE_APPLICATION_CREDENTIALS env', () => {
    const prev = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    process.env.GOOGLE_APPLICATION_CREDENTIALS = 'C:\\outside\\key.json';
    try {
      assert.throws(() => assertNoLegacyCredentialEnv(), /GOOGLE_APPLICATION_CREDENTIALS/);
    } finally {
      if (prev) process.env.GOOGLE_APPLICATION_CREDENTIALS = prev;
      else delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    }
  });

  it('accepts impersonated_service_account ADC fixture', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'adc-ok-'));
    const adcFile = writeAdcFixture(tmp);
    const info = resolveReadonlyAdc({ adcFilePath: adcFile });
    assert.equal(info.authMethod, 'application_default_credentials');
    assert.equal(info.serviceAccountEmail, EXPECTED_READONLY_SERVICE_ACCOUNT);
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('rejects ADC type service_account (JSON key)', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'adc-sa-'));
    const adcFile = writeAdcFixture(tmp, {
      type: 'service_account',
      client_email: 'firebase-adminsdk@test.iam.gserviceaccount.com',
      private_key: 'hidden',
    });
    assert.throws(
      () => resolveReadonlyAdc({ adcFilePath: adcFile }),
      /service_account \(JSON key\) is not allowed/,
    );
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('rejects wrong impersonated service account', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'adc-bad-'));
    const adcFile = writeAdcFixture(tmp, {
      type: 'impersonated_service_account',
      service_account_impersonation_url:
        'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/wrong@example.iam.gserviceaccount.com:generateAccessToken',
    });
    assert.throws(() => resolveReadonlyAdc({ adcFilePath: adcFile }), /must target/);
    fs.rmSync(tmp, { recursive: true, force: true });
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

  it('rejects --credentials flag', () => {
    const { spawnSync } = require('node:child_process');
    const result = spawnSync(
      process.execPath,
      [
        path.join(__dirname, 'production_readonly_inventory.js'),
        '--credentials',
        'C:\\temp\\key.json',
      ],
      { encoding: 'utf8' },
    );
    assert.notEqual(result.status, 0);
    assert.match(result.stderr + result.stdout, /--credentials is not supported/);
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

describe('production admin initialization (mocked)', () => {
  it('uses applicationDefault and never credential.cert', async () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'adc-init-'));
    const adcFile = writeAdcFixture(tmp);

    let certCalls = 0;
    let adcCalls = 0;
    const mockCredential = { kind: 'adc-mock' };
    const mockAdmin = {
      apps: [],
      credential: {
        cert: () => {
          certCalls += 1;
          return {};
        },
        applicationDefault: () => {
          adcCalls += 1;
          return mockCredential;
        },
      },
      initializeApp: (cfg) => {
        assert.equal(cfg.projectId, 'sistema-integrado-sindicato');
        assert.equal(cfg.credential, mockCredential);
      },
    };

    const { credentialInfo } = await initializeReadonlyAdmin('sistema-integrado-sindicato', {
      adcFilePath: adcFile,
      admin: mockAdmin,
    });

    assert.equal(certCalls, 0);
    assert.equal(adcCalls, 1);
    assert.equal(credentialInfo.serviceAccountEmail, EXPECTED_READONLY_SERVICE_ACCOUNT);
    fs.rmSync(tmp, { recursive: true, force: true });
  });
});

describe('legacy production guard', () => {
  it('blocks legacy script from reading production without fixtures', () => {
    assert.throws(
      () =>
        assertLegacyNotProductionLive({
          useFixtures: false,
          emulator: false,
          projectId: 'sistema-integrado-sindicato',
        }),
      /Legacy dry-run cannot read production/,
    );
  });

  it('allows legacy script with fixtures', () => {
    assert.doesNotThrow(() =>
      assertLegacyNotProductionLive({
        useFixtures: true,
        emulator: false,
        projectId: 'sistema-integrado-sindicato',
      }),
    );
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
        type: 'impersonated_service_account',
        serviceAccountEmail: EXPECTED_READONLY_SERVICE_ACCOUNT,
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
    assert.ok(!raw.includes('sindicat-migration-readonly@'));
    assert.equal(maskEmail('readonly@test.com').includes('***'), true);
    fs.rmSync(tmp, { recursive: true, force: true });
  });
});

describe('project and emulator guards', () => {
  it('asserts project match', () => {
    assert.throws(() => assertProjectMatch('a', 'b'), /Project mismatch/);
  });

  it('blocks emulator host in production mode', () => {
    const prev = process.env.FIRESTORE_EMULATOR_HOST;
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    assert.throws(() => assertNotEmulator(), /FIRESTORE_EMULATOR_HOST/);
    if (prev) process.env.FIRESTORE_EMULATOR_HOST = prev;
    else delete process.env.FIRESTORE_EMULATOR_HOST;
  });
});
