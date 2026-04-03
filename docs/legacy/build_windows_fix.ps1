# Script para configurar Flutter y compilar en Windows con mirrors
# Ejecutar en PowerShell

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build Windows con Mirrors" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configurar mirrors de Flutter/China para mejor conectividad
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:STORAGE_BASE_URL = "https://storage.flutter-io.cn"

Write-Host "[1/4] Configurando mirrors de Flutter..." -ForegroundColor Yellow
Write-Host "  PUB_HOSTED_URL: $env:PUB_HOSTED_URL" -ForegroundColor Gray
Write-Host "  STORAGE_BASE_URL: $env:STORAGE_BASE_URL" -ForegroundColor Gray
Write-Host ""

Write-Host "[2/4] Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al obtener dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencias obtenidas" -ForegroundColor Green
Write-Host ""

Write-Host "[3/4] Limpiando build anterior..." -ForegroundColor Yellow
flutter clean
Write-Host "[OK] Build limpiado" -ForegroundColor Green
Write-Host ""

Write-Host "[4/4] Compilando para Windows..." -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTA: La primera compilación puede tomar varios minutos" -ForegroundColor Cyan
Write-Host ""

flutter run -d windows

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERROR: La compilación falló" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "  1. Problemas de conexión a internet" -ForegroundColor White
    Write-Host "  2. Firebase SDK no se descargó correctamente" -ForegroundColor White
    Write-Host "  3. Visual Studio no está bien configurado" -ForegroundColor White
    Write-Host ""
    Write-Host "Soluciones:" -ForegroundColor Yellow
    Write-Host "  - Verifica tu conexión a internet" -ForegroundColor White
    Write-Host "  - Ejecuta: flutter doctor -v" -ForegroundColor White
    Write-Host "  - Revisa los logs de error arriba" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ¡Compilación exitosa!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
