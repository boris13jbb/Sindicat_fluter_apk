# Configuración de Firebase para Windows Desktop

## Problemas Comunes y Soluciones

### 1. App se congela al iniciar en Windows

**Causa:** Firebase initialization puede quedarse colgado si:
- Las credenciales no son correctas
- Hay problemas de conexión de red
- Firestore persistence está habilitado pero hay errores

**Solución aplicada:**
- ✅ Se agregó timeout de 10 segundos a la inicialización
- ✅ Se mejoró el manejo de errores en Firestore
- ✅ Se corrigió el appId para Windows (debe ser igual que Web)

### 2. Verificar Credenciales de Firebase

Las credenciales actuales en `firebase_options.dart`:

```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
  appId: '1:118597085547:web:fluter_apk',  // ⚠️ DEBE SER IGUAL QUE WEB
  messagingSenderId: '118597085547',
  projectId: 'sistema-integrado-sindicato',
  storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  authDomain: 'sistema-integrado-sindicato.firebaseapp.com',
);
```

**IMPORTANTE:** Windows usa la misma configuración que Web en Firebase.

### 3. Pasos para Verificar

1. **Verifica en Firebase Console:**
   - Ve a https://console.firebase.google.com/
   - Selecciona tu proyecto: `sistema-integrado-sindicato`
   - Ve a Project Settings (engranaje ⚙️)
   - Baja hasta "Your apps"
   - Busca la app Web y verifica el `appId`

2. **Habilita los servicios necesarios:**
   - Authentication → Sign-in method → Habilita Email/Password
   - Firestore Database → Crea una base de datos
   - Storage → Habilita Cloud Storage

3. **Reglas de Firestore (firestore.rules):**
   Asegúrate de tener reglas básicas:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

### 4. Ejecutar en Modo Debug

Para ver logs detallados:

```bash
# Opción 1: Usar el script con verbose
run_windows.bat

# Opción 2: Flutter run con verbose
flutter run -d windows --verbose

# Opción 3: Build y run separado
flutter build windows
build\windows\x64\runner\Debug\fluter_apk.exe
```

### 5. Logs de Error Comunes

**Error: "Firebase initialization timeout"**
- Verifica tu conexión a internet
- Verifica que las credenciales sean correctas
- Intenta deshabilitar temporalmente el firewall/antivirus

**Error: "Firestore persistence failed"**
- El código ahora maneja este error automáticamente
- Continúa sin persistencia si falla

**Error: "No such module 'firebase_core'"**
- Ejecuta: `flutter clean`
- Luego: `flutter pub get`
- Rebuild: `flutter build windows`

### 6. Requisitos del Sistema

✅ **Visual Studio 2022** con:
- Desktop development with C++
- Windows 10 SDK

✅ **Flutter** versión estable:
```bash
flutter upgrade
flutter doctor
```

✅ **Git** en el PATH del sistema

### 7. Comandos Útiles

```bash
# Limpiar todo
flutter clean

# Obtener dependencias
flutter pub get

# Build Windows
flutter build windows

# Run con logging
flutter run -d windows --verbose

# Ver dispositivos
flutter devices

# Doctor
flutter doctor -v
```

### 8. Si el Problema Persiste

1. Ejecuta el diagnóstico:
   ```
   diagnose_windows.bat
   ```

2. Revisa los logs en la consola

3. Prueba crear un nuevo proyecto Firebase:
   - Ve a Firebase Console
   - Crea un nuevo proyecto
   - Registra una app Web
   - Copia las nuevas credenciales
   - Actualiza `firebase_options.dart`

4. Reporta el error con:
   - Output completo de `flutter doctor -v`
   - Logs de error de la consola
   - Versión de Windows
   - Versión de Visual Studio
