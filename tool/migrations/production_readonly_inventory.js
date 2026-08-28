#!/usr/bin/env node
'use strict';

/**
 * Production read-only Firestore inventory — Phase 4.1B.
 *
 * SECURITY LAYERS:
 * 1. Dedicated read-only service account (PRODUCTION_READONLY_CREDENTIALS)
 * 2. Separate script (no --apply path)
 * 3. Readonly Firestore proxy blocks writes
 * 4. --apply not supported
 * 5. Project + explicit confirmation gates
 * 6. Sanitized local reports (gitignored)
 */

const path = require('path');
const {
  EXPECTED_PROJECT,
  resolveReadonlyCredentials,
  assertProjectMatch,
  assertNotEmulator,
} = require('./lib/credential-guard');
const { loadProductionSnapshots } = require('./lib/production-reader');
const { buildProductionMetrics, compareRuns } = require('./lib/production-metrics');
const { writeProductionReport } = require('./lib/production-report');
const {
  createReadonlyFirestore,
  resetAudit,
  getAudit,
} = require('./lib/readonly-firestore');

const REPO_ROOT = path.resolve(__dirname, '..', '..');

function parseArgs(argv) {
  const args = {
    productionReadonly: false,
    confirmReadonlyAnalysis: false,
    projectId: '',
    doubleRun: false,
    outputDir: path.join(__dirname, 'migration-reports'),
    credentialsPath: process.env.PRODUCTION_READONLY_CREDENTIALS || '',
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--production-readonly') {
      args.productionReadonly = true;
    } else if (arg === '--confirm-readonly-analysis') {
      args.confirmReadonlyAnalysis = true;
    } else if (arg === '--project' && argv[i + 1]) {
      args.projectId = argv[++i];
    } else if (arg === '--double-run') {
      args.doubleRun = true;
    } else if (arg === '--output' && argv[i + 1]) {
      args.outputDir = path.resolve(argv[++i]);
    } else if (arg === '--credentials' && argv[i + 1]) {
      args.credentialsPath = argv[++i];
    } else if (arg === '--apply') {
      throw new Error('--apply is PROHIBITED in Phase 4.1B. Use Phase 4.1C when authorized.');
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`Production read-only inventory (Phase 4.1B)

Required flags for production:
  --production-readonly
  --project sistema-integrado-sindicato
  --confirm-readonly-analysis

Environment:
  PRODUCTION_READONLY_CREDENTIALS=/path/outside/repo/readonly-sa.json

Optional:
  --double-run              Run analysis twice and compare fingerprints
  --output <dir>            Report directory (default: tool/migrations/migration-reports)
  --credentials <path>      Override credentials path

PROHIBITED:
  --apply
  FIRESTORE_EMULATOR_HOST (must be unset)
`);
}

function validateGates(args) {
  if (!args.productionReadonly) {
    throw new Error('Missing --production-readonly gate.');
  }
  if (!args.confirmReadonlyAnalysis) {
    throw new Error('Missing --confirm-readonly-analysis gate.');
  }
  if (!args.projectId) {
    throw new Error('Missing --project sistema-integrado-sindicato');
  }
  if (args.projectId !== EXPECTED_PROJECT) {
    throw new Error(
      `Project mismatch. Expected: ${EXPECTED_PROJECT}. Provided: ${args.projectId}`,
    );
  }
  assertNotEmulator();
}

async function runAnalysis(args, credentialInfo) {
  resetAudit();

  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialInfo.credentialsPath;

  const admin = require('firebase-admin');
  for (const app of admin.apps) {
    if (app) await app.delete();
  }

  const serviceAccount = require(credentialInfo.credentialsPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: args.projectId,
  });

  const rawDb = admin.firestore();
  const db = createReadonlyFirestore(rawDb);

  assertProjectMatch(EXPECTED_PROJECT, args.projectId);

  console.log('Proyecto esperado:', EXPECTED_PROJECT);
  console.log('Proyecto detectado:', args.projectId);
  console.log('Modo: READ-ONLY');
  console.log('Identidad (SA):', credentialInfo.serviceAccountEmail);

  const startedAt = new Date().toISOString();
  const snapshots = await loadProductionSnapshots(db);
  const finishedAt = new Date().toISOString();
  const metrics = buildProductionMetrics(snapshots);
  const audit = getAudit();

  return {
    mode: 'production-readonly',
    projectId: args.projectId,
    startedAt,
    finishedAt,
    identity: {
      type: 'service_account',
      serviceAccountEmail: credentialInfo.serviceAccountEmail,
      projectId: args.projectId,
      canRead: true,
      canWrite: false,
      acceptedReadonlyRoles: credentialInfo.acceptedReadonlyRoles,
      iamVerifiedManually: true,
    },
    metrics,
    security: {
      writesAttempted: audit.writesAttempted,
      deletesAttempted: audit.deletesAttempted,
      applyExecuted: false,
    },
  };
}

async function main() {
  const args = parseArgs(process.argv);
  validateGates(args);

  const credentialInfo = resolveReadonlyCredentials({
    repoRoot: REPO_ROOT,
    credentialsPath: args.credentialsPath,
  });

  console.log('\n=== PRODUCTION READ-ONLY INVENTORY ===\n');

  const first = await runAnalysis(args, credentialInfo);
  let second = null;
  let doubleRunComparison = null;

  if (args.doubleRun) {
    console.log('\n--- Segunda ejecución read-only ---\n');
    second = await runAnalysis(args, credentialInfo);
    doubleRunComparison = compareRuns(first.metrics, second.metrics);
    if (doubleRunComparison.dataChangedDuringAnalysis) {
      console.log('WARNING: DATA_CHANGED_DURING_ANALYSIS');
    }
  }

  const report = {
    ...first,
    doubleRun: args.doubleRun
      ? {
          firstFingerprint: first.metrics.snapshotFingerprint,
          secondFingerprint: second?.metrics.snapshotFingerprint ?? null,
          comparison: doubleRunComparison,
        }
      : null,
    backup: {
      available: 'REQUIRES_ADMIN_VERIFICATION',
      executed: false,
      verified: false,
      restorationDocumented: true,
      note: 'See docs/migrations/production-readonly-inventory.md — backup identity is separate from inventory identity.',
    },
  };

  const paths = writeProductionReport(report, { outputDir: args.outputDir });

  console.log('\n=== METRICS SUMMARY ===');
  console.log(JSON.stringify(report.metrics.collectionCounts, null, 2));
  console.log('\nSecurity:', JSON.stringify(report.security, null, 2));
  console.log(`\nReports (local, gitignored):\n  ${paths.jsonPath}\n  ${paths.csvPath}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
