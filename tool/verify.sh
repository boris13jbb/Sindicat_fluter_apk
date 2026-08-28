#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKIP_RULES=0
BUILD_WEB=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-rules)
      SKIP_RULES=1
      shift
      ;;
    --build-web)
      BUILD_WEB=1
      shift
      ;;
    *)
      echo "Uso: $0 [--skip-rules] [--build-web]" >&2
      exit 1
      ;;
  esac
done

run_step() {
  local name="$1"
  shift
  echo ""
  echo "== $name =="
  "$@"
}

run_step "Dependencias Flutter" flutter pub get

run_step "Formato Dart" dart format --output=none --set-exit-if-changed lib test

run_step "Análisis estático" dart analyze lib test

run_step "Higiene Git" git -c core.whitespace=cr-at-eol diff --check

run_step "Pruebas Flutter" \
  flutter test --no-pub --enable-experiment=dot-shorthands --reporter compact

run_step "Cloud Functions" bash -c 'cd functions && npm ci && npm run check'

if [[ "$SKIP_RULES" -eq 0 ]]; then
  run_step "Pruebas Firebase Emulator" bash tool/test_firebase_rules.sh
fi

if [[ "$BUILD_WEB" -eq 1 ]]; then
  run_step "Build Web release" flutter build web --release
fi

echo ""
echo "Verificación completada correctamente."
