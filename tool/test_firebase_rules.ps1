$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$androidStudioJava = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path (Join-Path $androidStudioJava 'bin\java.exe')) {
    $env:JAVA_HOME = $androidStudioJava
    $env:Path = "$(Join-Path $androidStudioJava 'bin');$env:Path"
}

if (-not (Test-Path 'node_modules')) {
    npm install
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

firebase emulators:exec --project sindicat-rules-test --only firestore,storage "npm run test:rules"
exit $LASTEXITCODE
