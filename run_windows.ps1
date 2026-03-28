# Ejecutar Flutter en Windows con Git en el PATH (para que el build no falle)
$env:Path = "C:\Program Files\Git\cmd;C:\Program Files\Git\bin;$env:Path"
Set-Location $PSScriptRoot
flutter run -d windows
