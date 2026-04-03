@echo off
REM ============================================
REM   Configurador Rápido de Perfil CASA
REM   Para usar Lingma sin proxy en casa
REM ============================================

echo.
echo ============================================
echo   Configurando Lingma para CASA (sin proxy)
echo ============================================
echo.

REM Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Este script necesita permisos de administrador.
    echo.
    echo Por favor, haz clic derecho en este archivo y selecciona:
    echo   "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

echo [OK] Ejecutando con permisos de administrador
echo.

REM Crear directorio de configuracion
echo Creando directorio de configuracion...
if not exist "C:\Users\boris\AppData\Local\.lingma" (
    mkdir "C:\Users\boris\AppData\Local\.lingma"
    echo [OK] Directorio creado
) else (
    echo [OK] El directorio ya existe
)
echo.

REM Crear archivo de configuracion
echo Creando archivo de configuracion...
(
echo {
echo   "http_proxy": null,
echo   "https_proxy": null,
echo   "vpn_required": false,
echo   "profile": "home",
echo   "timeout": 60000,
echo   "retry_count": 3,
echo   "last_updated": "%date% %time%"
echo }
) > "C:\Users\boris\AppData\Local\.lingma\config.json"

echo [OK] Archivo de configuracion creado
echo.

REM Verificar que se creo el archivo
if exist "C:\Users\boris\AppData\Local\.lingma\config.json" (
    echo ============================================
    echo   PERFIL CASA ACTIVADO CORRECTAMENTE
    echo ============================================
    echo.
    echo Configuracion aplicada:
    echo   - Proxy: DESACTIVADO
    echo   - VPN: NO requerida
    echo   - Timeout: 60 segundos
    echo.
    echo ============================================
    echo   PROXIMOS PASOS:
    echo ============================================
    echo.
    echo 1. Cierra completamente tu IDE (Visual Studio / IntelliJ)
    echo 2. Espera 5 segundos
    echo 3. Vuelve a abrir el IDE
    echo 4. Inicia sesion en Lingma
    echo.
    echo Si tienes problemas, abre el archivo:
    echo CONFIGURACION_CASA_LEEME.md
    echo.
    pause
) else (
    echo [ERROR] No se pudo crear el archivo de configuracion
    echo.
    echo Intenta ejecutar el script de PowerShell manualmente:
    echo .\switch-lingma-profile.ps1 -Profile home
    echo.
    pause
)
