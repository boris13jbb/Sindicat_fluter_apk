#  Configuración de Lingma para Android Studio

## Solución al Error de "Sign in failed"

Basado en el error que estás viendo en Android Studio, aquí está la solución completa.

---

## 🔍 Diagnóstico del Problema

El error **"Sign in failed. An exception occurred while starting"** indica que:
1. ❌ Lingma no puede conectarse al servidor
2. ❌ Hay un problema de configuración de red/proxy
3. ❌ O la configuración actual no coincide con tu ubicación (casa/oficina)

---

## ✅ SOLUCIÓN RÁPIDA (5 Minutos)

### Paso 1: Configurar Archivo config.json

**Primero, identifica dónde estás:**

#### 🏠 Si estás en CASA:

1. Abre PowerShell como **Administrador**
2. Ejecuta:
   ```powershell
   cd d:\Sindicat_fluter_apk
   .\configurar_lingma_casa.bat
   ```
   (Click derecho → Ejecutar como administrador)

#### 🏢 Si estás en la OFICINA:

1. Abre PowerShell como **Administrador**
2. Ejecuta:
   ```powershell
   cd d:\Sindicat_fluter_apk
   .\configurar_lingma_zenvpn.bat
   ```
   (Click derecho → Ejecutar como administrador)
3. Selecciona opción **3** (OFICINA)
4. Configura con los datos de tu proxy corporativo

---

### Paso 2: Configurar Android Studio

#### A. Abrir Configuración de Lingma en Android Studio

1. **Abre Android Studio**
2. Ve a: **File** → **Settings** (o presiona `Ctrl + Alt + S`)
3. En el panel izquierdo, busca: **Tools** → **Tongyi Lingma**
4. Haz clic en **Lingma**

#### B. Configurar Proxy en Lingma (Android Studio)

**Para CASA:**

1. En la configuración de Lingma, busca **Network Settings** o **Proxy Settings**
2. Configura así:
   ```
   ☐ Use HTTP Proxy  (DESMARCADO)
   ☐ Use system proxy settings  (DESMARCADO)
   ```
3. Haz clic en **Apply**
4. Haz clic en **OK**

**Para OFICINA:**

1. En la configuración de Lingma, busca **Network Settings**
2. Marca: **☑ Use HTTP Proxy**
3. Configura:
   ```
   Proxy Host: proxy.empresa.com
   Proxy Port: 8080
   Proxy Username: tu_usuario
   Proxy Password: tu_contraseña
   ```
   *(Reemplaza con los datos de tu TI)*
4. Haz clic en **Test Connection** para verificar
5. Haz clic en **Apply** → **OK**

---

### Paso 3: Limpiar Caché de Lingma en Android Studio

1. En Android Studio, ve a: **File** → **Settings**
2. **Tools** → **Tongyi Lingma**
3. Busca botón **Clear Cache** o **Reset**
4. Haz clic en **Clear Cache**
5. Reinicia Android Studio completamente

---

### Paso 4: Verificar Conexión

1. **Abre PowerShell** (normal, no administrador)
2. Ejecuta:
   ```powershell
   curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```
3. **Resultado esperado:** `pong`

Si NO responde `pong`:
- Verifica tu conexión a internet
- Si estás en oficina, conecta la VPN primero
- Revisa el firewall de Windows

---

## 🔧 Configuración Detallada para Android Studio

### 1. Configurar Proxy HTTP de Android Studio (Global)

**File** → **Settings** → **Appearance & Behavior** → **System Settings** → **HTTP Proxy**

#### Para CASA:
```
☑ Auto-detect proxy settings
☐ Manual proxy configuration:
    [ ] HTTP: _____
    [ ] HTTPS: _____
    [ ] SOCKS: _____
```

#### Para OFICINA:
```
☐ Auto-detect proxy settings
☑ Manual proxy configuration:
    [✓] HTTP: proxy.empresa.com  Port: 8080
    [✓] HTTPS: proxy.empresa.com  Port: 8080
    Username: tu_usuario
    Password: tu_contraseña
    
☑ Proxy auto-config URL: (opcional, si tu empresa usa PAC)
```

**Importante:** Marca también:
```
☑ Check connection
```

Haz clic en **Check connection** y verifica que funcione.

---

### 2. Configurar Variables de Entorno para Lingma

Lingma en Android Studio usa las variables de entorno del sistema.

#### Método A: Configurar en Windows (Recomendado)

