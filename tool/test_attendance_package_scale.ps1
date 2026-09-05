param()

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path 'node_modules')) {
    npm install
}

if (-not (Test-Path 'functions/node_modules')) {
    npm --prefix functions ci
}

# Functions emulator HTTP tests need signing key in emulator runtime (.secret.local).
$testSeed = if ($env:ATTENDANCE_QR_TEST_SEED) { $env:ATTENDANCE_QR_TEST_SEED } else { 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' }
Set-Content -Path 'functions\.secret.local' -Value "ATTENDANCE_QR_SIGNING_PRIVATE_KEY=$testSeed" -Encoding utf8NoBOM

$cmd = "cd functions && node --test --test-concurrency=1 attendance-qr-package-scale.test.js attendance-qr.http.integration.test.js attendance-scanner-provisioning.emulator.test.js"

firebase emulators:exec `
    --project demo-sindicat-attendance-qr-v2 `
    --only auth,firestore,functions `
    $cmd
