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

# Auth + Firestore + Functions: package-scale helpers and HTTP prepareOfflineEvent.
# --test-concurrency=1 avoids shared emulator state races between suites.
firebase emulators:exec \
  --project demo-sindicat-attendance-qr-v2 \
  --only auth,firestore,functions \
  "cd functions && node --test --test-concurrency=1 attendance-qr-package-scale.test.js attendance-qr.http.integration.test.js"