1. Presiona `Windows + R`
2. Escribe: `sysdm.cpl` y presiona Enter
3. Ve a pestaña **Advanced**
4. Haz clic en **Environment Variables**
5. En **User variables**, haz clic en **New**:

**Para CASA:**
```
Variable name: HTTP_PROXY
Variable value: (déjalo vacío o no lo crees)

Variable name: HTTPS_PROXY
Variable value: (déjalo vacío o no lo crees)
```

**Para OFICINA:**
```
Variable name: HTTP_PROXY
Variable value: http://usuario:contraseña@proxy.empresa.com:8080

Variable name: HTTPS_PROXY
Variable value: http://usuario:contraseña@proxy.empresa.com:8080
```

6. Haz clic en **OK** en todas las ventanas
7. **Reinicia Android Studio** completamente

#### Método B: Configurar desde Android Studio (Alternativo)

1. Ve a: **File** → **Settings**
2. **Tools** → **Terminal**
3. En **Env vars**, añade:

**Para CASA:**
```
HTTP_PROXY=
HTTPS_PROXY=
```

**Para OFICINA:**
```
HTTP_PROXY=http://usuario:contraseña@proxy.empresa.com:8080
HTTPS_PROXY=http://usuario:contraseña@proxy.empresa.com:8080
```

---

### 3. Verificar Plugin de Lingma en Android Studio

1. **File** → **Settings**
2. **Plugins**
3. Busca: **Tongyi Lingma**
4. Verifica que esté:
   ```
   ✓ Installado
   ✓ Habilitado (checkbox marcado)
   ✓ Actualizado a la última versión
   ```

**Si hay problemas:**
1. Haz clic en el engranaje ⚙️ junto al plugin
2. Selecciona **Disable**
3. Reinicia Android Studio
4. Vuelve a habilitar el plugin
5. Reinicia nuevamente

---

## 🎯 Configuración por Ubicación

### 🏠 Perfil CASA (Trabajo Remoto)

**Archivo config.json:**
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_required": false,
  "profile": "home",
  "timeout": 60000,
  "retry_count": 3
}
```

**Android Studio HTTP Proxy:**
```
☑ Auto-detect proxy settings
☐ Manual proxy configuration
```

**Variables de entorno:**
```
HTTP_PROXY = (vacío o no definido)
HTTPS_PROXY = (vacío o no definido)
```

**VPN:** NO requerida

**Pasos:**
1. Ejecutar: `.\configurar_lingma_casa.bat` como admin
2. Abrir Android Studio
3. File → Settings → Tools → Tongyi Lingma
4. Desmarcar "Use HTTP Proxy"
5. Apply → OK
6. Iniciar sesión en Lingma

---

### 🏢 Perfil OFICINA

**Archivo config.json:**
```json
{
  "http_proxy": "http://usuario:clave@proxy.empresa.com:8080",
  "https_proxy": "http://usuario:clave@proxy.empresa.com:8080",
  "vpn_required": true,
  "vpn_type": "zenvpn",
  "profile": "office",
  "timeout": 90000,
  "retry_count": 5,
  "proxy_bypass_list": ["localhost", "127.0.0.1"]
}
```

**Android Studio HTTP Proxy:**
```
☐ Auto-detect proxy settings
☑ Manual proxy configuration:
    HTTP: proxy.empresa.com:8080
    Username: tu_usuario
    Password: tu_contraseña
```

**Variables de entorno:**
```
HTTP_PROXY = http://usuario:clave@proxy.empresa.com:8080
HTTPS_PROXY = http://usuario:clave@proxy.empresa.com:8080
```

**VPN:** SÍ requerida (ZenVPN)

**Pasos:**
1. Conectar ZenVPN
2. Ejecutar: `.\configurar_lingma_zenvpn.bat` como admin (opción 3)
3. Configurar proxy con datos de TI
4. Abrir Android Studio
5. File → Settings → Tools → Tongyi Lingma
6. Marcar "Use HTTP Proxy"
7. Configurar proxy
8. Test Connection → Apply → OK
9. Iniciar sesión en Lingma

---

## 🔄 Cambiar entre Casa y Oficina

### Script Automático para Cambiar Perfiles

Crea el archivo `cambiar-perfil-android-studio.bat`:

```batch
@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================
echo   CAMBIAR PERFIL LINGMA - ANDROID STUDIO
echo ============================================
echo.

