# Solución de Problemas - Windows Desktop

## Guía Completa para Ejecutar la App en Windows

Esta guía te ayudará a resolver los problemas más comunes al ejecutar la aplicación en Windows Desktop.

---

## ✅ Requisitos Previos

### 1. **Visual Studio 2022 (Obligatorio)**

Debes tener instalado Visual Studio 2022 (no VS Code) con las siguientes cargas de trabajo:

- ✅ **"Desarrollo para el escritorio de Windows con C++"** (Desktop development with C++)
- ✅ Esto incluye automáticamente:
  - MSVC (compilador de C++)
  - Windows 10/11 SDK
  - CMake

**¿Cómo verificar?**
1. Abre el **Instalador de Visual Studio**
2. Busca "Desarrollo para el escritorio de Windows con C++"
3. Debe estar marcado con ✓

**Si no lo tienes:**
1. Descarga desde: https://visualstudio.microsoft.com/es/downloads/
2. Ejecuta el instalador
3. Marca la carga de trabajo mencionada
4. Espera a que termine la instalación (puede tardar 10-30 minutos)

---

### 2. **Git para Windows**

**Verificar instalación:**
```bash
git --version
```

**Si no está instalado:**
1. Descarga desde: https://git-scm.com/download/win
2. Durante la instalación, elige: **"Git from the command line and also from 3rd-party software"**
3. NO elijas "Bash only"

---

### 3. **Flutter SDK**

**Verificar instalación:**
```bash
flutter doctor
```

Debe mostrar Flutter instalado sin errores críticos.

---

## 🚀 Ejecutar la Aplicación

### Opción A: Usar el Script Automático (Recomendado)

**Desde PowerShell:**
```powershell
.\run_windows.ps1
```

**Desde CMD:**
```bat
run_windows.bat
```

El script automáticamente:
1. ✅ Verifica Git
2. ✅ Limpia builds anteriores
3. ✅ Obtiene dependencias
4. ✅ Compila y ejecuta

---

### Opción B: Comandos Manuales

```bash
# 1. Ir al directorio del proyecto
cd D:\Sindicat_fluter_apk

# 2. Agregar Git al PATH temporalmente
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"

# 3. Obtener dependencias
flutter pub get

# 4. Limpiar build anterior (opcional)
flutter clean

# 5. Ejecutar en Windows
flutter run -d windows
```

---

## ❌ Errores Comunes y Soluciones

### Error 1: "Unable to find git in your PATH"

**Causa:** MSBuild no encuentra Git en el PATH del sistema.

**Solución Rápida:**
```bat
# Agrega Git al PATH temporalmente
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"
flutter run -d windows
```

**Solución Permanente:**
1. Presiona **Win + R**, escribe `sysdm.cpl` y Enter
2. Pestaña **Opciones avanzadas** → **Variables de entorno**
3. En **Variables del sistema**, selecciona **Path** → **Editar** → **Nuevo**
4. Agrega: `C:\Program Files\Git\cmd`
5. Agrega también: `C:\Program Files\Git\bin`
6. Aceptar en todas las ventanas
7. **Cierra completamente** tu IDE/terminal y vuelve a abrirlo

---

### Error 2: "C1041: cannot open program database" o conflictos de PDB

**Causa:** Múltiples procesos intentan escribir al mismo archivo PDB.

**Solución:** El archivo `windows/CMakeLists.txt` ya incluye la bandera `/FS` que fuerza la sincronización de escritura de PDB.

Si persiste:
1. Cierra todos los procesos de MSBuild
2. Limpia el build: `flutter clean`
3. Vuelve a ejecutar

---

### Error 3: "No such file or directory" en headers de Windows

**Causa:** Falta el Windows SDK.

**Solución:**
1. Abre el Instalador de Visual Studio
2. Modifica la instalación
3. Asegúrate de tener marcado **"Windows 10/11 SDK"**
4. Instala y reinicia

---

### Error 4: La app se inicia pero Firebase falla

**Síntomas:**
```
❌ Error inicializando Firebase: [firebase_core] ...
```

**Solución:**

1. **Verifica conexión a internet**
   ```bash
   ping google.com
   ```

2. **Verifica las credenciales en `lib/firebase_options.dart`**
   - Asegúrate de que `apiKey`, `appId`, `projectId` sean correctos
   - Para Windows, se usa la configuración de Web

