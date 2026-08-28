param(
    [switch]$SkipRules,
    [switch]$BuildWeb
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host "`n== $Name ==" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name falló con código $LASTEXITCODE"
    }
}

Invoke-Step 'Dependencias Flutter' { flutter pub get }
Invoke-Step 'Formato Dart modificado' {
    $dartFiles = @()
    $dartFiles += git diff --name-only -- '*.dart'
    $dartFiles += git ls-files --others --exclude-standard -- '*.dart'
    $dartFiles = $dartFiles | Where-Object { $_ } | Sort-Object -Unique
    if ($dartFiles.Count -gt 0) {
        & dart format --output=none --set-exit-if-changed @dartFiles
    }
}
Invoke-Step 'Análisis estático' { dart analyze lib test }
Invoke-Step 'Higiene Git' { git -c core.whitespace=cr-at-eol diff --check }

# Flutter 3.44.0 usa dot-shorthands internamente, pero el runner actual aún
# requiere activar explícitamente el experimento al compilar pruebas.
Invoke-Step 'Pruebas Flutter' {
    flutter test --no-pub --enable-experiment=dot-shorthands --reporter compact
}

Invoke-Step 'Reglas Firestore (dry-run)' {
    firebase deploy --only firestore:rules,firestore:indexes --dry-run
}
Invoke-Step 'Reglas Storage (dry-run)' {
    firebase deploy --only storage --dry-run
}

if (-not $SkipRules) {
    Invoke-Step 'Pruebas Firebase Emulator' { & .\tool\test_firebase_rules.ps1 }
}

Invoke-Step 'Migration tests (fixtures)' {
    Push-Location (Join-Path $PSScriptRoot 'migrations')
    try {
        if (Test-Path 'package-lock.json') {
            npm ci
        } else {
            npm install
        }
        npm test
    } finally {
        Pop-Location
    }
}

if ($BuildWeb) {
    Invoke-Step 'Build Web release' { flutter build web --release }
}

Write-Host "`nVerificación completada correctamente." -ForegroundColor Green
