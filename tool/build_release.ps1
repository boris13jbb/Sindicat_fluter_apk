param(
    [switch]$Android,
    [switch]$Web,
    [switch]$Windows,
    [switch]$All,
    [switch]$AllowDebugAndroidSigning
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not ($Android -or $Web -or $Windows -or $All)) {
    $All = $true
}

$buildAndroid = $Android -or $All
$buildWeb = $Web -or $All
$buildWindows = $Windows -or $All

function Invoke-Build {
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

if ($buildAndroid) {
    $keyPropertiesPath = Join-Path (Get-Location) 'android\key.properties'
    if (-not (Test-Path $keyPropertiesPath) -and -not $AllowDebugAndroidSigning) {
        throw @"
Build Android productivo bloqueado: falta android/key.properties.
Usa android/key.properties.example como plantilla.
Para validar localmente con firma debug explícita, agrega -AllowDebugAndroidSigning.
"@
    }
}

Invoke-Build 'Dependencias Flutter' { flutter pub get }

if ($buildAndroid) {
    $androidStudioJbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $androidStudioJbr) {
        $env:JAVA_HOME = $androidStudioJbr
        $env:Path = "$androidStudioJbr\bin;$env:Path"
    }

    $previousGradleOpts = $env:GRADLE_OPTS
    $previousDebugSigning = $env:ALLOW_DEBUG_RELEASE_SIGNING
    try {
        $env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
        if ($AllowDebugAndroidSigning) {
            $env:ALLOW_DEBUG_RELEASE_SIGNING = 'true'
            Write-Warning 'Los artefactos Android se firmarán con clave debug y sólo sirven para QA.'
        } else {
            Remove-Item Env:ALLOW_DEBUG_RELEASE_SIGNING -ErrorAction SilentlyContinue
        }

        Invoke-Build 'Android APK release' { flutter build apk --release --no-pub }
        Invoke-Build 'Android App Bundle release' { flutter build appbundle --release --no-pub }
    } finally {
        $env:GRADLE_OPTS = $previousGradleOpts
        $env:ALLOW_DEBUG_RELEASE_SIGNING = $previousDebugSigning
    }
}

if ($buildWeb) {
    Invoke-Build 'Web release' { flutter build web --release --no-pub }
}

if ($buildWindows) {
    Invoke-Build 'Windows release' { flutter build windows --release --no-pub }
}

Write-Host "`nBuilds release completados correctamente." -ForegroundColor Green
