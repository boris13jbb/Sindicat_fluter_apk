# Configuración de Firebase (FlutterFire CLI)

## Ya hecho por la configuración anterior

1. **Firebase CLI**  
   Se puede usar con: `npx firebase-tools` (o instalar globalmente: `npm install -g firebase-tools`).

2. **FlutterFire CLI**  
   Activada con: `dart pub global activate flutterfire_cli`  
   Asegúrate de tener en el PATH la carpeta de Dart global:
   - Windows: `%USERPROFILE%\AppData\Local\Pub\Cache\bin`

## Pasos que debes hacer tú (en una terminal donde puedas interactuar)

### Opción A: Script automático (recomendado)

1. Abre una **terminal** (PowerShell o CMD) en la carpeta del proyecto.
2. Ejecuta:
   ```bat
   configurar_firebase.bat
   ```
3. Cuando se abra el navegador, **inicia sesión** con tu cuenta de Google.
4. En la terminal, cuando pida **proyecto de Firebase**, elige el tuyo (o créalo en la consola de Firebase).
5. Selecciona las plataformas: **android, ios, web, windows** (o las que uses).
6. Al terminar se habrá creado `lib/firebase_options.dart` y Flutter reconocerá Firebase.

### Opción B: Comandos manuales

En la carpeta del proyecto:

```bash
# 1. Iniciar sesión en Firebase (abre el navegador)
npx firebase-tools login

# 2. Añadir Pub Cache al PATH (Windows) y configurar FlutterFire
set PATH=%USERPROFILE%\AppData\Local\Pub\Cache\bin;%PATH%
flutterfire configure --platforms=android,ios,web,windows
```

En el paso 2 selecciona tu proyecto de Firebase y las plataformas.

---

Después de esto, `lib/firebase_options.dart` existirá y la app usará `DefaultFirebaseOptions.currentPlatform` en `main.dart`.  
Para ejecutar: `flutter run -d chrome` (o el dispositivo que quieras).
