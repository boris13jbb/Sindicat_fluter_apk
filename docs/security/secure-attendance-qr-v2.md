# Secure Attendance QR V2 — Offline-First (SATT2)

**Estado:** implementación LOCAL (sin deploy).
**Release baseline:** `v1.4.9-vote-active-member-rules` (`d9ffe19`).
**Principio:** el cliente muestra y captura; el servidor decide el registro canónico.

## Protocolo

| Elemento | Valor |
|----------|-------|
| Versión | `2` (`SATT2`) |
| Challenge | `SATT2C` (firmado por scanner Ed25519) |
| Response | `SATT2R` (firmado por dispositivo del socio Ed25519) |
| Rotación challenge | 15 s |
| Validez response | 20 s |
| Criptografía | Ed25519 |
| Serialización | Canonical UTF-8 `key=value` orden fijo |

## Confianza de firmas del servidor

Las credenciales `SATT2CRED` y los paquetes `SATT2PKG` se verifican antes de
guardarse y cada vez que se recuperan del almacenamiento offline. La fuente de
confianza es un keyring de claves públicas fijado durante el build:

```text
--dart-define=ATTENDANCE_QR_TRUSTED_SERVER_KEYS=v1:<public-key>,v2:<public-key>
```

Cada clave pública es Ed25519 raw de 32 bytes, codificada como base64url
canónico sin padding (43 caracteres). Una configuración vacía o inválida
bloquea solamente Secure Attendance con
`attendance-server-trust-not-configured`. Una versión no incluida en el
keyring se rechaza con `unknown-server-key-version`.

`serverPublicKey` puede viajar en una respuesta únicamente como metadata de
diagnóstico. Nunca establece confianza ni reemplaza una clave fijada; si está
presente debe coincidir con el pin correspondiente a `keyVersion`.

La credencial también se vincula al UID autenticado, socio enrolado, ID de
dispositivo y clave pública local. El paquete se vincula al evento, ID del
escáner y clave pública local del escáner. Las ventanas firmadas se validan
contra los máximos emitidos por el backend y se rechazan timestamps futuros o
fuera de rango. Los IDs de dispositivo duplicados en participantes invalidan el
paquete.

El backend acepta la semilla privada solo como 32 bytes codificados en
base64url canónico sin padding. Una clave ausente produce
`signing-key-missing`; una representación ambigua o inválida produce
`signing-key-invalid`. Ambos casos responden 503 sin exponer el secret.

### Rotación de clave

1. Generar el keypair v2 fuera del repositorio.
2. Distribuir clientes con el keyring público v1+v2.
3. Esperar la adopción mínima definida para esos clientes.
4. Cambiar la versión activa del servidor a v2 junto con su secret.
5. Emitir todas las credenciales y paquetes nuevos con `keyVersion = v2`.
6. Mantener la clave pública v1 mientras puedan existir artefactos v1 válidos.
7. Esperar la validez máxima de credenciales más la ventana máxima de paquetes.
8. Retirar v1 del keyring solo en una versión posterior del cliente.
9. Deshabilitar la versión anterior del secret después de la ventana acordada.
10. Destruirla únicamente después de la ventana de recuperación definida.

La clave privada y las semillas TEST-ONLY nunca se incluyen en builds de
producción. Cambiar el secret sin actualizar de forma coherente la versión
activa está prohibido porque produciría artefactos mal etiquetados.

## Modelo de amenazas

