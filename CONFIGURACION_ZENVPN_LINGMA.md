# 🔐 Configuración con ZenVPN para Lingma

## ¿Qué es ZenVPN?

El enlace que proporcionaste (`https://dhqiltxi1gh39.cloudfront.net/...#zenVPN`) es para descargar/configurar **ZenVPN**, que es un cliente VPN, NO un proxy.

---

## Diferencia entre VPN y Proxy

| Característica | VPN | Proxy |
|----------------|-----|-------|
| **Funcionamiento** | Crea un túnel cifrado a una red remota | Actúa como intermediario para tráfico web |
| **Alcance** | Todo el tráfico del sistema | Solo aplicaciones configuradas |
| **Configuración en Lingma** | No requiere configuración especial | Requiere URL del proxy |
| **Uso típico** | Acceder a recursos corporativos | Filtrar/cachear tráfico web |

---

## Configuración Correcta para CASA con ZenVPN

### Escenario 1: Trabajas desde casa SIN necesidad de VPN

**Este es tu caso actual** - Si estás en casa y puedes acceder a internet directamente:

✅ **NO uses VPN**  
✅ **NO uses proxy**  
✅ **Configuración directa**

**Archivo config.json:**
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_required": false,
  "profile": "home"
}
```

**Para configurar, ejecuta:**
```powershell
.\configurar_lingma_casa.bat
```

---

### Escenario 2: Tu empresa REQUIERE ZenVPN incluso desde casa

Si tu departamento de TI te ha indicado que **debes usar ZenVPN** para trabajar:

#### Paso 1: Descargar e instalar ZenVPN

1. Abre el enlace que proporcionaste:
   ```
   https://dhqiltxi1gh39.cloudfront.net/386a1dc0-2471-4284-add7-6061e183e57c#zenVPN
   ```

2. Descarga el instalador de ZenVPN
3. Instálalo siguiendo las instrucciones
4. Obtén tus credenciales de acceso (usuario/contraseña o archivo de configuración)

#### Paso 2: Conectar ZenVPN

1. Abre ZenVPN
2. Inicia sesión con tus credenciales
3. Conéctate al servidor VPN indicado por tu empresa
4. Verifica que estás conectado (deberías ver un icono de candado o "Connected")

#### Paso 3: Configurar Lingma con VPN activa

**Importante:** Con ZenVPN activo, generalmente NO necesitas configurar proxy adicional.

Crea el archivo `config.json` manualmente:

1. Abre PowerShell como administrador
2. Ejecuta:
   ```powershell
   New-Item -ItemType Directory -Force -Path "C:\Users\boris\AppData\Local\.lingma"
   
   @"
   {
     "http_proxy": null,
     "https_proxy": null,
     "vpn_required": true,
     "vpn_type": "zenvpn",
     "profile": "home_with_vpn",
     "timeout": 90000,
     "retry_count": 5
   }
   "@ | Set-Content "C:\Users\boris\AppData\Local\.lingma\config.json" -Encoding UTF8
   ```

3. Reinicia tu IDE

---

## Verificar si Realmente Necesitas ZenVPN

### Test 1: Sin VPN activada

1. **Asegúrate de que ZenVPN esté DESCONECTADO**
2. Abre PowerShell
3. Ejecuta:
   ```powershell
   curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```

**Resultado:**
- ✅ Si responde `pong` → **NO necesitas VPN**, usa el perfil casa normal
- ❌ Si NO responde o da error → **Probablemente necesitas VPN**

### Test 2: Con VPN activada

1. **Conecta ZenVPN**
2. Ejecuta:
   ```powershell
   curl https://lingma-api.tongyi.aliyun.com/algo/api/v1/ping
   ```

**Resultado:**
- ✅ Si responde `pong` → Necesitas VPN activa para usar Lingma
- ❌ Si tampoco responde → Hay otro problema (firewall, proxy adicional, etc.)

---

## Posibles Configuraciones de tu Empresa

### Configuración A: Solo VPN (Más común)

Tu empresa usa **exclusivamente ZenVPN** sin proxy adicional.

**Configuración:**
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_required": true,
  "profile": "vpn_only"
}
```

**Uso diario:**
1. Conectar ZenVPN
2. Abrir IDE
3. Usar Lingma normalmente

---

### Configuración B: VPN + Proxy Corporativo

Algunas empresas usan **ambos**: VPN para acceso a la red + Proxy para salir a internet.

**Necesitarás preguntar a TI:**
- ¿Se requiere proxy adicional cuando usas ZenVPN?
- ¿Cuál es la URL del proxy?
- ¿Requiere autenticación?

**Si te dan datos de proxy, configura:**
```json
{
  "http_proxy": "http://usuario:clave@proxy.empresa.com:8080",
  "https_proxy": "http://usuario:clave@proxy.empresa.com:8080",
  "vpn_required": true,
  "vpn_type": "zenvpn",
  "profile": "office"
}
```

---

## Script Actualizado para ZenVPN

He creado un script específico para tu configuración con ZenVPN:

### `configurar_lingma_zenvpn.bat`

