@echo off
REM ============================================
REM Script para ejecutar la app en Windows Desktop
REM ============================================

echo.
echo ========================================
echo  Sistema de Voto - Build Windows
echo ========================================
echo.

REM Asegura que Git este en el PATH para el build de Windows (MSBuild lo necesita)
echo [1/4] Configurando Git en el PATH...
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"

REM Verificar que Git este disponible
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: No se encontro Git. Por favor instalalo desde:
    echo https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)
echo [OK] Git encontrado

REM Ir al directorio del proyecto
cd /d "%~dp0"

REM Limpiar build anterior si existe
echo [2/4] Limpiando build anterior...
if exist "build\windows" (
    rmdir /s /q "build\windows"
    echo [OK] Build limpiado
) else (
    echo [INFO] No hay build anterior que limpiar
)

REM Obtener dependencias
echo [3/4] Obteniendo dependencias de Flutter...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Fallo al obtener dependencias
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas

REM Ejecutar en Windows con logging detallado
echo [4/4] Ejecutando en Windows Desktop...
echo.
echo IMPORTANTE: La primera vez puede tardar varios minutos
echo mientras se descarga el compilador de C++ y las herramientas.
echo.
echo ========================================
echo INICIANDO APLICACION CON LOGGING DETALLADO
echo ========================================
echo.

REM Habilitar logging de Flutter para debugging
set FLUTTER_ENABLE_LOGGING=1

REM Ejecutar con verbose mode para ver errores detallados
flutter run -d windows --verbose

if %errorlevel% neq 0 (
    echo.
    echo ========================================
    echo ERROR: El build fallo
    echo ========================================
    echo.
    echo Posibles soluciones:
    echo 1. Asegurate de tener Visual Studio 2022 con "Desktop development with C++"
    echo 2. Ejecuta: flutter doctor -v y revisa los errores
    echo 3. Revisa BUILD_WINDOWS.md para mas informacion
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Aplicacion cerrada
echo ========================================
pause
