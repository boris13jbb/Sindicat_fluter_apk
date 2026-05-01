# Guía de Configuración: Usuarios VOTER para Votación

## Problema Resuelto

Los usuarios con rol `VOTER` no podían votar debido a que el sistema no podía identificar correctamente su socio (member) correspondiente en la base de datos.

## Causa Raíz

El sistema de votación necesita vincular el **usuario autenticado** (`users/{uid}`) con su **socio correspondiente** (`members/{memberId}`) para validar la elegibilidad de voto. Esta vinculación se hacía incorrectamente usando el email como identificador, lo cual fallaba en la mayoría de los casos.

---

## Requisitos para Usuarios VOTER

Para que un usuario con rol `VOTER` pueda votar correctamente, debe cumplir con los siguientes requisitos:

### 1. Documento en Colección `users/{uid}`

El usuario debe tener un documento en Firestore con la siguiente estructura mínima:

```json
{
  "uid": "abc123xyz456def789",
  "email": "juan.perez@empresa.com",
  "role": "VOTER",
  "employeeNumber": "SOCIO001",
  "displayName": "Juan Pérez",
  "createdAt": 1712700000000,
  "updatedAt": 1712700000000,
  "isActive": true
}
```

#### Campos Obligatorios:
- ✅ `uid` - Debe coincidir exactamente con el UID de Firebase Authentication
- ✅ `email` - Email del usuario
- ✅ `role` - Debe ser exactamente `"VOTER"` (en mayúsculas)
- ✅ `employeeNumber` - **CRÍTICO**: Debe contener el `workerCode` o `memberNumber` del socio correspondiente

#### Campos Opcionales:
- `displayName` - Nombre completo para mostrar
- `createdAt` - Timestamp de creación (milisegundos)
- `updatedAt` - Timestamp de última actualización (milisegundos)
- `isActive` - Estado activo del usuario (boolean)

---

### 2. Documento en Colección `members/{memberId}`

Debe existir un socio con el `workerCode` que coincida con el `employeeNumber` del usuario:

```json
{
  "id": "SOCIO001",
  "memberNumber": "SOCIO001",
  "workerCode": "SOCIO001",
  "firstName": "Juan",
  "lastName": "Pérez García",
  "fullName": "Juan Pérez García",
  "documentId": "123456789",
  "email": "juan.perez@empresa.com",
  "phone": "0991234567",
  "status": "activo",
  "createdAt": 1712700000000,
  "updatedAt": 1712700000000,
  "createdBy": "admin_uid_here"
}
```

#### Campos Obligatorios para Votación:
- ✅ `workerCode` - **DEBE COINCIDIR** con `employeeNumber` del usuario
- ✅ `status` - Debe ser exactamente `"activo"` (minúsculas)
- ✅ `memberNumber` - Número de socio único
- ✅ `fullName` - Nombre completo

---

### 3. Registro de Asistencia (Si la Elección lo Requiere)

Si la elección tiene configurado `requireAttendance: true`, el socio debe tener asistencia registrada en el evento especificado:

#### En colección `attendance_events/{eventId}/asistencias/{asistenciaId}`:

```json
{
  "eventoId": "evento_2024_001",
  "personaId": "SOCIO001",
  "asistio": true,
  "fechaRegistro": 1712700000000,
  "metodoRegistro": "manual",
  "registradoPor": "operador_uid",
  "createdAt": 1712700000000
}
```

O en colección `personas/{personaId}`:

```json
{
  "id": "SOCIO001",
  "workerCode": "SOCIO001",
  "nombre": "Juan Pérez García",
  "email": "juan.perez@empresa.com"
}
```

---

## Proceso de Creación Manual en Firebase Console

### Paso 1: Crear Usuario en Firebase Authentication

1. Ir a **Firebase Console** → **Authentication** → **Users**
2. Click en **"Add user"**
3. Ingresar:
   - Email: `juan.perez@empresa.com`
   - Password: `contraseña_segura`
4. Copiar el **UID generado** (ej: `abc123xyz456def789`)

### Paso 2: Crear Documento en Colección `users`

