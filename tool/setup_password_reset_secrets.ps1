param(
    [string]$ProjectId = "sistema-integrado-sindicato"
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host ""
Write-Host "Configuracion segura de SMTP para recuperacion de contrasena" -ForegroundColor Cyan
Write-Host "No escribas la contrasena normal de Gmail. Usa una contrasena de aplicacion." -ForegroundColor Yellow
Write-Host ""

$smtpUser = Read-Host "Correo Gmail remitente (SMTP_USER)"
if ([string]::IsNullOrWhiteSpace($smtpUser)) {
    throw "SMTP_USER no puede estar vacio."
}

$securePassword = Read-Host "Contrasena de aplicacion Gmail (SMTP_PASSWORD)" -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordPtr)
if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    throw "SMTP_PASSWORD no puede estar vacio."
}

$tmpDir = Join-Path $env:TEMP ("sindicato-secrets-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$userFile = Join-Path $tmpDir "smtp_user.txt"
$passwordFile = Join-Path $tmpDir "smtp_password.txt"

try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($userFile, $smtpUser, $utf8NoBom)
    [System.IO.File]::WriteAllText($passwordFile, $plainPassword, $utf8NoBom)

    firebase functions:secrets:set SMTP_USER --project $ProjectId --data-file $userFile
    if ($LASTEXITCODE -ne 0) { throw "No se pudo guardar SMTP_USER." }

    firebase functions:secrets:set SMTP_PASSWORD --project $ProjectId --data-file $passwordFile
    if ($LASTEXITCODE -ne 0) { throw "No se pudo guardar SMTP_PASSWORD." }

    Write-Host ""
    Write-Host "Secretos configurados correctamente." -ForegroundColor Green
} finally {
    if ($passwordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
    }
    Remove-Item -LiteralPath $userFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpDir -Force -Recurse -ErrorAction SilentlyContinue
}
