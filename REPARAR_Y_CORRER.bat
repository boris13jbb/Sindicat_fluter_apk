@echo off
TITLE Reparador de Entorno Flutter - Sindicato
:: Asegurar que el script se ejecute en la carpeta donde esta guardado
cd /d "%~dp0"

echo ====================================================
echo   REPARADOR DE ENTORNO FLUTTER - MODO ULTRA-LIMPIO
echo ====================================================
echo.

echo [+] 1. Cerrando procesos Dart y Chrome...
taskkill /F /IM dart.exe /T >nul 2>&1
taskkill /F /IM flutter_tools.exe /T >nul 2>&1
taskkill /F /IM chrome.exe /T >nul 2>&1

echo [+] 2. Limpiando bloqueos de archivos temporales de Flutter...
:: Borramos la carpeta de cache de herramientas para forzar un inicio fresco
if exist "build" rd /s /q "build"
if exist ".dart_tool" rd /s /q ".dart_tool"

echo [+] 3. Limpiando cache de Flutter...
call flutter clean

echo [+] 4. Reinstalando librerias...
call flutter pub get

echo.
echo ====================================================
echo   ENTORNO LISTO. LANZANDO SERVIDOR...
echo ====================================================
echo.
echo   PASOS A SEGUIR:
echo   1. Deja esta ventana abierta (es el motor de la app).
echo   2. Abre Chrome (preferiblemente Incognito: Ctrl+Shift+N).
echo   3. Entra a: http://localhost:5000
echo.
echo   Si haces cambios en el codigo, escribe 'R' aqui para recargar.
echo ====================================================
echo.

:: Usamos web-server con puerto fijo para maxima estabilidad
call flutter run -d web-server --web-port 5000 --web-hostname localhost
pause
