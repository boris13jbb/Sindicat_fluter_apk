@echo off
REM ============================================
REM   Configurador Lingma con ZenVPN
REM   Para usuarios que requieren VPN obligatoria
REM ============================================

echo.
echo ============================================
echo     CONFIGURADOR LINGMA - ZENVPN
echo ============================================
echo.

REM Verificar permisos de administrador
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

REM Menú de opciones
echo ============================================
echo     SELECCIONA TU CONFIGURACION
echo ============================================
echo.
echo 1. CASA sin VPN (conexion directa a internet)
echo    - Recomendado si puedes acceder a internet normalmente
echo    - Sin VPN, sin proxy
echo.
echo 2. CASA con ZenVPN obligatorio
echo    - Solo si tu empresa requiere VPN siempre
echo    - Debes tener ZenVPN instalado y conectado
echo.
echo 3. OFICINA (VPN + Proxy corporativo)
echo    - Cuando estés físicamente en la oficina
echo    - Requiere configuración manual del proxy
echo.

set /p opcion="Elige una opción (1-3): "

if "%opcion%"=="1" goto CONFIG_CASA
if "%opcion%"=="2" goto CONFIG_VPN
if "%opcion%"=="3" goto CONFIG_OFICINA

echo.
echo [ERROR] Opción no válida. Debe ser 1, 2 o 3.
pause
exit /b 1

:CONFIG_CASA
echo.
echo ============================================
echo   OPCION 1: CASA SIN VPN
echo ============================================
echo.
echo Configurando perfil CASA (sin VPN, sin proxy)...
echo.

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

if exist "C:\Users\boris\AppData\Local\.lingma\config.json" (
    echo [OK] Archivo de configuracion creado exitosamente
    echo.
    echo Configuracion aplicada:
    echo   ✓ Proxy: DESACTIVADO
    echo   ✓ VPN: NO requerida
    echo   ✓ Timeout: 60 segundos
    echo   ✓ Reintentos: 3
    echo.
    goto FIN
) else (
    echo [ERROR] No se pudo crear el archivo
    pause
    exit /b 1
)

:CONFIG_VPN
echo.
echo ============================================
echo   OPCION 2: CASA CON ZENVPN
echo ============================================
echo.
echo IMPORTANTE: Esta configuración asume que:
echo   1. Ya descargaste e instalaste ZenVPN
echo   2. Tienes tus credenciales de acceso
echo   3. Debes conectar ZenVPN ANTES de usar Lingma
echo.
echo Si NO cumples estos requisitos, presiona Ctrl+C
echo para cancelar y primero instala ZenVPN.
echo.
pause

echo.
echo Configurando perfil ZENVPN...
echo.

(
echo {
echo   "http_proxy": null,
echo   "https_proxy": null,
echo   "vpn_required": true,
echo   "vpn_type": "zenvpn",
echo   "profile": "home_vpn",
echo   "timeout": 90000,
echo   "retry_count": 5,
echo   "last_updated": "%date% %time%"
echo }
) > "C:\Users\boris\AppData\Local\.lingma\config.json"

if exist "C:\Users\boris\AppData\Local\.lingma\config.json" (
    echo [OK] Archivo de configuracion creado exitosamente
    echo.
    echo Configuracion aplicada:
    echo   ✓ Proxy: DESACTIVADO
    echo   ✓ VPN: REQUERIDA (ZenVPN)
    echo   ✓ Timeout: 90 segundos
    echo   ✓ Reintentos: 5
    echo.
    echo ============================================
    echo   PROXIMOS PASOS OBLIGATORIOS:
    echo ============================================
    echo.
    echo 1. Abre ZenVPN
    echo 2. Inicia sesión con tus credenciales
    echo 3. Conéctate al servidor VPN
    echo 4. Verifica que estás conectado
    echo 5. Cierra tu IDE completamente
    echo 6. Vuelve a abrir el IDE
    echo 7. Inicia sesión en Lingma
    echo.
    goto FIN
) else (
    echo [ERROR] No se pudo crear el archivo
    pause
    exit /b 1
)

:CONFIG_OFICINA
echo.
echo ============================================
echo   OPCION 3: OFICINA (VPN + PROXY)
echo ============================================
echo.
echo [ATENCION] Esta configuración requiere datos adicionales.
echo.
echo Necesitas obtener de tu departamento de TI:
echo   1. Dirección del servidor proxy
echo   2. Puerto del proxy
echo   3. Usuario de autenticación
echo   4. Contraseña
echo.
echo Ejemplo de lo que necesitas:
echo   Proxy: proxy.miempresa.com
echo   Puerto: 8080
echo   Usuario: juan.perez
echo   Clave: miPassword123
echo.
echo Una vez tengas estos datos:
echo   1. Abre el archivo: switch-lingma-profile.ps1
echo   2. Busca la variable $proxyUrl (línea ~45)
echo   3. Reemplaza con tus datos reales
echo   4. Guarda el archivo
echo   5. Ejecuta como administrador:
echo      .\switch-lingma-profile.ps1 -Profile office
echo.
echo Presiona una tecla para salir...
pause
exit /b 0

:FIN
echo ============================================
echo   CONFIGURACION COMPLETADA
echo ============================================
echo.
echo Archivo creado en:
echo   C:\Users\boris\AppData\Local\.lingma\config.json
echo.
echo ============================================
echo   PROXIMOS PASOS:
echo ============================================
echo.
echo 1. Cierra completamente tu IDE
echo    (Visual Studio / IntelliJ / VS Code)
echo.
echo 2. Espera 5 segundos
echo.
echo 3. Vuelve a abrir el IDE
echo.
echo 4. Inicia sesión en Lingma
echo.
echo ============================================
echo   VERIFICAR CONFIGURACION:
echo ============================================
echo.
echo Para ver la configuración aplicada:
echo   Get-Content C:\Users\boris\AppData\Local\.lingma\config.json
echo.
echo Si tienes problemas, consulta:
echo   CONFIGURACION_ZENVPN_LINGMA.md
echo.
echo ============================================
echo.
pause
