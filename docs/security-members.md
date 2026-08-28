# Seguridad de lectura — colección `members` y cuentas `users`

Fase **1.2** del plan de endurecimiento de seguridad del proyecto `sistema-integrado-sindicato`.

## Modelo de datos

| Colección | Contenido | Sensibilidad |
|-----------|-----------|--------------|
| `members` | Padrón de socios (nombre, cédula, email, teléfono, workerCode, modalidad) | Alta |
| `users` | Cuentas de aplicación (rol, email, memberId, isActive) | Alta administrativa |

Los socios **no** son lo mismo que las cuentas: un `users/{uid}` puede vincularse a `members/{memberId}`.

## Principio aplicado

- **Deny by default** en todo lo no expresamente permitido.
- Separación explícita **`get`** vs **`list`** en Firestore Rules.
- Búsquedas administrativas y validación de padrón en **Cloud Functions** con Admin SDK.
- La UI no sustituye la seguridad; solo oculta acciones.

## Matriz de permisos (lectura)

### `members`

| Rol | `get` documento | `list` / consultas |
|-----|-----------------|-------------------|
| Sin autenticar | ❌ | ❌ |
| VOTER / USER | ✅ solo si `users.memberId == memberId` | ❌ |
| OPERADOR_ASISTENCIA | ✅ | ✅ |
| ADMIN | ✅ | ✅ |
| SUPERADMIN | ✅ | ✅ |

### `users`

| Rol | `get` | `list` |
|-----|-------|--------|
| Sin autenticar | ❌ | ❌ |
| Usuario normal | ✅ solo `users/{su_uid}` | ❌ |
| ADMIN | ✅ solo propio perfil | ❌ |
| SUPERADMIN | ✅ cualquiera | ✅ |

### Escritura `members` (sin cambio funcional relevante)

- **create**: ADMIN+
- **update**: ADMIN o SUPERADMIN
- **delete**: SUPERADMIN

Campos críticos de `users` (rol, isActive, memberId) siguen protegidos por reglas existentes y Cloud Function `syncUserAuthAccess`.

## Reglas anteriores (vulnerabilidad)

```javascript
match /members/{memberId} {
  allow read: if isAuthenticated();
}
```

Cualquier usuario autenticado podía:

- listar todo el padrón (`collection('members').get()`),
- leer cédulas, emails y teléfonos de terceros,
- enumerar worker codes desde DevTools o SDK.

En `users`, `allow read` mezclaba get y list; se endureció separando permisos.

## Reglas nuevas (resumen)

- `members`: `get` si admin, operador o socio vinculado; `list` solo admin/operador.
- `users`: `get` propio o superadmin; `list` solo superadmin.

Helpers añadidos: `userDocData()`, `isLinkedToMember()`, `canReadMember()`.

## Arquitectura resultante

### Usuario normal (perfil / registro)

```text
Flutter (AuthService / UserProfile)
  ↓ POST + Bearer token
/api/lookup-member-by-employee  →  lookupMemberByEmployee
  ↓ Admin SDK
Firestore members (búsqueda por employeeNumber)
  ↓
Respuesta mínima al cliente

Lectura directa Firestore:
  get members/{memberId}  solo si users.memberId coincide
```

### SUPERADMIN (administración de usuarios)

```text
Flutter UsersAdminService
  ↓ POST + Bearer token
/api/admin-search-users      → adminSearchUsers
/api/admin-search-members    → adminSearchMembers
  ↓ assertSuperAdminRequest
  ↓ Admin SDK + límite 50 resultados
Firestore
```

### ADMIN / OPERADOR (padrón y asistencia)

```text
Flutter MembersService / Asistencia
  ↓ Firestore SDK (reglas permiten list/get)
Firestore members
```

## Cloud Functions involucradas

| Función | Endpoint | Quién |
|---------|----------|-------|
| `adminSearchUsers` | `/api/admin-search-users` | SUPERADMIN |
| `adminSearchMembers` | `/api/admin-search-members` | SUPERADMIN |
| `lookupMemberByEmployee` | `/api/lookup-member-by-employee` | Usuario autenticado (solo su employeeNumber) |

## Servicios Flutter modificados

- `lib/services/member_lookup_service.dart` — lookup seguro de socio.
- `lib/services/auth_service.dart` — registro y auto-vinculación vía backend.
- `lib/services/users_admin_service.dart` — búsquedas admin vía backend.
- `lib/services/members_service.dart` — manejo de `permission-denied` en `getMemberById`.
- `lib/features/profile/user_profile_screen.dart` — eliminado escaneo masivo del padrón.

## Pruebas

- `firebase_rules_test/firestore.rules.test.mjs` — escenarios members/users get/list.
- `functions/admin-search.test.js` — validación de payloads de búsqueda.
- Ejecutar: `powershell -File .\tool\test_firebase_rules.ps1`

## Riesgos pendientes

1. **Rol en Firestore**: `getUserRole()` lee `users/{uid}.role` desde reglas. Un usuario no puede escalar su rol por reglas de update, pero custom claims reforzarían aún más la autorización.
2. **Colecciones legacy** (`personas`, `eventos`): siguen con `read: if isAuthenticated()`; fuera del alcance estricto de esta fase pero conviene endurecer en fase posterior.
3. **Enumeración en registro**: `lookupMemberByEmployee` durante signup (sin doc `users` aún) permite probar números de trabajador; mitigado con auth obligatoria y mensajes genéricos; considerar rate limiting / App Check.
4. **Búsqueda parcial admin**: el backend escanea hasta 200–250 documentos para coincidencias de nombre; aceptable para superadmin pero no escala a miles de usuarios sin índices o Algolia.

## Validación local

```powershell
cd D:\Sindicat_fluter_apk
dart format lib test
flutter analyze
flutter test
cd functions
npm test
cd ..
powershell -File .\tool\test_firebase_rules.ps1
```

## Deploy

```powershell
firebase deploy --only firestore:rules,functions:adminSearchUsers,functions:adminSearchMembers,functions:lookupMemberByEmployee,hosting
```
