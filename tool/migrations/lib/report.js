'use strict';

const fs = require('fs');
const path = require('path');

/**
 * @param {Record<string, unknown>} report
 * @param {{ outputDir?: string }} options
 */
function writeReport(report, options = {}) {
  const outputDir = options.outputDir ?? path.join(process.cwd(), 'migration-reports');
  fs.mkdirSync(outputDir, { recursive: true });

  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, '')
    .replace(/\..+/, '')
    .replace('T', '-');
  const baseName = `legacy-attendance-dry-run-${stamp}`;
  const jsonPath = path.join(outputDir, `${baseName}.json`);

  const sanitized = sanitizeReport(report);
  fs.writeFileSync(jsonPath, JSON.stringify(sanitized, null, 2), 'utf8');

  const csvPath = path.join(outputDir, `${baseName}-summary.csv`);
  fs.writeFileSync(csvPath, metricsToCsv(sanitized.metrics), 'utf8');

  return { jsonPath, csvPath };
}

/**
 * Elimina datos sensibles completos de ejemplos.
 * @param {Record<string, unknown>} report
 */
function sanitizeReport(report) {
  const clone = JSON.parse(JSON.stringify(report));
  if (clone.analysis?.personaResults) {
    clone.analysis.personaResults = clone.analysis.personaResults.map((r) => ({
      personaId: r.personaId,
      status: r.status,
      memberIds: r.memberIds,
      reason: r.reason,
    }));
  }
  if (clone.analysis?.userResults) {
    clone.analysis.userResults = clone.analysis.userResults.map((r) => ({
      userId: r.userId,
      status: r.status,
      memberIds: r.memberIds,
      reason: r.reason,
    }));
  }
  return clone;
}

function metricsToCsv(metrics) {
  const lines = ['section,metric,value'];
  for (const [section, values] of Object.entries(metrics)) {
    for (const [key, value] of Object.entries(values)) {
      lines.push(`${section},${key},${value}`);
    }
  }
  return `${lines.join('\n')}\n`;
}

module.exports = { writeReport, sanitizeReport };
