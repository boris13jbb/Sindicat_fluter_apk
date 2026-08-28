#!/usr/bin/env node
'use strict';

/**
 * Legacy attendance migration CLI — Phase 4.1A (dry-run only).
 *
 * Default mode: DRY RUN (no writes).
 * Apply mode is gated and NOT enabled in this phase.
 */

const path = require('path');
const { MIGRATION_VERSION } = require('./lib/constants');
const { runDryRun } = require('./lib/dry-run');
const { writeReport } = require('./lib/report');
const {
  loadFixtures,
  loadFromFirestore,
  defaultFixturePath,
} = require('./lib/firestore-reader');

function parseArgs(argv) {
  const args = {
    dryRun: true,
    apply: false,
    useFixtures: false,
    fixturePath: defaultFixturePath(),
    projectId: process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || '',
    emulator: Boolean(process.env.FIRESTORE_EMULATOR_HOST),
    confirmMigration: false,
    outputDir: path.join(process.cwd(), 'migration-reports'),
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      args.dryRun = true;
      args.apply = false;
    } else if (arg === '--apply') {
      args.apply = true;
      args.dryRun = false;
    } else if (arg === '--use-fixtures') {
      args.useFixtures = true;
    } else if (arg === '--fixture' && argv[i + 1]) {
      args.fixturePath = path.resolve(argv[++i]);
      args.useFixtures = true;
    } else if (arg === '--project' && argv[i + 1]) {
      args.projectId = argv[++i];
    } else if (arg === '--confirm-migration') {
      args.confirmMigration = true;
    } else if (arg === '--output' && argv[i + 1]) {
      args.outputDir = path.resolve(argv[++i]);
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      printHelp();
      process.exit(1);
    }
  }

  return args;
}

function printHelp() {
  console.log(`Legacy attendance migration (${MIGRATION_VERSION})

Usage:
  node legacy_attendance_migration.js [options]

Options:
  --dry-run                 Simulate only (default)
  --use-fixtures            Use local emulator fixtures JSON
  --fixture <path>          Custom fixtures file
  --project <id>            Firebase project (read-only inventory)
  --output <dir>            Report output directory

Apply mode (DISABLED in Phase 4.1A):
  --apply --project <id> --confirm-migration
`);
}

function validateApplyGate(args) {
  if (!args.apply) return;

  const errors = [];
  if (!args.confirmMigration) {
    errors.push('Missing --confirm-migration');
  }
  if (!args.projectId) {
    errors.push('Missing --project <project-id>');
  }
  if (args.projectId !== 'sistema-integrado-sindicato') {
    errors.push('Unexpected project id for apply mode');
  }

  if (errors.length) {
    throw new Error(`Apply mode blocked: ${errors.join('; ')}`);
  }

  throw new Error(
    'Apply mode is not implemented in Phase 4.1A. Dry-run only.',
  );
}

async function main() {
  const args = parseArgs(process.argv);
  validateApplyGate(args);

  /** @type {import('./lib/firestore-reader').normalizeSnapshots extends never ? any : ReturnType<typeof loadFixtures>} */
  let snapshots;

  if (args.useFixtures) {
    snapshots = loadFixtures(args.fixturePath);
    console.log(`Loaded fixtures: ${args.fixturePath}`);
  } else {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: args.projectId || 'demo-sindicat-migration',
      });
    }
    const db = admin.firestore();
    if (args.emulator) {
      console.log(`Reading from Firestore emulator: ${process.env.FIRESTORE_EMULATOR_HOST}`);
    } else if (args.projectId) {
      console.log(`READ-ONLY inventory for project: ${args.projectId}`);
    } else {
      throw new Error('Specify --use-fixtures or set FIRESTORE_EMULATOR_HOST / --project');
    }
    snapshots = await loadFromFirestore(db);
  }

  const report = runDryRun(snapshots, { apply: false });
  const paths = writeReport(report, { outputDir: args.outputDir });

  console.log('\n=== DRY-RUN SUMMARY ===');
  console.log(JSON.stringify(report.metrics, null, 2));
  console.log(`\nProposed writes: ${report.writeCount}`);
  console.log(`Proposed deletes: ${report.deleteCount}`);
  console.log(`Reports:\n  ${paths.jsonPath}\n  ${paths.csvPath}`);

  if (report.writeCount !== 0 || report.deleteCount !== 0) {
    console.log('\nNote: proposed operations are simulated only (no Firestore writes).');
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