| ID | Amenaza | Vector | Impacto | Control | Riesgo residual |
|----|---------|--------|---------|---------|-----------------|
| ATT-01 | QR fabricado con workerCode | JSON legacy / string plano | Asistencia falsa | Secure path rechaza legacy; sin fallback workerCode | Bypass solo vía registro manual auditado |
| ATT-02 | Screenshot del QR | Foto de SATT2R | Replay corto | TTL 20 s + un solo uso de challenge/nonce | Relay en tiempo real (~15–20 s) |
| ATT-03 | Replay | Reenviar SATT2R | Duplicado | Nonce + challengeId usados en store/servidor | — |
| ATT-04 | QR de otro evento | Response para EVENT_A en EVENT_B | Asistencia en evento incorrecto | Binding `eventId` firmado | — |
| ATT-05 | QR de otro scanner | Challenge SCANNER_A en B | Confusión de estación | Binding `scannerId` firmado | — |
| ATT-06 | QR expirado | Response fuera de ventana | Aceptación tardía | `expiresAtTrusted` del challenge | Reloj offline del scanner |
| ATT-07 | Reloj del socio manipulado | Cambiar hora del teléfono | Bypass TTL | Scanner es autoridad de ventana; timestamp socio solo evidencia | — |
| ATT-08 | Reloj del scanner manipulado | Cambiar hora del dispositivo operador | Ventana incorrecta | Ancla verificada + progresión monotónica `Stopwatch`; estados `clock_*` | Reinicio y rollback manual antes de recargar siguen limitados por validación de timestamps firmados |
| ATT-09 | Member inactive | Socio dado de baja | Voto/asistencia indebida | Emisión y sync validan status | Snapshot offline desactualizado → review |
| ATT-10 | Usuario sin memberId | Cuenta no vinculada | Emisión de credencial | Enrollment exige memberId | — |
| ATT-11 | Member inexistente | memberId huérfano | Identidad inválida | Exists + active | — |
| ATT-12 | Dispositivo socio revocado | Clave robada | Firma válida hasta revoke | status `revoked` en devices + package snapshot | Offline con snapshot previo |
| ATT-13 | Scanner no autorizado | App operador sin enrollment | Challenges falsos | Scanner device aprobado por admin | — |
| ATT-14 | Modificación DB local | Editar receipts | Sync fraudulento | Receipt firmado por scanner; revalidación servidor | — |
| ATT-15 | Duplicado offline | Doble escaneo | Contadores falsos | Índice local `eventId+memberId` | Dos scanners sin sync (ATT-16) |
| ATT-16 | Dos scanners offline | Mismo socio en A y B | Duplicado canónico | Sync idempotente; segundo → DUPLICATE/REVIEW | Decisión humana en review |
| ATT-17 | Escritura Firestore directa | Cliente crea `secure_qr_v2` | Bypass crypto | Rules: create secure_qr_v2 denegado a clientes | Manual override separado |
| ATT-18 | GPS falso | Spoof ubicación | Bypass geofence | GPS es auditoría/refuerzo, no prueba única | Spoofing siempre residual |
| ATT-19 | QR legacy | JSON workerCode | Bypass V2 | Secure scanner rechaza legacy | Clientes antiguos hasta cutover Rules |
| ATT-20 | Extracción de clave privada | Root/malware/Web storage | Suplantación de dispositivo | SecureKeyStore; Web = LIMITED_ASSURANCE | Web/comprometido |

**No afirmamos** que GPS pruebe presencia física ni que el sistema sea imposible de atacar. El relay en tiempo real (mostrar QR vivo a distancia) permanece como riesgo residual operativo.

## Colecciones

- `attendance_member_devices/{deviceId}` — solo backend
- `attendance_scanner_devices/{scannerId}` — solo backend / admin approve
- `attendance_offline_packages` (opcional metadata) — solo backend
- Canonical write: `attendance_events/{eventId}/asistencias/{deterministicId}` vía Admin SDK

## Rollout seguro (NO ejecutar ahora)

1. Functions nuevas
2. Flutter nuevo
3. Validación
4. Rules cutover (bloquear `secure_qr_v2` cliente)
5. Deshabilitar QR legacy en UI

Un deploy prematuro de Rules puede romper clientes antiguos.

## Capacidades por plataforma

| Plataforma | Offline HIGH_ASSURANCE | Notas |
|------------|------------------------|-------|
| Android/iOS | Sí (secure storage) | Preferido |
| Windows nativo | No | Secure Attendance online no está soportado en este release |
| Web/PWA | LIMITED_ASSURANCE | No afirmar hardware-backed keys |

## Registro manual excepcional

Camino **separado** de Secure QR:

- `metodoRegistro = MANUAL_OVERRIDE`
- Motivo (`justificacion`) ≥ 3 caracteres (Rules + cliente)
- `registradoPor = auth.uid`
- Member desde padrón (no crear persona/member desde QR/texto libre)
- Nunca `SECURE_QR_V2` desde cliente

Legacy `MANUAL` / `ESCANEO_*` permanece para clientes antiguos, sin poder elevar a secure.

## Política sync: member inactive

Si al sincronizar el `member` está inactive/revocado:

- **No** se crea asistencia canónica silenciosamente.
- Resultado: `review` + code `member-inactive-at-sync`.

## Scanner devices

- Registro por operador → `pending`
- Aprobación solo ADMIN/SUPERADMIN → `active`
- `pending`/`revoked` no pueden preparar paquete ni sincronizar

## App Check (código listo — configuración externa pendiente)

| Campo | Estado |
|-------|--------|
| Clasificación | **CODE READY / PRE-PRODUCTION CONFIGURATION REQUIRED** |
| Server-side enforcement en código | **REQUIRED por defecto en producción** |
| Flag legacy `ATTENDANCE_QR_REQUIRE_APPCHECK` | **Ignorado** (no debe usarse para “apagar” seguridad) |
| Emulator | Bypass solo con `FUNCTIONS_EMULATOR=true` |
| Tests | Bypass explícito `ATTENDANCE_QR_SKIP_APPCHECK=1` o verificador inyectado |
| Cliente envía `X-Firebase-AppCheck` | Sí (online `_post`) + `Authorization: Bearer` |
| Offline SATT2M (rotación local) | **No** pide App Check |
| Deploy / Console | **Todavía NO ejecutado** |