1. Ir a **Firestore Database** → **Data**
2. Navegar a colección `users`
3. Click en **"Add document"**
4. **Document ID**: Pegar el UID copiado (ej: `abc123xyz456def789`)
5. Agregar campos:

| Campo | Tipo | Valor |
|-------|------|-------|
| uid | string | `abc123xyz456def789` |
| email | string | `juan.perez@empresa.com` |
| role | string | `VOTER` |
| employeeNumber | string | `SOCIO001` |
| displayName | string | `Juan Pérez` |
| createdAt | number | `1712700000000` |
| updatedAt | number | `1712700000000` |
| isActive | boolean | `true` |

### Paso 3: Verificar/Crear Socio en Colección `members`

1. Ir a colección `members`
2. Buscar documento con `workerCode = "SOCIO001"`
3. Si no existe, crearlo con los campos indicados arriba
4. **IMPORTANTE**: Verificar que `workerCode` sea exactamente igual al `employeeNumber` del usuario

### Paso 4: Registrar Asistencia (Si Aplica)

Si la elección requiere asistencia:

1. Ir a **Asistencia** en la aplicación
2. Registrar asistencia del socio `SOCIO001` en el evento correspondiente
3. O crear manualmente el documento en `attendance_events/{eventId}/asistencias/`

---

## Validación de Configuración Correcta

### Checklist de Verificación

- [ ] Usuario existe en Firebase Authentication
- [ ] Documento `users/{uid}` existe con campo `role: "VOTER"`
- [ ] Campo `employeeNumber` está presente y no está vacío
- [ ] Existe miembro en `members` con `workerCode` igual al `employeeNumber`
- [ ] Miembro tiene `status: "activo"` (exactamente así, en minúsculas)
- [ ] Si la elección requiere asistencia, el socio tiene registro de asistencia
- [ ] El evento de asistencia está correctamente configurado en la elección

### Prueba de Funcionamiento

1. Iniciar sesión con el usuario VOTER
2. Navegar a **Votar**
3. Seleccionar una elección activa
4. Verificar que:
   - No aparece error de `permission-denied`
   - Los candidatos se cargan correctamente
   - Puede seleccionar un candidato y emitir voto
   - Recibe confirmación de voto registrado

---

## Diagnóstico de Errores Comunes

### Error: `cloud_firestore/permission-denied`

**Causa**: Falta documento en `users/{uid}` o campo `role` incorrecto

**Solución**:
1. Verificar que existe documento en `users/{uid}`
2. Confirmar que `role` es exactamente `"VOTER"` (mayúsculas)
3. Verificar que el UID coincide con Firebase Auth

---

### Error: "No tienes permiso para votar en esta elección"

**Causa**: No se pudo vincular usuario con socio, o no cumple requisitos de elegibilidad

**Solución**:
1. Verificar que `employeeNumber` en `users/{uid}` no está vacío
2. Verificar que existe miembro con `workerCode` igual a `employeeNumber`
3. Verificar que `status` del miembro es `"activo"`
4. Si la elección requiere asistencia, verificar registro de asistencia

**Logs de Diagnóstico**:
Buscar en consola mensajes que empiecen con `🗳️`:
```
🗳️ MemberId inicializado: SOCIO001 (tipo: employeeNumber)
🗳️  Verificando elegibilidad para votación:
   Election: election_001
   Evento requerido: evento_2024_001
   UserId: abc123xyz456def789
   MemberId recibido: SOCIO001
   🔍 Identificadores a probar (1): SOCIO001
   🔎 Probando identifier: "SOCIO001"
   ✅ Miembro encontrado:
      - workerCode: SOCIO001
      - Nombre: Juan Pérez García
      - Status: activo
```

---

### Error: Candidatos no se cargan

**Causa**: Problema de permisos o conexión

**Solución**:
1. Verificar reglas de Firestore para `elections/{electionId}/candidates`
2. Confirmar que usuario está autenticado
3. Revisar logs de error en consola

---

## Mejoras Implementadas en el Código

### 1. `voting_screen.dart`

**Antes**:
```dart
memberId: _userEmail, // ❌ Usaba email como identificador
```

**Después**:
```dart
// ✅ Usa employeeNumber (workerCode) como prioridad
_memberId = user.employeeNumber?.isNotEmpty == true 
    ? user.employeeNumber 
    : _userId;
```

