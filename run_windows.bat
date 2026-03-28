@echo off
REM Asegura que Git este en el PATH para el build de Windows (MSBuild lo necesita)
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"
cd /d "%~dp0"
flutter run -d windows
pause
