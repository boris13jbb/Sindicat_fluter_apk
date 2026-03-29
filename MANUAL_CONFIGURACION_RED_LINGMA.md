# Manual de Configuración de Red y Proxy para Lingma

## Índice
1. [Verificación de Conectividad](#1-verificación-de-conectividad)
2. [Configuración del Proxy](#2-configuración-del-proxy)
3. [Configuración con VPN](#3-configuración-con-vpn)
4. [Limpieza de Caché](#4-limpieza-de-caché)
5. [Reinicio y Solución de Problemas](#5-reinicio-y-solución-de-problemas)
6. [Solución de Errores Comunes](#6-solución-de-errores-comunes)

---

## 1. Verificación de Conectividad

### 1.1 Verificar Acceso al Servicio Lingma

**Objetivo:** Confirmar que puede alcanzar el servicio de Lingma.

**Pasos:**

1. Abra PowerShell o Símbolo del sistema (CMD) como administrador
2. Ejecute el siguiente comando:

```bash
curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
```

**Resultado Esperado:**
```
pong
```

**Si NO recibe "pong":**
- Verifique su conexión a internet
- Contacte al departamento de TI para añadir la URL a la lista blanca del firewall
- Proceda a la sección de configuración de proxy

### 1.2 Verificar Acceso a DevOps Aliyun

**Objetivo:** Confirmar acceso al portal de DevOps.

**Pasos:**

1. En PowerShell o CMD, ejecute:

```bash
curl -I https://devops.aliyun.com
```

**Resultado Esperado:**
```
HTTP/1.1 302 Found
```

**Código de estado debe ser:** `302`

**Si NO recibe 302:**
- El sitio puede estar bloqueado por el firewall corporativo
- Configure el proxy según la sección 2

---

## 2. Configuración del Proxy

### 2.1 Obtener Información del Proxy

**Importante:** Debe solicitar al departamento de TI de su empresa:

- Dirección del servidor proxy
- Puerto del proxy
- Usuario de autenticación (si aplica)
- Contraseña (si aplica)

**Formato de la URL del proxy:**
```
http(s)://usuario:contraseña@direccion-proxy:puerto
```

**Ejemplos:**

- **Sin autenticación:**
  ```
  http://proxy.empresa.com:8080
  ```

- **Con autenticación:**
  ```
  http://juan:perez123@proxy.empresa.com:8080
  ```

- **Proxy HTTPS:**
  ```
  https://juan:perez123@secure-proxy.empresa.com:3128
  ```

### 2.2 Configurar Proxy en Lingma

#### Método A: Desde la Interfaz (Recomendado)

1. Abra su IDE (Visual Studio, IntelliJ, etc.)
2. Vaya a **Extensiones** → **Lingma**
3. Haga clic en **Configuración** o **Settings**
4. Busque la sección **Red** o **Network**
5. En el campo **HTTP Proxy**, ingrese la URL del proxy obtenida del TI
6. Haga clic en **Guardar** o **Apply**
7. Reinicie el IDE

#### Método B: Editando el Archivo de Configuración

**Ubicación del archivo:**
```
C:\Users\[SU_USUARIO]\AppData\Local\.lingma\config.json
```

**Pasos:**

1. Cierre completamente el IDE
2. Finalice el proceso de Lingma desde el Administrador de Tareas
3. Abra el archivo `config.json` con un editor de texto (Notepad, VS Code)
4. Localice o agregue el campo `http_proxy`
5. Modifique según corresponda:

**Ejemplo de config.json:**
```json
{
  "http_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
  "https_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
  "no_proxy": "localhost,127.0.0.1"
}
```

6. Guarde el archivo
7. Continúe con la sección 3

---

## 3. Configuración con VPN

### 3.1 ¿Necesitas VPN para usar Lingma?

**Sí, necesitas VPN si:**
- Tu empresa requiere conexión VPN para acceder a recursos externos
- Los servidores de Lingma están bloqueados en tu red local
- Trabajas desde casa y necesitas acceder a la red corporativa
- Tu departamento de TI lo indica como requisito obligatorio

**No necesitas VPN si:**
- Puedes acceder directamente a las URLs de Lingma sin VPN
- Tu empresa permite acceso directo a servicios en la nube
- Ya configuraste un proxy corporativo que funciona

### 3.2 Verificar Conexión con VPN

#### Paso 1: Conectar la VPN

1. Abre tu cliente VPN (Cisco AnyConnect, GlobalProtect, FortiClient, etc.)
2. Ingresa las credenciales proporcionadas por tu empresa
3. Conéctate al servidor VPN indicado
4. Espera a que el estado muestre "Conectado"

#### Paso 2: Verificar que la VPN está activa

**En Windows:**

1. Abre PowerShell
2. Ejecuta:
   ```bash
   ipconfig /all
   ```

3. Busca adaptadores que digan:
   - "Cisco AnyConnect"
   - "GlobalProtect"
   - "FortiClient"
   - O el nombre de tu VPN

4. Deberías ver una dirección IP asignada por la VPN

#### Paso 3: Probar conectividad a Lingma con VPN

1. **Con la VPN conectada**, ejecuta:
   ```bash
   curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```

2. **Resultado esperado:** `pong`

3. **Si NO funciona:**
   - Verifica que la VPN tenga acceso a internet (no solo a recursos internos)
   - Contacta a TI para que habiliten el acceso a los dominios de Lingma

### 3.3 Configurar Lingma con VPN Activa

#### Escenario A: VPN con Proxy Corporativo

**Cuando usar:** Tu empresa usa VPN Y ADEMÁS requiere proxy para salir a internet.

**Configuración:**

1. **Conecta primero la VPN**
2. **Luego configura el proxy** en Lingma (ver sección 2)
3. **Orden correcto:**
   ```
   1. Activar VPN → 2. Configurar Proxy → 3. Iniciar Lingma
   ```

**Archivo config.json:**
```json
{
  "http_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
  "https_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
  "vpn_enabled": true,
  "no_proxy": "localhost,127.0.0.1,.empresa.local"
}
```

#### Escenario B: VPN sin Proxy

**Cuando usar:** Tu VPN te da acceso directo a internet sin necesidad de proxy.

**Configuración:**

1. **Conecta la VPN**
2. **NO configures proxy** en Lingma (déjalo vacío o null)
3. **Orden correcto:**
   ```
   1. Activar VPN → 2. Sin proxy → 3. Iniciar Lingma
   ```

**Archivo config.json:**
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_enabled": true
}
```

#### Escenario C: VPN con Split Tunneling

**¿Qué es Split Tunneling?** Algunas rutas van por la VPN, otras por tu conexión normal.

**Configuración:**

1. **Identifica qué tráfico va por la VPN:**
   - Pregunta a TI qué dominios requieren VPN
   - Los servidores de Lingma pueden requerir VPN

2. **Configura en Lingma:**

```json
{
  "http_proxy": "http://proxy.empresa.com:8080",
  "vpn_required_domains": [
    "lingma-api.tongyi.aliyun.com",
    "devops.aliyun.com"
  ],
  "split_tunnel": true
}
```

3. **Verifica las rutas de la VPN:**
   ```bash
   route print
   ```
   
   Busca rutas que incluyan los dominios de Aliyun

### 3.4 Solución de Problemas con VPN

#### Problema 1: Lingma funciona SIN VPN pero NO CON VPN

**Causa probable:** La VPN está bloqueando el acceso a los servidores de Lingma.

**Solución:**

1. **Verifica las reglas del firewall de la VPN:**
   - Abre tu cliente VPN
   - Busca configuración de firewall o reglas de acceso
   - Verifica que no haya bloqueo para `*.aliyun.com`

2. **Solicita a TI que añadan las siguientes URLs a la lista blanca:**
   ```
   https://lingma-api.tongyi.aliyun.com
   https://devops.aliyun.com
   *.tongyi.aliyun.com
   *.aliyun.com
   ```

3. **Prueba hacer ping a los servidores:**
   ```bash
   ping lingma-api.tongyi.aliyun.com
   ```

#### Problema 2: La VPN se desconecta frecuentemente

**Síntoma:** Lingma deja de funcionar cuando la VPN se reconecta.

**Solución:**

1. **Configurar reconexión automática del servicio Lingma:**

   Edita `config.json`:
   ```json
   {
     "auto_reconnect": true,
     "reconnect_delay": 5000,
     "max_reconnect_attempts": 3
   }
   ```

2. **Forzar renovación de DNS después de reconectar:**
   
   Crea un script PowerShell `renew-dns.ps1`:
   ```powershell
   ipconfig /flushdns
   ipconfig /registerdns
   Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"} | Stop-Process -Force
   # El IDE reiniciará Lingma automáticamente
   ```

3. **Ejecutar el script después de cada reconexión de VPN**

#### Problema 3: Lentitud extrema con VPN activada

**Causa:** El tráfico está siendo ruteado por servidores lentos.

**Solución:**

1. **Cambiar servidor VPN:**
   - Conéctate a un servidor VPN más cercano geográficamente
   - Pregunta a TI por servidores optimizados para acceso a cloud

2. **Optimizar configuración de Lingma:**

   ```json
   {
     "timeout": 120000,
     "retry_count": 5,
     "enable_caching": true,
     "cache_ttl": 3600
   }
   ```

3. **Usar modo offline cuando sea posible:**
   - Lingma puede cachear respuestas
   - Configura caché agresivo si la VPN es inestable

### 3.5 VPN + Proxy: Configuración Avanzada

#### Configuración para Empresas con Seguridad Reforzada

**Escenario:** VPN obligatoria + Proxy autenticado + Firewall restrictivo

**Pasos detallados:**

1. **Obtener toda la información de TI:**
   
   Completa esta plantilla:
   ```
   Servidor VPN: _______________________
   Usuario VPN: _______________________
   Contraseña VPN: ____________________
   
   Proxy URL: _________________________
   Puerto Proxy: ______________________
   Usuario Proxy: _____________________
   Contraseña Proxy: __________________
   
   Dominios en lista blanca necesarios:
   - lingma-api.tongyi.aliyun.com
   - devops.aliyun.com
   - Otros: ___________________________
   ```

2. **Configurar en orden estricto:**

   **Paso 1:** Conectar VPN
   ```powershell
   # Ejemplo con Cisco AnyConnect (ajustar según tu cliente)
   cd "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client"
   .\vpncli.exe connect vpn.empresa.com
   ```

   **Paso 2:** Verificar conexión VPN
   ```powershell
   ipconfig | findstr "AnyConnect"
   ```

   **Paso 3:** Configurar proxy en Lingma
   - Editar `C:\Users\[USUARIO]\AppData\Local\.lingma\config.json`
   
   ```json
   {
     "http_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
     "https_proxy": "http://usuario:contraseña@proxy.empresa.com:8080",
     "vpn_mode": "corporate",
     "bypass_proxy_for_vpn": false,
     "proxy_bypass_list": [
       "localhost",
       "127.0.0.1",
       ".empresa.local"
     ]
   }
   ```

   **Paso 4:** Limpiar caché DNS
   ```powershell
   ipconfig /flushdns
   ```

   **Paso 5:** Reiniciar Lingma
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"} | Stop-Process -Force
   ```

   **Paso 6:** Iniciar IDE como administrador
   
   **Paso 7:** Probar conectividad
   ```powershell
   curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```

3. **Crear script de inicio automático (Opcional):**

   Crea `start-lingma-with-vpn.ps1`:
   ```powershell
   # Conectar VPN
   Write-Host "Conectando VPN..." -ForegroundColor Cyan
   # Ajustar comando según tu cliente VPN
   Start-Process "C:\Path\To\Your\VPN\client.exe" -ArgumentList "--connect"
   
   # Esperar conexión
   Start-Sleep -Seconds 10
   
   # Verificar VPN
   $vpnConnected = ipconfig | Select-String "AnyConnect|GlobalProtect|Forti"
   if ($vpnConnected) {
       Write-Host "VPN conectado exitosamente" -ForegroundColor Green
       
       # Limpiar DNS
       ipconfig /flushdns
       
       # Iniciar Lingma
       Write-Host "Iniciando servicio Lingma..." -ForegroundColor Cyan
       Start-Process "C:\Users\$env:USERNAME\AppData\Local\.lingma\bin\1.1.2\x86_64-pc-windows-msvc\Lingma.exe" -ArgumentList "start"
       
       # Esperar
       Start-Sleep -Seconds 5
       
       # Abrir IDE
       Write-Host "Abriendo IDE..." -ForegroundColor Cyan
       Start-Process "devenv.exe"  # Para Visual Studio
       # o
       Start-Process "idea64.exe"  # Para IntelliJ
   } else {
       Write-Host "Error: No se pudo conectar la VPN" -ForegroundColor Red
       exit 1
   }
   ```

### 3.6 Preguntas Frecuentes sobre VPN

#### ¿Puedo usar Lingma sin VPN?

**Depende de tu empresa:**
- ✅ **Sí**, si tu empresa permite acceso directo a servicios cloud
- ❌ **No**, si tu empresa bloquea todo el tráfico externo sin VPN

**Cómo verificar:**
```bash
# Desconecta la VPN e intenta
ping lingma-api.tongyi.aliyun.com
```

#### ¿La VPN afecta el rendimiento de Lingma?

**Sí, puede afectar:**
- **Latencia aumentada:** El tráfico pasa por más saltos de red
- **Ancho de banda limitado:** La VPN puede tener límites de velocidad
- **Procesamiento adicional:** Encriptación/desencriptación consume tiempo

**Mitigación:**
- Usa servidores VPN cercanos
- Solicita a TI QoS (Quality of Service) para herramientas de desarrollo
- Configura caché agresivo en Lingma

#### ¿Necesito configurar algo especial si cambio entre oficina y casa?

**Sí, recomendado:**

1. **Perfil Oficina (con VPN corporativa):**
   ```json
   {
     "http_proxy": "http://proxy.empresa.com:8080",
     "vpn_required": true
   }
   ```

2. **Perfil Casa (sin VPN):**
   ```json
   {
     "http_proxy": null,
     "vpn_required": false
   }
   ```

3. **Script para cambiar perfiles:**

   Crea `switch-lingma-profile.ps1`:
   ```powershell
   param(
       [Parameter(Mandatory=$true)]
       [ValidateSet("office", "home")]
       [string]$Profile
   )
   
   $configPath = "C:\Users\$env:USERNAME\AppData\Local\.lingma\config.json"
   
   if ($Profile -eq "office") {
       $config = @{
           http_proxy = "http://proxy.empresa.com:8080"
           https_proxy = "http://proxy.empresa.com:8080"
           vpn_required = $true
       } | ConvertTo-Json
   } else {
       $config = @{
           http_proxy = $null
           https_proxy = $null
           vpn_required = $false
       } | ConvertTo-Json
   }
   
   $config | Set-Content $configPath
   Write-Host "Perfil '$Profile' activado. Reinicia el IDE." -ForegroundColor Green
   ```

   **Uso:**
   ```powershell
   .\switch-lingma-profile.ps1 -Profile office
   .\switch-lingma-profile.ps1 -Profile home
   ```

---

## 4. Limpieza de Caché

### 3.1 Limpiar Caché DNS (Windows)

**Objetivo:** Eliminar entradas DNS obsoletas que pueden causar problemas de conexión.

**Pasos:**

1. Abra PowerShell o CMD **como administrador**
2. Ejecute:

```bash
ipconfig /flushdns
```

**Mensaje esperado:**
```
Se vació correctamente la caché de resolución de DNS.
```

### 3.2 Limpiar Caché DNS (macOS)

**Solo si usa macOS:**

```bash
sudo killall -HUP mDNSResponder
```

### 3.3 Eliminar Directorio .lingma (Limpieza Completa)

**Advertencia:** Esto eliminará toda la configuración local de Lingma. Deberá volver a configurarlo.

#### En Windows:

**Ruta:**
```
C:\Users\[SU_USUARIO]\.lingma
```

**Pasos:**

1. Cierre completamente el IDE
2. Finalice cualquier proceso de Lingma en el Administrador de Tareas
3. Abra el Explorador de Archivos
4. Navegue a: `C:\Users\[SU_USUARIO]\`
5. Localice la carpeta `.lingma`
6. Elimine la carpeta completa (Shift + Supr para eliminación permanente)
7. Vacíe la papelera de reciclaje

#### En macOS:

**Ruta:**
```
~/.lingma
```

**Comando:**
```bash
rm -rf ~/.lingma
```

---

## 4. Reinicio y Solución de Problemas

### 4.1 Reiniciar el IDE con Privilegios

**Pasos:**

1. Cierre completamente el IDE
2. Haga clic derecho en el icono del IDE
3. Seleccione **"Ejecutar como administrador"**
4. Abra un proyecto existente (no vacío)
5. Intente iniciar sesión en Lingma nuevamente

### 4.2 Iniciar Manualmente el Servicio Lingma

**Cuando usar esto:** Si los pasos anteriores no funcionaron.

**Pasos:**

1. **Navegar al directorio de Lingma:**

   Abra PowerShell y ejecute:
   ```bash
   cd C:\Users\[SU_USUARIO]\AppData\Local\.lingma\bin
   ```

2. **Identificar la versión y arquitectura:**

   Liste los directorios disponibles:
   ```bash
   dir
   ```

   Verá algo como:
   ```
   1.0.0
   1.1.2
   ```

3. **Navegar a la carpeta del ejecutable:**

   ```bash
   cd 1.1.2\x86_64-pc-windows-msvc
   ```
   
   *Nota: El nombre exacto puede variar según la versión*

4. **Iniciar el servicio:**

   ```bash
   .\Lingma.exe start
   ```

5. **Verificar que inició correctamente:**

   Debería ver un mensaje como:
   ```
   Lingma service started successfully
   ```

6. **Volver al IDE:**

   - Regrese a su IDE
   - Haga clic en el botón de **Iniciar Sesión** de Lingma
   - Complete el proceso de autenticación

### 4.3 Verificar Estado del Servicio

**En PowerShell:**
```bash
Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"}
```

Debe mostrar el proceso de Lingma en ejecución.

---

## 5. Solución de Errores Comunes

### 5.1 Error: "Programa Incompatible" en Windows

**Causa:** Descompresión incompleta o corrupta de los archivos de Lingma.

**Solución:**

#### Paso 1: Cambiar Ruta de Extracción

1. En el IDE, vaya a **Extensiones** → **Lingma**
2. Haga clic en el icono de **engranaje** (Configuración) en la esquina inferior derecha
3. Seleccione **Configuración Avanzada**
4. Busque **Ruta de Extracción** o **Extraction Path**
5. Cambie a una ruta fuera de la unidad C, por ejemplo:
   ```
   D:\Tools\Lingma
   ```
6. **Importante:** La carpeta debe estar vacía o no existir
7. Haga clic en **Guardar**

#### Paso 2: Reiniciar el IDE

1. Cierre completamente el IDE
2. Espere 10 segundos
3. Abra el IDE nuevamente (como administrador)
4. Lingma comenzará a extraer los archivos en la nueva ubicación
5. Espere a que complete la extracción (puede tomar 2-5 minutos)

#### Paso 3: Verificar

1. Abra una ventana de PowerShell
2. Verifique que los archivos existen:
   ```bash
   dir D:\Tools\Lingma\bin
   ```
3. Intente iniciar sesión en Lingma

### 5.2 Error: "No se puede conectar al servidor"

**Posibles causas:**
- Proxy mal configurado
- Firewall bloqueando la conexión
- DNS incorrecto

**Solución:**

1. **Verificar configuración del proxy:**
   ```bash
   # En PowerShell
   echo $env:HTTP_PROXY
   echo $env:HTTPS_PROXY
   ```

2. **Probar sin proxy (si aplica):**
   - Temporalmente deshabilite el proxy en config.json
   - Pruebe conexión directa

3. **Cambiar DNS:**
   - Abra "Configuración de red" en Windows
   - Cambie DNS a Google DNS: `8.8.8.8` y `8.8.4.4`

4. **Verificar firewall:**
   - Panel de Control → Firewall de Windows
   - Verifique que el IDE y Lingma estén permitidos

### 5.3 Error: "Autenticación fallida"

**Solución:**

1. **Limpiar credenciales almacenadas:**
   - Panel de Control → Credenciales de Windows
   - Busque credenciales relacionadas a Lingma
   - Elimínelas

2. **Regenerar token:**
   - En el IDE, cierre sesión de Lingma
   - Elimine el directorio `.lingma` (sección 3.3)
   - Reinicie el IDE
   - Vuelva a iniciar sesión

### 5.4 Error: "Tiempo de espera agotado"

**Causa:** La conexión está muy lenta o bloqueada.

**Solución:**

1. **Aumentar timeout en config.json:**
   ```json
   {
     "http_proxy": "http://proxy.empresa.com:8080",
     "timeout": 60000,
     "retry_count": 3
   }
   ```

2. **Verificar velocidad de conexión:**
   ```bash
   curl -w "@curl-format.txt" -o /dev/null -s https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```

3. **Contactar al departamento de TI** para optimizar la ruta al servidor

---

## Apéndice A: Comandos Útiles

### Ver procesos de Lingma
```bash
Get-Process | Where-Object {$_.ProcessName -like "*Lingma*"}
```

### Detener servicio Lingma
```bash
cd C:\Users\[SU_USUARIO]\AppData\Local\.lingma\bin\[VERSION]\[ARQUITECTURA]
.\Lingma.exe stop
```

### Ver logs de Lingma
```bash
Get-Content C:\Users\[SU_USUARIO]\AppData\Local\.lingma\logs\lingma.log -Tail 50
```

### Probar conexión con proxy
```bash
$env:HTTP_PROXY="http://proxy.empresa.com:8080"
curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
```

---

## Apéndice B: Estructura de Directorios de Lingma

```
C:\Users\[USUARIO]\.lingma\
├── bin\
│   └── [VERSION]\
│       └── [ARQUITECTURA]\
│           ├── Lingma.exe
│           └── otros archivos
├── config\
│   └── config.json
├── logs\
│   └── lingma.log
└── cache\
    └── archivos temporales
```

---

## Apéndice C: Contacto y Soporte

Si después de seguir todos los pasos el problema persiste:

1. **Recolectar información:**
   - Versión del IDE
   - Versión de Lingma
   - Sistema operativo
   - Logs de error (archivo `lingma.log`)

2. **Contactar al departamento de TI:**
   - Proporcionar URLs que necesitan whitelist:
     - `https://lingma-api.tongyi.aliyun.com`
     - `https://devops.aliyun.com`

3. **Soporte oficial:**
   - Documentación: https://help.aliyun.com/product/42154.html
   - Email de soporte: lingma-support@alibabacloud.com

---

## Historial de Revisiones

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0 | 28/03/2026 | Versión inicial del manual |

---

**Nota:** Este manual asume que tiene permisos de administrador en su equipo. Si no los tiene, solicite asistencia al departamento de TI.