### 2. `election_service.dart`

**Mejoras**:
- Búsqueda inteligente por múltiples identificadores (employeeNumber, memberId, userId, email)
- Validación explícita de estado activo del socio
- Logs detallados para diagnóstico
- Manejo robusto de casos edge (campos vacíos, null, etc.)

---

## Script de Verificación Automática (Opcional)

Puedes agregar este código temporalmente en tu app para verificar la configuración:

```dart
Future<void> verificarConfiguracionVotante() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final user = auth.currentUser;
  
  if (user == null) {
    print('❌ No hay usuario autenticado');
    return;
  }
  
  print('\\n=== VERIFICACIÓN DE CONFIGURACIÓN VOTER ===\\n');
  
  // 1. Verificar documento de usuario
  final userDoc = await firestore.collection('users').doc(user.uid).get();
  if (!userDoc.exists) {
    print('❌ Documento users/{uid} NO existe');
    return;
  }
  
  final userData = userDoc.data()!;
  print('✅ Documento users/{uid} existe');
  print('   Role: ${userData['role']}');
  print('   Email: ${userData['email']}');
  print('   EmployeeNumber: ${userData['employeeNumber'] ?? "NO CONFIGURADO"}');
  
  if (userData['role'] != 'VOTER') {
    print('⚠️  Role no es VOTER (actual: ${userData['role']})');
  }
  
  final employeeNumber = userData['employeeNumber'];
  if (employeeNumber == null || employeeNumber.isEmpty) {
    print('❌ employeeNumber está vacío - CRÍTICO PARA VOTACIÓN');
    return;
  }
  
  // 2. Verificar miembro correspondiente
  final memberQuery = await firestore
      .collection('members')
      .where('workerCode', isEqualTo: employeeNumber)
      .limit(1)
      .get();
  
  if (memberQuery.docs.isEmpty) {
    print('❌ No se encontró miembro con workerCode: $employeeNumber');
    return;
  }
  
  final memberData = memberQuery.docs.first.data();
  print('\\n✅ Miembro encontrado:');
  print('   workerCode: ${memberData['workerCode']}');
  print('   Nombre: ${memberData['fullName']}');
  print('   Status: ${memberData['status']}');
  
  if (memberData['status'] != 'activo') {
    print('⚠️  Miembro no está activo (status: ${memberData['status']})');
  }
  
  print('\\n=== CONFIGURACIÓN CORRECTA ===');
  print('El usuario puede votar si:');
  print('1. La elección está activa');
  print('2. Si requiere asistencia, tiene registro en el evento');
}
```

---

## Notas Importantes

1. **Sensibilidad a Mayúsculas/Minúsculas**:
   - `role` debe ser exactamente `"VOTER"` (mayúsculas)
   - `status` del miembro debe ser exactamente `"activo"` (minúsculas)
   - `workerCode` y `employeeNumber` deben coincidir exactamente

2. **Timestamps**:
   - Usar siempre milisegundos desde epoch (números, no objetos Date)
   - Ejemplo: `1712700000000` en lugar de `new Date()`

3. **Seguridad**:
   - Las reglas de Firestore ya protegen contra escritura indebida de votos
   - Un usuario solo puede crear su propio voto
   - Los votos son inmutables (no se pueden actualizar ni eliminar)

4. **Elegibilidad**:
   - Si `requireAttendance: false`, todos los socios activos pueden votar
   - Si `requireAttendance: true`, solo socios con asistencia en el evento configurado

---

## Soporte

Si después de seguir esta guía el problema persiste:

1. Capturar logs completos de la consola al intentar votar
2. Verificar estructura exacta de documentos en Firestore (screenshots)
3. Confirmar versión de la aplicación desplegada
4. Revisar reglas de Firestore desplegadas (`firestore.rules`)

---

**Última Actualización**: Abril 2026  
**Versión Aplicación**: Post-fix voter eligibility  
**Archivos Modificados**:
- `lib/features/voting/voting_screen.dart`
- `lib/services/election_service.dart`
- `docs/setup/voter-configuration-guide.md` (este archivo)
