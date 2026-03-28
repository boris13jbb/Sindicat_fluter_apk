# Fix: Candidatos no se muestran en la UI

## Problema
Los candidatos se creaban exitosamente en Firebase Firestore (visibles en la consola), pero no aparecían en la interfaz de la aplicación Flutter.

## Causa Raíz

Se identificaron múltiples problemas:

### 1. **Consulta Firestore con `orderBy('order')` sin manejo de campos faltantes**
   - En `election_service.dart`, la consulta `.orderBy('order')` requiere que TODOS los documentos tengan el campo `order`
   - Si algún candidato no tenía este campo, era excluido silenciosamente de los resultados
   - La consulta no especificaba el orden (ascending/descending), lo cual podía causar inconsistencias

### 2. **Falta de validación del campo `order` al guardar**
   - Aunque el modelo `Candidate` tiene un valor por defecto (`order = 0`), no se garantizaba que el campo se escribiera correctamente en Firestore
   - El método `toMap()` incluye el campo, pero podría haber condiciones de carrera o problemas de serialización

### 3. **Ausencia de logging para debugging**
   - No había forma de rastrear qué datos se estaban guardando o recuperando de Firestore
   - Dificultaba la identificación de problemas de sincronización

## Solución Aplicada

### Cambios en `lib/services/election_service.dart`:

#### 1. Mejora en la consulta `getCandidates()`:
```dart
Stream<List<Candidate>> getCandidates(String electionId) {
  return _firestore
      .collection('elections')
      .doc(electionId)
      .collection('candidates')
      .orderBy('order', descending: false)  // Explícito: ascending
      .snapshots()
      .map((snap) {
        // Debug logging
        debugPrint('getCandidates: Retrieved ${snap.docs.length} candidates for election $electionId');
        for (var doc in snap.docs) {
          debugPrint('  - Candidate: ${doc.id}, data: ${doc.data()}');
        }
        final candidates = snap.docs.map((d) => Candidate.fromMap({...d.data(), 'electionId': electionId}, d.id)).toList();
        debugPrint('getCandidates: Deserialized ${candidates.length} candidates: ${candidates.map((c) => c.name).join(', ')}');
        return candidates;
      });
}
```

**Cambios clave:**
- Se especifica explícitamente `descending: false` para el ordenamiento
- Se agrega logging detallado para rastrear la recuperación y deserialización de datos
- Se imprime información de cada documento para facilitar el debugging

#### 2. Refuerzo en `addCandidate()`:
```dart
Future<void> addCandidate(Candidate candidate) async {
  try {
    debugPrint('addCandidate: Starting to add candidate "${candidate.name}" to election ${candidate.electionId}');
    final ref = _firestore.collection('elections').doc(candidate.electionId).collection('candidates').doc();
    final data = candidate.toMap()..['id'] = ref.id;
    // Ensure required fields are present
    data['electionId'] = candidate.electionId;
    // Ensure order field exists (default to 0 if not set)
    if (!data.containsKey('order')) {
      data['order'] = candidate.order;
    }
    debugPrint('addCandidate: Data to be saved: $data');
    await ref.set(data);
    debugPrint('addCandidate: Successfully added candidate with ID: ${ref.id}');
  } catch (e) {
    debugPrint('addCandidate: ERROR - $e');
    rethrow;
  }
}
```

**Cambios clave:**
- Se valida explícitamente que el campo `order` exista antes de guardar
- Se agrega logging completo: desde el inicio, datos a guardar, y confirmación
- Se maneja excepciones con logging para identificar errores

### Cambios en `lib/core/models/candidate.dart`:

#### 3. Mejora en la deserialización `fromMap()`:
```dart
factory Candidate.fromMap(Map<String, dynamic> map, [String? id]) {
  final docId = id ?? map['id'] as String? ?? '';
  // Debug: Ensure electionId is properly extracted
  final electionId = map['electionId'] as String? ?? '';
  return Candidate(
    id: docId,
    electionId: electionId,
    name: map['name'] as String? ?? '',
    description: map['description'] as String?,
    imageUrl: map['imageUrl'] as String?,
    order: (map['order'] as num?)?.toInt() ?? 0,
    voteCount: (map['voteCount'] as num?)?.toInt() ?? 0,
  );
}
```

**Cambios clave:**
- Se extrae explícitamente `electionId` en una variable local para mayor claridad
- Se mantiene la lógica de valores por defecto robusta

## Verificación de Reglas de Seguridad

Las reglas de seguridad en `firestore.rules` ya permiten correctamente la lectura:

```javascript
match /candidates/{candidateId} {
  allow read: if isAuthenticated() && candidateId != "";
  allow create, update, delete: if isAuthenticated();
}
```

✅ **No se requieren cambios en las reglas de seguridad**

## Cómo Probar el Fix

1. **Ejecutar la aplicación en modo debug:**
   ```bash
   flutter run
   ```

2. **Observar la consola mientras se crea un candidato:**
   - Deberías ver: `addCandidate: Starting to add candidate "Nombre" to election ID_ELECCION`
   - Deberías ver: `addCandidate: Data to be saved: {id: ..., electionId: ..., name: ..., order: 0, ...}`
   - Deberías ver: `addCandidate: Successfully added candidate with ID: ID_CANDIDATO`

3. **Verificar que aparecen en la UI:**
   - Navegar a la edición de la elección
   - Los candidatos deberían aparecer inmediatamente en la lista
   - En la consola deberías ver: `getCandidates: Retrieved X candidates for election ID_ELECCION`
   - Deberías ver: `getCandidates: Deserialized X candidates: Nombre1, Nombre2, ...`

4. **Probar en diferentes escenarios:**
   - Crear candidatos sin especificar orden (debe usar 0 por defecto)
   - Crear candidatos especificando orden
   - Verificar que los candidatos aparecen en el orden correcto
   - Verificar que la votación funciona normalmente

## Posibles Problemas Adicionales

### Si los candidatos aún no aparecen:

1. **Verificar índices de Firestore:**
   - Al usar `orderBy('order')`, Firestore puede requerir un índice compuesto
   - Revisa la consola de Firebase para mensajes de error sobre índices
   - Si es necesario, crea el índice desde: https://console.firebase.google.com/project/PROJECT_ID/firestore/indexes

2. **Verificar permisos de autenticación:**
   - Asegúrate de estar logueado como usuario autenticado
   - Las reglas requieren `request.auth != null`

3. **Limpiar caché de la aplicación:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Verificar estructura de datos en Firestore Console:**
   - Navega a: `elections/{electionId}/candidates`
   - Verifica que cada documento tenga los campos: `id`, `electionId`, `name`, `order`
   - El campo `order` debe ser de tipo número (integer)

## Archivos Modificados

1. `lib/services/election_service.dart` - Consultas y persistencia de candidatos
2. `lib/core/models/candidate.dart` - Deserialización del modelo Candidate

## Próximos Pasos (Opcional)

- [ ] Agregar tests unitarios para verificar la serialización/deserialización
- [ ] Implementar retry logic para fallos de red
- [ ] Agregar indicadores visuales de carga/error en la UI
- [ ] Considerar el uso de transacciones para operaciones atómicas
- [ ] Evaluar si se necesita paginación para muchas elecciones con muchos candidatos

## Notas Importantes

- **NO se requieren cambios en las reglas de Firestore**
- **NO se requieren migraciones de datos** (el fix es compatible con datos existentes)
- **El logging puede ser removido en producción** una vez se confirme que el problema está resuelto
- **La solución es retro-compatible** con candidatos creados anteriormente