set /p perfil="Elige perfil (casa/oficina): "

if /i "%perfil%"=="casa" goto CASA
if /i "%perfil%"=="oficina" goto OFICINA

echo Opcion no valida
pause
exit /b 1

:CASA
echo.
echo Configurando perfil CASA...
echo.

REM Limpiar variables de entorno
setx HTTP_PROXY ""
setx HTTPS_PROXY ""

REM Configurar Lingma
echo { > temp.json
echo   "http_proxy": null, >> temp.json
echo   "https_proxy": null, >> temp.json
echo   "vpn_required": false, >> temp.json
echo   "profile": "home" >> temp.json
echo } >> temp.json

move /y temp.json "C:\Users\%USERNAME%\AppData\Local\.lingma\config.json" > nul

echo [OK] Perfil CASA configurado
echo.
echo Ahora:
echo 1. Cierra Android Studio
echo 2. Vuelve a abrir Android Studio
echo 3. Verifica: File -^> Settings -^> Tools -^> Tongyi Lingma
echo 4. Desmarca "Use HTTP Proxy"
echo.
goto FIN

:OFICINA
echo.
echo Configurando perfil OFICINA...
echo.
echo IMPORTANTE: Necesitas los datos del proxy de tu empresa
echo.
set /p proxy_url="URL del proxy (ej: http://proxy:8080): "
set /p proxy_user="Usuario: "
set /p proxy_pass="Contraseña: "

REM Configurar variables de entorno
setx HTTP_PROXY "%proxy_url%"
setx HTTPS_PROXY "%proxy_url%"

REM Configurar Lingma
echo { > temp.json
echo   "http_proxy": "%proxy_url%", >> temp.json
echo   "https_proxy": "%proxy_url%", >> temp.json
echo   "vpn_required": true, >> temp.json
echo   "profile": "office" >> temp.json
echo } >> temp.json

move /y temp.json "C:\Users\%USERNAME%\AppData\Local\.lingma\config.json" > nul

echo [OK] Perfil OFICINA configurado
echo.
echo Ahora:
echo 1. Conecta tu VPN (ZenVPN)
echo 2. Cierra Android Studio
echo 3. Vuelve a abrir Android Studio
echo 4. Verifica: File -^> Settings -^> Tools -^> Tongyi Lingma
echo 5. Marca "Use HTTP Proxy" y configura
echo.
goto FIN

:FIN
echo ============================================
echo   CONFIGURACION COMPLETADA
echo ============================================
echo.
pause
```

**Uso:**
```
Click derecho → cambiar-perfil-android-studio.bat → Ejecutar como administrador
```

---

## 🛠️ Solución de Problemas Específicos de Android Studio

### Problema 1: "Sign in failed" después de configurar

**Solución:**

1. **Cierra Android Studio completamente**
2. **Limpia caché de Lingma:**
   ```powershell
   Remove-Item "C:\Users\boris\AppData\Local\.lingma\cache" -Recurse -Force
   ```
3. **Reinicia el servicio Lingma:**
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"} | Stop-Process -Force
   ```
4. **Abre Android Studio como Administrador:**
   - Click derecho en Android Studio → Ejecutar como administrador
5. **Intenta iniciar sesión nuevamente**

---

### Problema 2: El plugin de Lingma no carga

**Solución:**

1. **File** → **Settings** → **Plugins**
2. Busca **Tongyi Lingma**
3. Click en el engranaje ⚙️ → **Disable**
4. **Reinicia Android Studio**
5. **File** → **Settings** → **Plugins**
6. Busca **Tongyi Lingma** → **Enable**
7. **Reinicia Android Studio** nuevamente

**Si persiste:**
1. **File** → **Settings** → **Plugins**
2. Click en engranaje ⚙️ → **Uninstall**
3. Reinicia Android Studio
4. Ve a **Marketplace** de plugins
5. Busca **Tongyi Lingma** → **Install**
6. Reinicia Android Studio

---

### Problema 3: Funciona en casa pero no en oficina (o viceversa)

**Solución:**

Necesitas cambiar el perfil según tu ubicación.

**Antes de abrir Android Studio:**

**Si vas a CASA:**
```powershell
cd d:\Sindicat_fluter_apk
.\configurar_lingma_casa.bat
```

**Si vas a OFICINA:**
```powershell
cd d:\Sindicat_fluter_apk
.\configurar_lingma_zenvpn.bat
# Elige opción 3
# Configura proxy con datos de TI
# Conecta ZenVPN
```

