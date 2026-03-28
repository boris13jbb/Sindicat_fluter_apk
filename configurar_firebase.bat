@echo off
chcp 65001 >nul
echo ============================================
echo   Configurar Firebase con FlutterFire CLI
echo ============================================
echo.

REM FlutterFire necesita el comando "firebase" en PATH (Firebase CLI global)
set "NPM_BIN=%APPDATA%\npm"
set "PATH=%NPM_BIN%;%PATH%"
REM Dart pub cache (para que funcione 'flutterfire')
set "DART_BIN=%USERPROFILE%\AppData\Local\Pub\Cache\bin"
set "PATH=%DART_BIN%;%PATH%"

REM Comprobar que Firebase CLI está instalado
where firebase >nul 2>&1
if errorlevel 1 (
    echo Firebase CLI no encontrado. Instalando globalmente...
    call npm install -g firebase-tools
    if errorlevel 1 (
        echo Error al instalar firebase-tools. Ejecuta manualmente: npm install -g firebase-tools
        pause
        exit /b 1
    )
    echo.
)

echo [1/2] Iniciando sesión en Firebase...
echo      Se abrirá el navegador para que inicies sesión con tu cuenta de Google.
echo.
call npx firebase-tools login
if errorlevel 1 (
    echo.
    echo Error en login. Si usas una terminal no interactiva, ejecuta en una terminal normal:
    echo   npx firebase-tools login
    echo.
    pause
    exit /b 1
)

echo.
echo [2/2] Configurando FlutterFire (genera lib/firebase_options.dart)...
echo      Selecciona tu proyecto de Firebase y las plataformas: android, ios, web, windows.
echo.
cd /d "%~dp0"
flutterfire configure --platforms=android,ios,web,windows

echo.
echo Si todo fue bien, ya existe lib\firebase_options.dart
echo Puedes ejecutar la app con: flutter run -d chrome
echo.
pause
