# Ejecuta la app Flutter en Web (solo servidor, sin abrir Chrome automático).
# Evita ERR_CONNECTION_REFUSED y 4 pestañas: tú abres UNA pestaña cuando veas "Serving at ...".
# No cierres esta ventana mientras uses la app.

Set-Location $PSScriptRoot
flutter run -d web-server --web-port=8080
