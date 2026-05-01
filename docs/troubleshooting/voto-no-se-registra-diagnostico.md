# Diagnóstico: Voto No Se Registra Correctamente

## Problema Reportado

El usuario con rol **VOTER** emite el voto, pero el sistema no lo registra correctamente y le vuelve a pedir que vote.

---

## Causas Posibles Identificadas

### 1. ❌ Error de Elegibilidad (Más Probable)

**Síntoma:** El voto pasa la validación inicial en la UI, pero falla en `castVote()` al validar elegibilidad nuevamente.

**Causa:** La función `isUserEligibleToVote()` puede fallar por:
- Campo `employeeNumber` vacío o incorrecto en `users/{uid}`
- Socio no encontrado en colección `members`
- Estado del socio inactivo
- Falta registro de asistencia cuando la elección lo requiere

**Solución Aplicada:**
- ✅ Agregado logging detallado en `castVote()` para ver exactamente dónde falla
- ✅ Mejor manejo de errores en `_confirmar()` con mensajes específicos
- ✅ Diálogo informativo cuando falla elegibilidad

---

### 2. ❌ Error de Red/Timeout

**Síntoma:** El batch commit tarda demasiado o falla por conexión inestable.

**Causa:** 
- Conexión lenta o intermitente
- Firestore offline mode no configurado correctamente
- Timeout en operaciones asíncronas

**Solución Aplicada:**
- ✅ Logging en cada paso del proceso de votación
- ✅ Stack trace completo en errores
- ✅ Opción de reintentar en SnackBar

---

### 3. ❌ Doble Validación Redundante

**Síntoma:** La UI ya verificó asistencia (líneas 177-209), pero `castVote()` vuelve a verificar (líneas 537-550).

**Causa:** 
- Inconsistencia entre las dos verificaciones
- Cache de Firestore desactualizada en una de ellas

**Solución Aplicada:**
- ✅ Logging permite ver si ambas validaciones pasan
- ✅ Si la primera valida (UI muestra pantalla de voto), la segunda debería pasar también

---

### 4. ❌ MemberId Incorrecto o Vacío

**Síntoma:** `_memberId` es null o vacío cuando llega a `castVote()`.

**Causa:**
- Usuario no tiene campo `employeeNumber` en su documento
- Método `_initializeMemberId()` no se ejecutó correctamente
- AuthService no pudo recuperar datos del usuario

**Solución Aplicada:**
- ✅ Logging muestra valor exacto de `memberId` recibido
- ✅ Fallback a `userId` si no hay `employeeNumber`

---

## Pasos de Diagnóstico

### Paso 1: Ejecutar la App con Logs Detallados

```bash
flutter run -d <device_id>
```

### Paso 2: Intentar Votar como Usuario VOTER

Observa los logs en la consola. Deberías ver algo como esto:

#### ✅ Escenario Exitoso:
```
🗳️ Usuario confirmó voto - Iniciando proceso...
   📤 Llamando a castVote...

🗳️ === INICIANDO PROCESO DE VOTACIÓN ===
   Election: election_abc123
   UserId: user_xyz789
   CandidateId: candidate_def456
   MemberId: SOCIO001
   🔍 Validando elegibilidad...

🗳️  Verificando elegibilidad para votación:
   Election: election_abc123
   Evento requerido: event_ghi789
   UserId: user_xyz789
   MemberId recibido: SOCIO001
   
   📋 Agregado employeeNumber: SOCIO001
   🔍 Identificadores a probar (1): SOCIO001
   
   🔎 Probando identifier: "SOCIO001"
   ✅ Miembro encontrado:
      - workerCode: SOCIO001
      - Nombre: Juan Pérez García
      - Status: Activo
      
   👤 Persona encontrada en sistema de asistencia: SOCIO001
   ✅ ASISTENCIA ENCONTRADA - Usuario ELEGIBLE
   
   ✅ Usuario es elegible - Continuando con votación
   📝 Preparando batch de escritura...
   💾 Ejecutando commit del batch...
   ✅ Batch commit exitoso
   📋 Registrando auditoría...
   ✅ Auditoría registrada
🗳️ === VOTACIÓN COMPLETADA EXITOSAMENTE ===

   ✅ castVote completado sin errores
   ✅ Voto local registrado
   ✅ UI actualizada - mostrando pantalla de éxito
```