3. **Habilita Firebase Auth en Firebase Console:**
   - Ve a: https://console.firebase.google.com
   - Selecciona tu proyecto
   - Authentication → Sign-in method
   - Habilita "Email/Password"

4. **Limpia cache de Flutter:**
   ```bash
   flutter clean
   flutter pub get
   ```

---

### Error 5: "Build failed" o errores de compilación C++

**Pasos de diagnóstico:**

1. **Ejecuta Flutter Doctor:**
   ```bash
   flutter doctor -v
   ```
   
   Busca la sección "Visual Studio - develop for Windows"
   - Debe tener ✓ verde
   - Si tiene ✗ rojo, lee el mensaje de error

2. **Verifica la versión de CMake:**
   ```bash
   cmake --version
   ```
   Debe ser 3.14 o superior (viene con Visual Studio)

3. **Revisa el log completo del error:**
   - El mensaje de error suele estar varias líneas arriba del final
   - Busca "error C" o "fatal error"

**Soluciones comunes:**

- **Falta MSVC:** Instala Visual Studio con desarrollo C++
- **CMake muy viejo:** Actualiza Visual Studio
- **Headers faltantes:** Reinstala Windows SDK

---

### Error 6: La app se cierra inmediatamente al iniciar

**Posibles causas:**

1. **Firebase mal configurado**
   - Revisa los logs en la terminal
   - Verifica `firebase_options.dart`

2. **Error en el código Dart**
   - Ejecuta: `flutter analyze`
   - Corrige errores reportados

3. **Problema de permisos**
   - Ejecuta como administrador (poco común)

---

### Error 7: Problemas de red/Firewall

**Síntomas:**
- Firebase funciona en Android/Web pero no en Windows
- Errores de conexión

**Solución:**
1. Verifica que el Firewall de Windows no esté bloqueando la app
2. Prueba desactivar temporalmente el antivirus
3. Asegúrate de estar en una red que permita conexiones salientes

---

## 🔧 Optimizaciones para Windows

### Mejorar tiempo de build

La primera compilación tarda 5-10 minutos. Las siguientes deberían tomar 1-2 minutos.

**Para acelerar:**
1. No limpies el build innecesariamente (`flutter clean` solo cuando haya errores)
2. Usa builds incrementales (cambia solo lo necesario)
3. Ten suficiente RAM (8GB mínimo, 16GB recomendado)

### Modo Release (producción)

```bash
flutter build windows --release
```

El ejecutable estará en: `build\windows\runner\Release\fluter_apk.exe`

---

## 📋 Lista de Verificación Pre-Build

Antes de ejecutar, verifica:

- [ ] Visual Studio 2022 instalado con carga de trabajo C++
- [ ] Git instalado y en PATH
- [ ] Flutter instalado y actualizado
- [ ] Conexión a internet activa
- [ ] Espacio en disco suficiente (mínimo 5GB libres)
- [ ] Dependencias obtenidas (`flutter pub get`)

---

## 🆘 ¿Nada funciona?

### Pasos nucleares:

1. **Reinicia todo:**
   - Cierra IDE, terminal, y cualquier proceso de Flutter
   - Reinicia la computadora

2. **Limpieza profunda:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Verifica Flutter Doctor:**
   ```bash
   flutter doctor -v
   ```
   Corrige TODO lo que tenga ✗ rojo

4. **Prueba en Chrome (alternativa):**
   ```bash
   flutter run -d chrome
   ```
   Si funciona en Chrome, el problema es específico de Windows

5. **Reinstala componentes:**
   - Desinstala Visual Studio
   - Vuelve a instalar con la carga de trabajo C++
   - Reinstala Git eligiendo la opción correcta de PATH

---

## 📞 Recursos Adicionales

- **Documentación oficial Flutter Windows:** https://docs.flutter.dev/platform-integration/windows/building
- **Stack Overflow:** https://stackoverflow.com/questions/tagged/flutter-windows
- **GitHub Issues de Flutter:** https://github.com/flutter/flutter/issues

---

## ✅ Confirmación de Éxito

Cuando la app se ejecute correctamente verás:

1. ✅ Ventana de Windows con la app
2. ✅ Login funcional
3. ✅ Logs en la terminal mostrando actividad
4. ✅ Sin mensajes de error rojos

**¡Listo! Ya puedes desarrollar y probar en Windows Desktop.**
