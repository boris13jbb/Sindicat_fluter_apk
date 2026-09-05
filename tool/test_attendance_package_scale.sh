#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d node_modules ]]; then
  npm install
fi

if [[ ! -d functions/node_modules ]]; then
  npm --prefix functions ci
fi

# Functions emulator HTTP tests call resolveServerKeyPair() in the isolated
# emulator runtime — not the test process. Inject a fixture seed via
# .secret.local (gitignored); never use production secrets here.
TEST_SEED="${ATTENDANCE_QR_TEST_SEED:-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA}"
printf '%s\n' "ATTENDANCE_QR_SIGNING_PRIVATE_KEY=${TEST_SEED}" > functions/.secret.local

# Auth + Firestore + Functions: package-scale helpers and HTTP prepareOfflineEvent.
# --test-concurrency=1 avoids shared emulator state races between suites.
firebase emulators:exec \
  --project demo-sindicat-attendance-qr-v2 \
  --only auth,firestore,functions \
  "cd functions && node --test --test-concurrency=1 attendance-qr-package-scale.test.js attendance-qr.http.integration.test.js attendance-scanner-provisioning.emulator.test.js"
