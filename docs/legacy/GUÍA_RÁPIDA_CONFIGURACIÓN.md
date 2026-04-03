# 🚀 GUÍA RÁPIDA - Configuración de Lingma

## ¿QUÉ NECESITAS HACER AHORA?

Tienes **DOS** archivos para configurar Lingma. Usa el correcto según tu situación:

---

## 🏠 CASO 1: Estás en Casa (LO MÁS PROBABLE)

### ¿Necesitas VPN obligatoria según tu empresa?

#### ❌ NO - Puedo usar internet normalmente

**Usa este archivo:**
```
configurar_lingma_casa.bat
```

**Instrucciones:**
1. Click derecho en `configurar_lingma_casa.bat`
2. "Ejecutar como administrador"
3. Listo ✅

**Resultado:**
- ✅ Sin VPN
- ✅ Sin proxy
- ✅ Conexión directa

---

#### ✅ SÍ - Mi empresa requiere ZenVPN siempre

**Usa este archivo:**
```
configurar_lingma_zenvpn.bat
```

**Instrucciones:**
1. Click derecho en `configurar_lingma_zenvpn.bat`
2. "Ejecutar como administrador"
3. Elige opción **2** (CASA con ZenVPN obligatorio)
4. Instala ZenVPN si no lo tienes
5. Conecta ZenVPN antes de usar Lingma

**Resultado:**
- ✅ ZenVPN activo
- ✅ Sin proxy adicional
- ✅ Lingma funciona a través de VPN

---

## 🏢 CASO 2: Vas a la Oficina

Cuando estés físicamente en la oficina:

**Usa este archivo:**
```
configurar_lingma_zenvpn.bat
```

**Instrucciones:**
1. Click derecho → "Ejecutar como administrador"
2. Elige opción **3** (OFICINA)
3. Contacta a TI para obtener datos del proxy
4. Edita `switch-lingma-profile.ps1` con los datos
5. Ejecuta: `.\switch-lingma-profile.ps1 -Profile office`

---

## 📋 RESUMEN VISUAL

```
┌──────────────────────────────────────┐
│  ¿Dónde estás trabajando?            │
└──────────────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
   CASA       OFICINA
     │           │
     ▼           ▼
┌─────────┐ ┌──────────────┐
│¿Necesitas│ │Ve a la      │
│VPN?      │ │sección      │
└────┬─────┘ │OFICINA       │
     │       └──────────────┘
┌────┴────┐
│         │
NO       SÍ
│         │
▼         ▼
casa      zenvpn
.bat      .bat
(Opción 1) (Opción 2)
```

---

## 🎯 RECOMENDACIÓN PARA AHORA

Como estás en casa y mencionaste ZenVPN pero NO has dicho que sea obligatorio:

### PRUEBA PRIMERO ESTO:

1. **Ejecuta configuración de casa SIN VPN:**
   ```
   Click derecho → configurar_lingma_casa.bat → Ejecutar como administrador
   ```

2. **Abre tu IDE e inicia sesión en Lingma**

3. **¿Funciona?**
   - ✅ **SÍ** → ¡Perfecto! No necesitas VPN ni proxy
   - ❌ **NO** → Entonces considera usar ZenVPN

4. **Si necesitas ZenVPN:**
   ```
   Click derecho → configurar_lingma_zenvpn.bat → Ejecutar como administrador
   Opción 2 → Instalar ZenVPN → Conectar → Usar Lingma
   ```

---

## 📁 ARCHIVOS QUE TIENES

| Archivo | Para qué sirve | Cuándo usar |
|---------|---------------|-------------|
| `configurar_lingma_casa.bat` | Configura sin VPN, sin proxy | Casa - Sin VPN requerida |
| `configurar_lingma_zenvpn.bat` | Menú con 3 opciones | Casa con VPN o Oficina |
| `CONFIGURACION_CASA_LEEME.md` | Guía detallada paso a paso | Si quieres más información |
| `CONFIGURACION_ZENVPN_LINGMA.md` | Info sobre VPN vs Proxy | Para entender la diferencia |
| `MANUAL_CONFIGURACION_RED_LINGMA.md` | Manual completo | Referencia general |
| `switch-lingma-profile.ps1` | Script avanzado PowerShell | Cambio rápido de perfiles |

---

## ⚡ ACCIÓN INMEDIATA

### Lo que debes hacer YA:

1. **Abre el Explorador de Archivos**
2. **Navega a:** `d:\Sindicat_fluter_apk`
3. **Busca:** `configurar_lingma_casa.bat`
4. **Click derecho** → **"Ejecutar como administrador"**
5. **Espera** a que termine
6. **Reinicia** tu IDE
7. **Prueba** iniciar sesión en Lingma

**¿Funciona?**
- ✅ **SÍ** → ¡Felicidades! Terminaste 🎉
- ❌ **NO** → Lee `CONFIGURACION_ZENVPN_LINGMA.md` para siguientes pasos

---

## 🔍 VERIFICAR CONFIGURACIÓN

Para ver qué configuración tienes activa:

```powershell
Get-Content C:\Users\boris\AppData\Local\.lingma\config.json
```

**Deberías ver algo como:**

### Si usaste `configurar_lingma_casa.bat`:
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_required": false,
  "profile": "home"
}
```

### Si usaste `configurar_lingma_zenvpn.bat` (opción 2):
```json
{
  "http_proxy": null,
  "https_proxy": null,
  "vpn_required": true,
  "vpn_type": "zenvpn",
  "profile": "home_vpn"
}
```

---

## 💡 CONSEJOS IMPORTANTES

1. **Siempre ejecuta como administrador** (click derecho)
2. **Cierra el IDE** antes de cambiar configuración
3. **Espera 5 segundos** después de configurar
4. **Reinicia el IDE** después de configurar
5. **Guarda los emails de TI** por si necesitas ayuda

---

## 🆘 SI NADA FUNCIONA

Contacta a tu departamento de TI con esta información:

```
Problema: Lingma pide configuración de red
Ubicación: Casa
URLs necesarias:
  - https://lingma-api.tongyi.aliyun.com
  - https://devops.aliyun.com

¿Requieren VPN? [SÍ/NO]
¿Requieren Proxy? [SÍ/NO - si es SÍ, pedir datos]

Datos de mi sistema:
  - Windows 22H2
  - PowerShell 7
  - Usuario: boris
```

---

## 📞 PREGUNTAS PARA TU DEPARTAMENTO DE TI

Si necesitas contactar a TI, pregunta esto:

1. **¿Es obligatorio usar ZenVPN para trabajar desde casa?**
2. **¿Necesito configurar algún proxy adicional?**
3. **¿Pueden añadir estas URLs a la lista blanca?**
   - `https://lingma-api.tongyi.aliyun.com`
   - `https://devops.aliyun.com`
4. **¿Hay algún servidor VPN específico que deba usar?**

---

¡Listo! Ahora ya sabes qué hacer. 

**TL;DR:** Ejecuta `configurar_lingma_casa.bat` como administrador y reinicia tu IDE. 🚀