#### ❌ Escenario de Error - Elegibilidad Fallida:
```
🗳️ Usuario confirmó voto - Iniciando proceso...
   📤 Llamando a castVote...

🗳️ === INICIANDO PROCESO DE VOTACIÓN ===
   Election: election_abc123
   UserId: user_xyz789
   CandidateId: candidate_def456
   MemberId: SOCIO001
   🔍 Validando elegibilidad...

🗳️  Verificando elegibilidad para votación:
   ...
   ❌ No se encontró miembro con identifier: "SOCIO001"
   
   🔄 Intentando búsqueda directa en asistencias...
   ❌ No se encontró asistencia por búsqueda directa
   💡 Sugerencia: Verificar que el socio tenga registro de asistencia en el evento event_ghi789
   
   ❌ Usuario NO es elegible para votar
   
   ❌ Error en _confirmar: Exception: No tienes permiso para votar en esta elección...
   ❌ Error de elegibilidad detectado
   [Muestra diálogo: "No cumples con los requisitos para votar"]
```

#### ❌ Escenario de Error - Commit Fallido:
```
🗳️ === INICIANDO PROCESO DE VOTACIÓN ===
   ...
   ✅ Usuario es elegible - Continuando con votación
   📝 Preparando batch de escritura...
   💾 Ejecutando commit del batch...
   ❌ Error al ejecutar batch: [error details]
   Stack trace: [stack trace]
🗳️ === ERROR EN VOTACIÓN ===

   ❌ Error en _confirmar: [error message]
   [Muestra SnackBar con opción de reintentar]
```

---

## Verificación Rápida en Firebase Console

### 1. Verificar Documento del Usuario

Ir a **Firestore** → Colección `users` → Buscar documento con UID del usuario:

```json
{
  "uid": "user_xyz789",
  "email": "juan.perez@empresa.com",
  "role": "VOTER",
  "employeeNumber": "SOCIO001",  // ⚠️ ¿Existe este campo?
  "displayName": "Juan Pérez",
  "isActive": true
}
```

**Verificar:**
- ✅ Campo `employeeNumber` existe y tiene valor
- ✅ Campo `role` es exactamente `"VOTER"`
- ✅ Campo `isActive` es `true`

---

### 2. Verificar Documento del Socio

Ir a **Firestore** → Colección `members` → Buscar documento con ID igual al `employeeNumber`:

```json
{
  "id": "SOCIO001",
  "workerCode": "SOCIO001",  // ⚠️ ¿Coincide con employeeNumber del usuario?
  "fullName": "Juan Pérez García",
  "status": "activo",  // ⚠️ ¿Está activo?
  "email": "juan.perez@empresa.com"
}
```

**Verificar:**
- ✅ Documento existe
- ✅ Campo `workerCode` coincide EXACTAMENTE con `employeeNumber` del usuario (case-sensitive)
- ✅ Campo `status` es `"activo"` o `"active"`

---

### 3. Verificar Registro de Asistencia (si aplica)

Si la elección tiene `requireAttendance: true`:

Ir a **Firestore** → Colección `attendance_events` → Evento específico → Subcolección `asistencias`:

```json
{
  "personaId": "SOCIO001",  // ⚠️ ¿Coincide con workerCode?
  "asistio": true,
  "registradoPor": "admin_uid",
  "fechaRegistro": 1712700000000
}
```

**Verificar:**
- ✅ Existe documento de asistencia para este `personaId`
- ✅ Campo `asistio` es `true`
- ✅ `personaId` coincide con `workerCode` del socio

---

### 4. Verificar Configuración de la Elección

Ir a **Firestore** → Colección `elections` → Documento de la elección:

```json
{
  "id": "election_abc123",
  "title": "Elección de Directiva 2024",
  "requireAttendance": true,  // ⚠️ ¿Requiere asistencia?
  "eventoAsistenciaId": "event_ghi789",  // ⚠️ ¿Tiene evento configurado?
  "isVisibleToVoters": true,
  "startDate": 1712700000000,
  "endDate": 1712800000000
}
```

**Verificar:**
- ✅ `isVisibleToVoters` es `true`
- ✅ Fecha actual está entre `startDate` y `endDate`
- ✅ Si `requireAttendance` es `true`, entonces `eventoAsistenciaId` debe existir

---

## Soluciones según el Diagnóstico

### Si el error es "Miembro no encontrado":

**Problema:** No existe documento en `members/{workerCode}` o `workerCode` no coincide con `employeeNumber`.

**Solución:**
1. Crear documento del socio en `members/SOCIO001` con estructura correcta
2. Asegurar que `workerCode` sea exactamente igual a `employeeNumber` del usuario

---

### Si el error es "Socio no está activo":

**Problema:** Campo `status` del socio es diferente de `"activo"` o `"active"`.

**Solución:**
Actualizar documento del socio:
```javascript
db.collection('members').doc('SOCIO001').update({
  status: 'activo'
});
```

---

### Si el error es "No tiene asistencia registrada":

**Problema:** No existe registro de asistencia en el evento configurado.

**Solución:**
Registrar asistencia manualmente:
```javascript
db.collection('attendance_events')
  .doc('event_ghi789')
  .collection('asistencias')
  .add({
    personaId: 'SOCIO001',
    asistio: true,
    registradoPor: 'admin_uid',
    fechaRegistro: FieldValue.serverTimestamp(),
    metodoRegistro: 'manual'
  });
```

---

### Si el error es "Batch commit failed":

**Problema:** Error de red o permisos de Firestore.

**Solución:**
1. Verificar conectividad de red
2. Revisar reglas de Firestore para colección `votes`
3. Verificar que el usuario esté autenticado correctamente

---

## Script de Verificación Automática

Ejecutar en **Firebase Console** → **Firestore** → pestaña **Console**:

