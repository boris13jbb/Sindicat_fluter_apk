'use strict';

const { MIGRATION_VERSION } = require('./constants');
const { analyzeInventory, summarizeMetrics } = require('./inventory');

/**
 * Plan de migración sin escrituras (dry-run).
 * @param {import('./inventory').analyzeInventory extends (...args: any[]) => infer R ? Parameters<typeof import('./inventory').analyzeInventory>[0] : never} snapshots
 * @param {{ apply?: boolean }} options
 */
function runDryRun(snapshots, options = {}) {
  if (options.apply) {
    throw new Error(
      'Apply mode is disabled in Phase 4.1A. Use --dry-run only.',
    );
  }

  const analysis = analyzeInventory(snapshots);
  const metrics = summarizeMetrics(analysis);

  const proposedWrites = [];
  const proposedDeletes = [];

  for (const ev of analysis.eventoResults) {
    if (ev.status === 'REQUIERE_MIGRACION') {
      proposedWrites.push({
        collection: 'attendance_events',
        docId: ev.targetEventId,
        operation: 'set',
        migrationVersion: MIGRATION_VERSION,
      });
    }
  }

  for (const row of analysis.asistenciaResults) {
    if (row.action === 'MIGRABLE') {
      proposedWrites.push({
        collection: `attendance_events/${row.targetEventId}/asistencias`,
        docId: row.targetDocId,
        operation: 'set',
        migrationVersion: MIGRATION_VERSION,
      });
    }
  }

  return {
    mode: 'dry-run',
    migrationVersion: MIGRATION_VERSION,
    metrics,
    analysis,
    proposedWrites,
    proposedDeletes,
    writeCount: proposedWrites.length,
    deleteCount: proposedDeletes.length,
  };
}

module.exports = { runDryRun };