### Inventario endpoints online

| Endpoint | Auth | App Check | Rol |
|----------|------|-----------|-----|
| `/api/attendance-enroll-member-device` | Bearer UID | REQUIRED (prod) | Socio con `memberId` activo |
| `/api/attendance-prepare-offline-credential` | Bearer UID | REQUIRED (prod) | Socio enrolado |
| `/api/attendance-prepare-offline-event` | Bearer UID | REQUIRED (prod) | Operador / admin |
| `/api/attendance-register-scanner-device` | Bearer UID | REQUIRED (prod) | Operador |
| `/api/attendance-approve-scanner-device` | Bearer UID | REQUIRED (prod) | ADMIN / SUPERADMIN |
| `/api/attendance-sync-offline-batch` | Bearer UID | REQUIRED (prod) | Scanner activo |

Auth y App Check son independientes: uno válido sin el otro → **DENIED**.

### Cliente por plataforma

| Plataforma | Provider |
|------------|----------|
| Android debug | `AndroidProvider.debug` |
| Android release | `AndroidProvider.playIntegrity` |
| iOS debug | `AppleProvider.debug` |
| iOS release | `AppleProvider.appAttest` |
| Web | `ReCaptchaV3Provider` (default) o `ReCaptchaEnterpriseProvider` vía dart-define |
| Windows | **UNSUPPORTED_FOR_THIS_FLOW** (no bypass global; usar Web/Android/iOS para online) |

### Configuración Web (dart-define)

```text
--dart-define=FIREBASE_APPCHECK_WEB_SITE_KEY=<site-key-from-console>
--dart-define=FIREBASE_APPCHECK_WEB_PROVIDER=recaptcha_v3
```

Opcional enterprise:

```text
--dart-define=FIREBASE_APPCHECK_WEB_PROVIDER=recaptcha_enterprise
```

Sin site key en Web: error controlado `app-check-web-not-configured` (no degradación silenciosa).
La site key **no** se hardcodea en el repositorio.

### Pasos externos todavía NO ejecutados (bloquean deploy, no CI)

1. **Android:** registrar app en Firebase App Check (Play Integrity).
2. **iOS:** registrar App Attest / debug tokens según entorno.
3. **Web:** registrar provider reCAPTCHA en Firebase Console y obtener site key.
4. **Build/release:** pasar `FIREBASE_APPCHECK_WEB_SITE_KEY` en CI/CD de Web.
5. **Deploy Functions:** el código ya exige App Check en producción; falta deploy autorizado.

**No se afirma** “ENFORCED IN PRODUCTION” hasta que exista deploy real + providers registrados en Console.

### Offline package scalability

| Campo | Valor |
|-------|--------|
| Device query | Paginada (`status==active` + `orderBy(__name__)`, page 200) |
| Member loads | `getAll` por chunks de 100 (sin N+1) |
| Límite silencioso 500 | **Eliminado** |
| Capacidad mínima probada | **≥ 5000** dispositivos activos (`attendance_member_devices`) |
| Máximo operativo | `MAX_OFFLINE_PACKAGE_DEVICES = 7500` (headroom sobre 5000) |
| Si se supera | HTTP **413** `offline-package-too-large` (nunca recorte parcial) |
| Tamaño JSON participants (medido fixture) | ~0.14 MB @600 · ~1.16 MB @5000 · ~1.74 MB @7500 |
| Multi-device | Varios `memberDeviceId` por socio permitidos |

### Debug Web

El plugin `firebase_app_check` 0.3.x no expone un `DebugProvider` web.
En desarrollo Web usar site key de prueba vía dart-define y, si Firebase lo requiere,
configurar el debug token del SDK JS según la documentación oficial de Firebase App Check
(`self.FIREBASE_APPCHECK_DEBUG_TOKEN`) — sin credenciales reales en el repo.

## SATT2M — QR personal dinámico (modo cotidiano)

| Campo | Valor |
|-------|-------|
| Type | `SATT2M` |
| Rotación | 20 s |
| Validez máxima | 30 s |
| Firma | Ed25519 del dispositivo enrolado |
| Default de evento | `secureQrMode = dynamic_member_qr` |
| Alta seguridad | `secureQrMode = challenge_response` (SATT2C/SATT2R) |

El socio ve **MI CÓDIGO DE ASISTENCIA** en Perfil → Asistencia segura.
El QR se genera offline tras activar la credencial una vez con Internet.
