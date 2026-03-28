@echo off
REM ============================================
REM Script para diagnosticar problemas en Windows
REM ============================================

echo.
echo ========================================
echo  DIAGNOSTICO - Sistema de Voto Windows
echo ========================================
echo.

cd /d "%~dp0"

echo [1/5] Verificando Flutter...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter no esta instalado o no esta en el PATH
    pause
    exit /b 1
)
echo.

echo [2/5] Verificando dispositivos disponibles...
flutter devices
echo.

echo [3/5] Obteniendo dependencias...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Fallo al obtener dependencias
    pause
    exit /b 1
)
echo.

echo [4/5] Verificando configuracion del proyecto...
flutter doctor -v
echo.

echo [5/5] Limpiando build anterior...
flutter clean
if exist "build\windows" (
    rmdir /s /q "build\windows"
    echo [OK] Build limpiado
)
echo.

echo ========================================
echo DIAGNOSTICO COMPLETADO
echo ========================================
echo.
echo Ahora puedes intentar ejecutar la aplicacion con:
echo   run_windows.bat
echo.
echo O en modo debug con logging:
echo   flutter run -d windows --verbose
echo.
pause
