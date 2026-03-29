# 🏠 CONFIGURACIÓN PARA CASA - Sin Proxy

## ¡ESTO ES LO QUE NECESITAS HACER AHORA!

Como estás en **CASA**, Lingma debe configurarse **SIN PROXY**.

---

## Pasos a Seguir (EN ORDEN)

### Paso 1: Abrir PowerShell como ADMINISTRADOR

**IMPORTANTE:** Esto es crucial para evitar errores de permisos.

1. Presiona `Windows + X`
2. Selecciona **"Windows PowerShell (Administrador)"** o **"Terminal (Administrador)"**
3. Si aparece una ventana de confirmación, haz clic en **"Sí"**

### Paso 2: Navegar al directorio del proyecto

En la ventana de PowerShell (que debe decir "Administrador" en la barra de título), escribe:

```powershell
cd d:\Sindicat_fluter_apk
```

### Paso 3: Ejecutar el script de configuración

Copia y pega este comando:

```powershell
.\switch-lingma-profile.ps1 -Profile home
```

Presiona **Enter**

### Paso 4: Verificar que se creó el archivo

El script debería mostrar un mensaje verde diciendo que se activó el perfil 'home'.

Si todo salió bien, verás:
```
============================================
  Perfil 'home' activado correctamente
============================================
```

### Paso 5: Reiniciar tu IDE

1. **Cierra completamente** Visual Studio o IntelliJ
2. **Espera 5 segundos**
3. **Vuelve a abrir** el IDE
4. **Intenta iniciar sesión** en Lingma

---

## ¿Qué hace esta configuración?

El perfil **CASA** configura:

✅ **Proxy:** DESACTIVADO (conexión directa a internet)  
✅ **VPN:** NO requerida  
✅ **Timeout:** 60 segundos  
✅ **Reintentos:** 3 intentos

Esto es perfecto para trabajar desde casa sin restricciones corporativas.

---

## Solución de Problemas Comunes

### ❌ Error: "Access to the path is denied"

**Causa:** No ejecutaste PowerShell como administrador.

**Solución:**
1. Cierra PowerShell
2. Abre PowerShell como **Administrador** (ver Paso 1 arriba)
3. Vuelve a ejecutar el script

### ❌ Error: "No se reconoce el cmdlet"

**Causa:** Las políticas de ejecución de PowerShell están bloqueando el script.

**Solución:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\switch-lingma-profile.ps1 -Profile home
```

### ❌ Lingma sigue pidiendo proxy después de configurar

**Solución:**
1. Cierra el IDE completamente
2. Ejecuta como administrador:
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"} | Stop-Process -Force
   ```
3. Vuelve a ejecutar el script:
   ```powershell
   .\switch-lingma-profile.ps1 -Profile home
   ```
4. Abre el IDE nuevamente

---

## Verificar Configuración

Para confirmar que la configuración se aplicó correctamente:

```powershell
Get-Content C:\Users\boris\AppData\Local\.lingma\config.json
```

Deberías ver algo como:

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

**Si ves `"http_proxy": null`** → ¡Perfecto! Estás en modo casa ✅

---

## Cuando Vayas a la Oficina

Cuando necesites usar el proxy de la oficina:

1. Obtén los datos del proxy de tu departamento de TI
2. Edita el archivo `switch-lingma-profile.ps1` y busca la línea con `$proxyUrl`
3. Reemplaza con tus datos reales
4. Ejecuta:
   ```powershell
   .\switch-lingma-profile.ps1 -Profile office
   ```

---

## Resumen Rápido

| Ubicación | Comando | ¿Necesitas VPN? |
|-----------|---------|----------------|
| 🏠 Casa | `.\switch-lingma-profile.ps1 -Profile home` | NO |
| 🏢 Oficina | `.\switch-lingma-profile.ps1 -Profile office` | SÍ |

---

## ¡LISTO!

Después de seguir estos pasos, deberías poder usar Lingma en casa sin problemas.

**Recuerda:** Siempre reinicia el IDE después de cambiar el perfil.
