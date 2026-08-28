'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const EXPECTED_PROJECT = 'sistema-integrado-sindicato';

const EXPECTED_READONLY_SERVICE_ACCOUNT =
  'sindicat-migration-readonly@sistema-integrado-sindicato.iam.gserviceaccount.com';

/** Roles IAM de solo lectura aceptados para inventario (nombres oficiales GCP). */
const ACCEPTED_READONLY_ROLES = ['roles/datastore.viewer'];

const FORBIDDEN_SERVICE_ACCOUNT_PATTERNS = [
  /@developer\.gserviceaccount\.com$/i,
  /^firebase-adminsdk-/i,
  /@appspot\.gserviceaccount\.com$/i,
];

/**
 * Directorio de configuración gcloud (sin rutas personales hardcodeadas).
 */
function resolveGcloudConfigDir() {
  if (process.env.CLOUDSDK_CONFIG) {
    return path.resolve(process.env.CLOUDSDK_CONFIG);
  }
  if (process.platform === 'win32') {
    const appData =
      process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
    return path.join(appData, 'gcloud');
  }
  return path.join(os.homedir(), '.config', 'gcloud');
}

/**
 * Ruta estándar del archivo ADC local.
 */
function getApplicationDefaultCredentialsPath() {
  return path.join(resolveGcloudConfigDir(), 'application_default_credentials.json');
}

/**
 * Rechaza mecanismos legacy de credenciales JSON para el inventario oficial.
 */
function assertNoLegacyCredentialEnv() {
  if (process.env.PRODUCTION_READONLY_CREDENTIALS) {
    throw new Error(
      'PRODUCTION_READONLY_CREDENTIALS is not supported. Use Application Default Credentials with service account impersonation.',
    );
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error(
      'GOOGLE_APPLICATION_CREDENTIALS must be unset for production read-only inventory. Use ADC impersonation instead.',
    );
  }
}

/**
 * Valida metadatos no secretos del archivo ADC local (sin red).
 * @param {{ adcFilePath?: string }} options
 */
function resolveReadonlyAdc(options = {}) {
  assertNoLegacyCredentialEnv();

  const adcFilePath = options.adcFilePath || getApplicationDefaultCredentialsPath();

  if (!fs.existsSync(adcFilePath)) {
    throw new Error(
      `Application Default Credentials file not found: ${adcFilePath}. Run gcloud auth application-default login with service account impersonation.`,
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(adcFilePath, 'utf8'));
  } catch {
    throw new Error('Application Default Credentials file is not valid JSON.');
  }

  if (parsed.type === 'service_account') {
    throw new Error(
      'ADC type service_account (JSON key) is not allowed. Use impersonated_service_account via gcloud ADC.',
    );
  }

  if (parsed.type !== 'impersonated_service_account') {
    throw new Error(
      `ADC type must be impersonated_service_account. Found: ${parsed.type || 'unknown'}.`,
    );
  }

  const impersonationUrl = String(parsed.service_account_impersonation_url || '');
  if (!impersonationUrl.includes(EXPECTED_READONLY_SERVICE_ACCOUNT)) {
    throw new Error(
      `ADC impersonation must target ${EXPECTED_READONLY_SERVICE_ACCOUNT}.`,
    );
  }

  for (const pattern of FORBIDDEN_SERVICE_ACCOUNT_PATTERNS) {
    if (pattern.test(impersonationUrl)) {
      throw new Error('ADC impersonation URL matches a forbidden service account pattern.');
    }
  }

  return {
    authMethod: 'application_default_credentials',
    adcType: parsed.type,
    serviceAccountEmail: EXPECTED_READONLY_SERVICE_ACCOUNT,
    adcFilePath,
    acceptedReadonlyRoles: ACCEPTED_READONLY_ROLES,
    note:
      'IAM role binding (roles/datastore.viewer) must be verified in GCP Console. This script does not query IAM.',
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

/**
 * Impide que el script legacy contacte producción sin fixtures/emulador.
 * @param {{ useFixtures?: boolean, emulator?: boolean, projectId?: string }} args
 */
function assertLegacyNotProductionLive(args) {
  if (args.useFixtures || args.emulator) return;
  if (args.projectId === EXPECTED_PROJECT) {
    throw new Error(
      'Legacy dry-run cannot read production Firestore. Use production_readonly_inventory.js with ADC gates, or --use-fixtures.',
    );
  }
}

module.exports = {
  EXPECTED_PROJECT,
  EXPECTED_READONLY_SERVICE_ACCOUNT,
  ACCEPTED_READONLY_ROLES,
  resolveGcloudConfigDir,
  getApplicationDefaultCredentialsPath,
  assertNoLegacyCredentialEnv,
  resolveReadonlyAdc,
  assertProjectMatch,
  assertNotEmulator,
  assertLegacyNotProductionLive,
};
