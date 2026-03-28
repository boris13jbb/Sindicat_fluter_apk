@echo off
chcp 65001 >nul
REM Firebase CLI y FlutterFire en el PATH (necesario para que FlutterFire encuentre "firebase")
set "PATH=%APPDATA%\npm;%USERPROFILE%\AppData\Local\Pub\Cache\bin;%PATH%"
cd /d "%~dp0"

echo Proyecto: sistema-integrado-sindicato
echo Plataformas: android, ios, web, windows
echo.

flutterfire configure --project=sistema-integrado-sindicato --platforms=android,ios,web,windows --yes

if exist "lib\firebase_options.dart" (
    echo.
    echo OK. lib\firebase_options.dart generado correctamente.
) else (
    echo.
    echo No se generó el archivo. Ejecuta en su lugar: configurar_firebase.bat
    echo y en el menú elige "sistema-integrado-sindicato".
)
echo.
pause
