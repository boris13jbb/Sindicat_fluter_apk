#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d node_modules ]]; then
  npm install
fi

firebase emulators:exec \
  --project sindicat-rules-test \
  --only firestore,storage \
  "npm run test:rules"
