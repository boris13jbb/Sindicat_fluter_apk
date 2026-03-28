# ============================================
# Script para ejecutar la app en Windows Desktop
# ============================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Sistema de Voto - Build Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# [1/4] Configurar Git en el PATH
Write-Host "[1/4] Configurando Git en el PATH..." -ForegroundColor Yellow
$env:Path = "C:\Program Files\Git\cmd;C:\Program Files\Git\bin;$env:Path"

# Verificar que Git este disponible
try {
    $gitVersion = git --version 2>&1
    Write-Host "[OK] Git encontrado: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se encontro Git. Por favor instalalo desde:" -ForegroundColor Red
    Write-Host "https://git-scm.com/download/win" -ForegroundColor Red
    pause
    exit 1
}

# Ir al directorio del proyecto
Set-Location $PSScriptRoot

# [2/4] Limpiar build anterior
Write-Host "[2/4] Limpiando build anterior..." -ForegroundColor Yellow
if (Test-Path "build\windows") {
    Remove-Item -Recurse -Force "build\windows"
    Write-Host "[OK] Build limpiado" -ForegroundColor Green
} else {
    Write-Host "[INFO] No hay build anterior que limpiar" -ForegroundColor Gray
}

# [3/4] Obtener dependencias
Write-Host "[3/4] Obteniendo dependencias de Flutter..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al obtener dependencias" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "[OK] Dependencias obtenidas" -ForegroundColor Green

# [4/4] Ejecutar en Windows
Write-Host "[4/4] Ejecutando en Windows Desktop..." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANTE: La primera vez puede tardar varios minutos" -ForegroundColor Yellow
Write-Host "mientras se descarga el compilador de C++ y las herramientas." -ForegroundColor Yellow
Write-Host ""

flutter run -d windows

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " ERROR: El build fallo" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Posibles soluciones:" -ForegroundColor Yellow
    Write-Host "1. Asegurate de tener Visual Studio 2022 con 'Desktop development with C++'" -ForegroundColor White
    Write-Host "2. Ejecuta: flutter doctor -v y revisa los errores" -ForegroundColor White
    Write-Host "3. Revisa BUILD_WINDOWS.md para mas informacion" -ForegroundColor White
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Aplicacion cerrada" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
