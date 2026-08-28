'use strict';

const fs = require('fs');
const path = require('path');

const EXPECTED_PROJECT = 'sistema-integrado-sindicato';

/** Roles IAM de solo lectura aceptados para inventario (nombres oficiales GCP). */
const ACCEPTED_READONLY_ROLES = ['roles/datastore.viewer'];

/**
 * Valida credenciales fuera del repositorio para inventario read-only.
 * @param {{ repoRoot: string, credentialsPath?: string }} options
 */
function resolveReadonlyCredentials(options) {
  const credentialsPath =
    options.credentialsPath ||
    process.env.PRODUCTION_READONLY_CREDENTIALS ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    '';

  if (!credentialsPath) {
    throw new Error(
      'Missing read-only credentials. Set PRODUCTION_READONLY_CREDENTIALS to a service account JSON path outside the repository.',
    );
  }

  const resolved = path.resolve(credentialsPath);
  const repoRoot = path.resolve(options.repoRoot);

  if (!fs.existsSync(resolved)) {
    throw new Error(`Credentials file not found: ${resolved}`);
  }

  if (resolved.startsWith(repoRoot + path.sep) || resolved === repoRoot) {
    throw new Error('Credentials must not be stored inside the repository.');
  }

  const forbiddenNames = [
    'service-account.json',
    'firebase-admin-key.json',
    'credentials.json',
  ];
  if (forbiddenNames.includes(path.basename(resolved).toLowerCase())) {
    throw new Error(
      'Use a dedicated read-only service account file outside the repo with a non-generic filename.',
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(resolved, 'utf8'));
  } catch {
    throw new Error('Credentials file is not valid JSON.');
  }

  if (parsed.type !== 'service_account' || !parsed.client_email || !parsed.project_id) {
    throw new Error('Credentials must be a Google service account JSON key.');
  }

  return {
    credentialsPath: resolved,
    serviceAccountEmail: parsed.client_email,
    keyProjectId: parsed.project_id,
    acceptedReadonlyRoles: ACCEPTED_READONLY_ROLES,
    note:
      'IAM role binding must be verified in GCP Console. This script does not modify IAM.',
  };
}

/**
 * @param {string} expectedProject
 * @param {string} detectedProject
 */
function assertProjectMatch(expectedProject, detectedProject) {
  if (expectedProject !== detectedProject) {
    throw new Error(
      `Project mismatch. Expected: ${expectedProject}. Detected: ${detectedProject}. Aborting.`,
    );
  }
}

/**
 * Bloquea ejecución accidental contra emulador en modo producción.
 */
function assertNotEmulator() {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is set. Unset it before production read-only analysis.',
    );
  }
}

module.exports = {
  EXPECTED_PROJECT,
  ACCEPTED_READONLY_ROLES,
  resolveReadonlyCredentials,
  assertProjectMatch,
  assertNotEmulator,
};