```batch
@echo off
REM ============================================
REM   Configurador Lingma con ZenVPN
REM ============================================

echo.
echo ============================================
echo   Configurando Lingma con ZenVPN
echo ============================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Ejecuta como administrador
    pause
    exit /b 1
)

echo Creando directorio...
if not exist "C:\Users\boris\AppData\Local\.lingma" (
    mkdir "C:\Users\boris\AppData\Local\.lingma"
)

echo.
echo Selecciona tu configuracion:
echo.
echo 1. CASA sin VPN (conexion directa)
echo 2. CASA con ZenVPN obligatorio
echo 3. OFICINA con VPN + Proxy
echo.
set /p opcion="Opcion (1-3): "

if "%opcion%"=="1" goto CONFIG_CASA
if "%opcion%"=="2" goto CONFIG_VPN
if "%opcion%"=="3" goto CONFIG_OFICINA

echo Opcion no valida
pause
exit /b 1

:CONFIG_CASA
echo.
echo Configurando perfil CASA (sin VPN)...
(
echo {
echo   "http_proxy": null,
echo   "https_proxy": null,
echo   "vpn_required": false,
echo   "profile": "home"
echo }
) > "C:\Users\boris\AppData\Local\.lingma\config.json"
echo [OK] Configurado
goto FIN

:CONFIG_VPN
echo.
echo Configurando perfil ZENVPN...
(
echo {
echo   "http_proxy": null,
echo   "https_proxy": null,
echo   "vpn_required": true,
echo   "vpn_type": "zenvpn",
echo   "profile": "home_vpn"
echo }
) > "C:\Users\boris\AppData\Local\.lingma\config.json"
echo [OK] Configurado
echo.
echo IMPORTANTE: Debes conectar ZenVPN antes de usar Lingma
goto FIN

:CONFIG_OFICINA
echo.
echo Para configurar oficina necesitas editar manualmente
echo el archivo switch-lingma-profile.ps1 con los datos del proxy
pause
exit /b 1

:FIN
echo.
echo ============================================
echo   CONFIGURACION COMPLETADA
echo ============================================
echo.
echo Ahora:
echo 1. Cierra tu IDE completamente
echo 2. Espera 5 segundos
echo 3. Vuelve a abrir el IDE
echo 4. Inicia sesion en Lingma
echo.
pause
```

---

## Instrucciones Paso a Paso para Ti

### Situación Actual: Estás en Casa

**Paso 1: Determinar si necesitas ZenVPN**

Responde esta pregunta:
- ¿Tu empresa te ha dicho explícitamente que debes usar ZenVPN para trabajar desde casa?

**Si la respuesta es NO:**
→ Usa el perfil CASA normal (sin VPN, sin proxy)
→ Ejecuta: `.\configurar_lingma_casa.bat`

**Si la respuesta es SÍ:**
→ Continúa con el Paso 2

---

**Paso 2: Configurar con ZenVPN**

1. **Descarga ZenVPN:**
   - Abre: `https://dhqiltxi1gh39.cloudfront.net/386a1dc0-2471-4284-add7-6061e183e57c#zenVPN`
   - Descarga e instala el cliente

2. **Obtén credenciales:**
   - Contacta a tu departamento de TI
   - Pide: usuario, contraseña y servidor VPN

3. **Configura Lingma:**
   - Ejecuta como administrador:
     ```powershell
     .\configurar_lingma_zenvpn.bat
     ```
   - Selecciona opción **2** (CASA con ZenVPN obligatorio)

4. **Conecta ZenVPN:**
   - Abre ZenVPN
   - Inicia sesión
   - Conéctate al servidor

5. **Abre tu IDE:**
   - Cierra y vuelve a abrir
   - Inicia sesión en Lingma

---

## Resumen Visual

```
┌─────────────────────────────────────────┐
│  ¿Trabajas desde casa?                  │
└─────────────────────────────────────────┘
              │
              ▼
         ┌────┴────┐
         │ ¿Necesitas │
         │   VPN?     │
         └────┬────┘
              │
      ┌───────┴───────┐
      │               │
     NO              SÍ
      │               │
      ▼               ▼
┌──────────┐    ┌─────────────┐
│Perfil    │    │Instala      │
│CASA      │    │ZenVPN       │
│Sin proxy │    │             │
└──────────┘    └──────┬──────┘
                       │
                       ▼
                ┌─────────────┐
                │¿Proxy       │
                │adicional?   │
                └──────┬──────┘
                       │
              ┌────────┴────────┐
              │                 │
             NO               SÍ
              │                 │
              ▼                 ▼
       ┌─────────────┐   ┌─────────────┐
       │Solo VPN     │   │VPN + Proxy  │
       │config.json  │   │Config compleja│
       │vpn_required │   │Contacta TI  │
       │= true       │   │             │
       └─────────────┘   └─────────────┘
```

---

## Próximos Pasos

1. **Primero prueba SIN ZenVPN:**
   ```powershell
   .\configurar_lingma_casa.bat
   ```
   
2. **Prueba Lingma** en tu IDE

3. **Si funciona** → ¡Perfecto! No necesitas VPN

4. **Si NO funciona** → Entonces configura ZenVPN

---

## Contacto Importante

**Guarda esto:**
- Email de tu departamento de TI
- Teléfono de soporte técnico de tu empresa

**Preguntas clave para TI:**
1. ¿Es obligatorio usar ZenVPN para trabajar desde casa?
2. ¿Se necesita proxy adicional cuando uso ZenVPN?
3. ¿Cuáles son las credenciales para ZenVPN?
4. ¿Hay algún servidor VPN específico que deba usar?

---

¡Espero que esto aclare la confusión entre VPN y proxy! La mayoría de usuarios trabajando desde casa **NO necesitan VPN ni proxy**, solo conexión directa a internet.