```javascript
// ========================================
// SCRIPT DE DIAGNÓSTICO COMPLETO
// ========================================

async function diagnosticarVotacion(userId, electionId) {
  console.log('🔍 INICIANDO DIAGNÓSTICO...\n');
  
  // 1. Verificar usuario
  console.log('1️⃣ Verificando usuario...');
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    console.error('❌ Usuario NO encontrado');
    return;
  }
  const userData = userDoc.data();
  console.log('✅ Usuario encontrado');
  console.log('   Role:', userData.role);
  console.log('   EmployeeNumber:', userData.employeeNumber || 'NO DEFINIDO');
  console.log('   Email:', userData.email);
  
  if (!userData.employeeNumber) {
    console.error('❌ ERROR CRÍTICO: employeeNumber no definido');
    console.log('💡 SOLUCIÓN: Agregar campo employeeNumber al usuario');
    return;
  }
  
  // 2. Verificar socio
  console.log('\n2️⃣ Verificando socio...');
  const memberDoc = await db.collection('members').doc(userData.employeeNumber).get();
  if (!memberDoc.exists) {
    console.error('❌ Socio NO encontrado con ID:', userData.employeeNumber);
    console.log('💡 SOLUCIÓN: Crear documento members/' + userData.employeeNumber);
    return;
  }
  const memberData = memberDoc.data();
  console.log('✅ Socio encontrado');
  console.log('   WorkerCode:', memberData.workerCode);
  console.log('   Nombre:', memberData.fullName);
  console.log('   Status:', memberData.status);
  
  if (memberData.status !== 'activo' && memberData.status !== 'active') {
    console.error('❌ ERROR: Socio no está activo (status:', memberData.status + ')');
    console.log('💡 SOLUCIÓN: Actualizar status a "activo"');
    return;
  }
  
  // 3. Verificar elección
  console.log('\n3️⃣ Verificando elección...');
  const electionDoc = await db.collection('elections').doc(electionId).get();
  if (!electionDoc.exists) {
    console.error('❌ Elección NO encontrada');
    return;
  }
  const electionData = electionDoc.data();
  console.log('✅ Elección encontrada');
  console.log('   Título:', electionData.title);
  console.log('   Requiere asistencia:', electionData.requireAttendance);
  console.log('   Visible para votantes:', electionData.isVisibleToVoters);
  
  // 4. Verificar asistencia (si aplica)
  if (electionData.requireAttendance && electionData.eventoAsistenciaId) {
    console.log('\n4️⃣ Verificando asistencia...');
    const attendanceSnap = await db
      .collection('attendance_events')
      .doc(electionData.eventoAsistenciaId)
      .collection('asistencias')
      .where('personaId', '==', memberData.workerCode)
      .where('asistio', '==', true)
      .limit(1)
      .get();
    
    if (attendanceSnap.empty) {
      console.error('❌ NO se encontró registro de asistencia');
      console.log('   Evento:', electionData.eventoAsistenciaId);
      console.log('   PersonaId buscado:', memberData.workerCode);
      console.log('💡 SOLUCIÓN: Registrar asistencia del socio en el evento');
      return;
    }
    console.log('✅ Asistencia encontrada');
  } else {
    console.log('\n4️⃣ Elección NO requiere asistencia - omitiendo verificación');
  }
  
  // 5. Verificar si ya votó
  console.log('\n5️⃣ Verificando si ya votó...');
  const voteId = `${electionId}_${userId}`.replace(/[^a-zA-Z0-9_]/g, '_');
  const voteDoc = await db
    .collection('elections')
    .doc(electionId)
    .collection('votes')
    .doc(voteId)
    .get();
  
  if (voteDoc.exists) {
    console.warn('⚠️ El usuario YA VOTÓ en esta elección');
    console.log('   VoteId:', voteId);
    console.log('   Votó en:', voteDoc.data()?.votedAt?.toDate());
    return;
  }
  console.log('✅ Usuario aún NO ha votado - puede votar');
  
  console.log('\n✅✅✅ DIAGNÓSTICO COMPLETADO - TODO CORRECTO ✅✅✅');
  console.log('El usuario debería poder votar sin problemas.');
}

// ========================================
// EJECUTAR DIAGNÓSTICO
// ========================================
// Reemplazar con valores reales:
diagnosticarVotacion('user_xyz789', 'election_abc123');
```

---

## Resumen de Cambios Realizados

### Archivos Modificados:

1. **`lib/services/election_service.dart`**
   - ✅ Agregado logging detallado en `castVote()`
   - ✅ Mejor manejo de errores con stack traces
   - ✅ Detección automática de votos duplicados
   - ✅ Mensajes claros en cada paso del proceso

2. **`lib/features/voting/voting_screen.dart`**
   - ✅ Agregado logging en `_confirmar()`
   - ✅ Manejo específico de errores de elegibilidad
   - ✅ Diálogo informativo cuando falla elegibilidad
   - ✅ SnackBar con opción de reintentar en errores genéricos
   - ✅ Detección mejorada de votos duplicados

---

## Próximos Pasos

1. **Ejecutar la app** con los nuevos cambios
2. **Intentar votar** como usuario VOTER
3. **Copiar los logs** completos de la consola
4. **Identificar en qué paso falla** usando los emojis como guía:
   - 🗳️ = Inicio del proceso
   - 🔍 = Validando elegibilidad
   - ✅ = Paso exitoso
   - ❌ = Error detectado
   - 💾 = Escribiendo en Firestore
5. **Compartir los logs** para diagnóstico preciso

---

## Contacto para Soporte

Si después de seguir este diagnóstico el problema persiste, proporcionar:
- Logs completos de la consola (desde 🗳️ hasta el error)
- Captura de pantalla de los documentos en Firebase Console
- Configuración exacta de la elección (campos relevantes)
- Versión de Flutter y Firebase SDK utilizadas