**Luego abre Android Studio y verifica:**
- File → Settings → Tools → Tongyi Lingma
- La configuración de proxy debe coincidir con tu ubicación

---

### Problema 4: Error de autenticación o timeout

**Solución:**

1. **Aumentar timeout en config.json:**

   Edita: `C:\Users\boris\AppData\Local\.lingma\config.json`
   
   ```json
   {
     "http_proxy": "...",
     "https_proxy": "...",
     "timeout": 120000,
     "retry_count": 5,
     "enable_caching": true
   }
   ```

2. **Limpiar DNS:**
   ```powershell
   ipconfig /flushdns
   ```

3. **Reiniciar Android Studio**

---

## 📋 Checklist de Verificación

### Antes de Iniciar Sesión en Lingma:

- [ ] Ejecuté el script de configuración como administrador
- [ ] Verifiqué mi conexión a internet
- [ ] Si estoy en oficina: VPN conectada
- [ ] Si estoy en oficina: Proxy configurado correctamente
- [ ] Cerré Android Studio completamente
- [ ] Volví a abrir Android Studio
- [ ] Verifiqué: File → Settings → Tools → Tongyi Lingma
- [ ] La configuración de proxy coincide con mi ubicación

### Después de Configurar:

- [ ] El plugin de Lingma está habilitado
- [ ] No hay errores en la ventana de eventos
- [ ] Puedo hacer clic en "Sign in to Lingma"
- [ ] La ventana de autenticación se abre
- [ ] Puedo ingresar mis credenciales
- [ ] El inicio de sesión es exitoso
- [ ] Lingma responde en el editor

---

## 🎯 Resumen Visual

```
┌─────────────────────────────────────┐
│  ¿Dónde estás trabajando?           │
└─────────────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
   CASA      OFICINA
     │           │
     ▼           ▼
┌─────────┐ ┌──────────────┐
│Ejecutar │ │1. Conectar   │
│script   │ │   ZenVPN     │
│casa.bat │ │2. Ejecutar   │
│         │ │   oficina.bat │
│         │ │3. Configurar │
│         │ │   proxy      │
└────┬────┘ └──────┬───────┘
     │             │
     └────────────┘
            │
            ▼
     ┌──────────────┐
     │Abrir Android │
     │Studio        │
     └──────┬───────┘
            │
            ▼
     ┌──────────────┐
     │File → Settings│
     │Tools → Lingma │
     └──────┬───────┘
            │
            ▼
     ┌──────────────┐
     │Configurar    │
     │proxy según   │
     │ubicación     │
     └──────┬───────┘
            │
            ▼
     ┌──────────────┐
     │Apply → OK    │
     │Sign in       │
     └──────────────┘
```

---

## 📞 Contacto y Soporte

Si después de seguir todos los pasos el problema persiste:

### Información para TI:

```
Problema: Lingma en Android Studio - Error "Sign in failed"
Ubicación: [CASA/OFICINA]
Configuración actual: [Sin proxy/Con proxy/Con VPN]

URLs necesarias:
  - https://lingma-api.tongyi.aliyun.com
  - https://devops.aliyun.com

Datos del sistema:
  - Android Studio: [Versión]
  - Plugin Lingma: [Versión]
  - Windows: 22H2
  - Usuario: boris

¿Requieren VPN? [SÍ/NO]
¿Requieren Proxy? [SÍ/NO]
  - Si SÍ: [URL del proxy, puerto, usuario]
```

### Soporte Oficial Lingma:

- **FAQ Troubleshooting Guide:** (Enlace desde el error en Android Studio)
- **DingTalk group:** 53770000738
- **Email:** lingma-support@alibabacloud.com
- **Documentación:** https://help.aliyun.com/product/42154.html

---

## ✅ Verificación Final

Después de configurar todo, haz esta prueba:

1. **Abre Android Studio**
2. **Abre un archivo Dart/Java/Kotlin**
3. **Escribe un comentario o código**
4. **Presiona `Alt + \`** (o el atajo de Lingma)
5. **Debería aparecer la sugerencia de IA**

**Si funciona:** ¡Felicidades! ✅ Configuración exitosa  
**Si NO funciona:** Revisa la sección de solución de problemas

---

**¡Listo! Ahora puedes usar Lingma en Android Studio tanto en casa como en la oficina.** 🚀
