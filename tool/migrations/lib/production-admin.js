'use strict';

const { resolveReadonlyAdc } = require('./credential-guard');

/**
 * Inicializa Firebase Admin con ADC (applicationDefault).
 * @param {string} projectId
 * @param {{ adcFilePath?: string, admin?: import('firebase-admin') }} options
 */
async function initializeReadonlyAdmin(projectId, options = {}) {
  const credentialInfo = resolveReadonlyAdc(options);
  const admin = options.admin || require('firebase-admin');

  for (const app of admin.apps) {
    if (app) {
      await app.delete();
    }
  }

  const credential = admin.credential.applicationDefault();
  admin.initializeApp({
    credential,
    projectId,
  });

  return { admin, credentialInfo, credential };
}

module.exports = { initializeReadonlyAdmin };
