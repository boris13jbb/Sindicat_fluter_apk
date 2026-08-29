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
| ATT-08 | Reloj del scanner manipulado | Cambiar hora del dispositivo operador | Ventana incorrecta | Offset vs `serverTimeAtPreparation`; estados `clock_*` | Offline prolongado sin re-preparación |
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
| Windows | Sí si secure storage disponible | Verificar runtime |
| Web | LIMITED_ASSURANCE / ONLINE_ONLY | No afirmar hardware-backed keys |

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

## App Check (pre-deploy)

| Campo | Estado |
|-------|--------|
| Server-side App Check en attendance QR Functions | **NO ENFORCED** |
| Clasificación | **PRE-DEPLOY HARDENING REQUIRED** / **PRE-DEPLOY BLOCKER** |

No desplegar Functions de attendance QR a producción hasta exigir App Check
(o un control equivalente documentado) en los endpoints HTTP sensibles.
Este checkpoint Git **no** implementa App Check; solo deja el gap explícito.
