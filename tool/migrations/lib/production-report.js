'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Escribe reporte sanitizado de inventario read-only.
 * @param {Record<string, unknown>} report
 * @param {{ outputDir?: string }} options
 */
function writeProductionReport(report, options = {}) {
  const outputDir = options.outputDir ?? path.join(process.cwd(), 'migration-reports');
  fs.mkdirSync(outputDir, { recursive: true });

  const stamp = formatStamp(new Date());
  const baseName = `production-readonly-inventory-${stamp}`;
  const jsonPath = path.join(outputDir, `${baseName}.json`);
  const csvPath = path.join(outputDir, `${baseName}.csv`);

  const sanitized = sanitizeProductionReport(report);
  fs.writeFileSync(jsonPath, JSON.stringify(sanitized, null, 2), 'utf8');
  fs.writeFileSync(csvPath, metricsToCsv(sanitized.metrics), 'utf8');

  return { jsonPath, csvPath, baseName };
}

function formatStamp(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-` +
    `${pad(date.getHours())}${pad(date.getMinutes())}`
  );
}

/**
 * @param {Record<string, unknown>} report
 */
function sanitizeProductionReport(report) {
  const clone = JSON.parse(JSON.stringify(report));
  delete clone._rawAnalysis;
  if (clone.identity) {
    clone.identity = {
      type: clone.identity.type,
      serviceAccountEmail: maskEmail(clone.identity.serviceAccountEmail),
      projectId: clone.identity.projectId,
      canRead: clone.identity.canRead,
      canWrite: clone.identity.canWrite,
      acceptedReadonlyRoles: clone.identity.acceptedReadonlyRoles,
    };
  }
  return clone;
}

/**
 * @param {string} email
 */
function maskEmail(email) {
  if (!email || typeof email !== 'string') return '';
  const [user, domain] = email.split('@');
  if (!domain) return '***';
  const visible = user.slice(0, 2);
  return `${visible}***@${domain}`;
}

/**
 * @param {Record<string, unknown>} metrics
 */
function metricsToCsv(metrics) {
  const lines = ['section,metric,value'];
  flattenMetrics('', metrics, lines);
  return `${lines.join('\n')}\n`;
}

/**
 * @param {string} prefix
 * @param {unknown} value
 * @param {string[]} lines
 */
function flattenMetrics(prefix, value, lines) {
  if (value == null) return;
  if (typeof value !== 'object' || Array.isArray(value)) {
    lines.push(`${prefix || 'root'},value,${String(value)}`);
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const section = prefix ? `${prefix}.${key}` : key;
    if (child && typeof child === 'object' && !Array.isArray(child)) {
      flattenMetrics(section, child, lines);
    } else {
      lines.push(`${section},value,${String(child)}`);
    }
  }
}

module.exports = { writeProductionReport, sanitizeProductionReport, maskEmail };
