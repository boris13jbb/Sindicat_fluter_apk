# Ejecutar la app en Web

## Errores `ERR_CONNECTION_REFUSED` / `ERR_CONNECTION_RESET`

Esos mensajes **no son bugs del código**. Aparecen cuando:

1. El **servidor de desarrollo** no está en marcha (cerraste la terminal o se reinició).
2. Recargas la página **después** de que el servidor se haya parado.
3. El navegador intenta cargar scripts desde un puerto (ej. 60349) donde ya no hay nada.

## Qué hacer

1. **Arrancar solo el servidor** (así no se abren 4 pestañas ni peticiones antes de tiempo):
   ```powershell
   cd d:\proyecto_voto_sindicato\fluter_apk
   .\run_web.ps1
   ```
   O manualmente:
   ```bash
   flutter run -d web-server --web-port=8080
   ```

2. **Esperar** hasta que en la terminal salga algo como:
   ```
   Serving DevTools at http://127.0.0.1:9100
   The web server is running at http://localhost:8080
   ```
   **Solo entonces** abre en Chrome **una sola pestaña**: `http://localhost:8080`

3. **Usar siempre la misma URL**  
   Mientras la terminal siga abierta, puedes recargar esa pestaña sin problema.

4. **Si ya viste ERR_CONNECTION_REFUSED**  
   - Cierra todas las pestañas de localhost:8080.
   - Ejecuta `.\run_web.ps1`, espera a que diga que el servidor está corriendo.
   - Abre **una** pestaña a `http://localhost:8080`.

5. **Si sigue fallando**  
   - `flutter clean`
   - `flutter pub get`
   - Vuelve a ejecutar `.\run_web.ps1`.

No cierres la terminal donde corre el servidor hasta que termines de usar la app.

### Por qué se abren 4 pestañas

Si usas `flutter run -d chrome`, a veces Flutter/Chrome abre varias pestañas y algunas intentan cargar antes de que el servidor esté listo → ERR_CONNECTION_REFUSED. Por eso el script usa `web-server`: arranca solo el servidor y tú abres **una** pestaña cuando ya diga "The web server is running at ...".
