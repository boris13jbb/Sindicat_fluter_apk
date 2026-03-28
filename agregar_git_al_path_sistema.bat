@echo off
REM Ejecutar como Administrador: clic derecho -> "Ejecutar como administrador"
REM Anade Git al PATH del sistema para que el build de Flutter Windows funcione.

set "GIT_PATH=C:\Program Files\Git\cmd"
set "GIT_BIN=C:\Program Files\Git\bin"

if not exist "%GIT_PATH%\git.exe" (
    echo Git no esta en "%GIT_PATH%". Instala Git desde https://git-scm.com/download/win
    pause
    exit /b 1
)

for /f "skip=2 tokens=3*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%a %%b"
echo %SYS_PATH% | find /i "%GIT_PATH%" >nul 2>&1
if %errorlevel% equ 0 (
    echo Git ya esta en el PATH del sistema.
    echo Si el build sigue fallando, cierra Cursor/terminal y vuelve a abrir. Ver BUILD_WINDOWS.md
) else (
    setx /M PATH "%GIT_PATH%;%GIT_BIN%;%SYS_PATH%"
    echo Git anadido al PATH del sistema.
    echo Cierra Cursor y la terminal por completo, vuelve a abrir y ejecuta: flutter run -d windows
)
pause
