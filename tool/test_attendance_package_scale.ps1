param()

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path 'node_modules')) {
    npm install
}

if (-not (Test-Path 'functions/node_modules')) {
    npm --prefix functions ci
}

$cmd = "cd functions && node --test --test-concurrency=1 attendance-qr-package-scale.test.js attendance-qr.http.integration.test.js"

firebase emulators:exec `
    --project demo-sindicat-attendance-qr-v2 `
    --only auth,firestore,functions `
    $cmd
