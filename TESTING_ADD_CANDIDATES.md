# 📋 Guía de Prueba: Agregar Candidatos

## Instrucciones Paso a Paso

### Preparación
1. ✅ Asegúrate de que Firebase esté configurado correctamente
2. ✅ Verifica que las reglas de Firestore estén desplegadas
3. ✅ Inicia sesión como administrador en la aplicación

### Flujo de Prueba Principal

#### Paso 1: Navegar a la Elección
1. Ejecuta la aplicación: `flutter run -d windows`
2. Inicia sesión con credenciales de administrador
3. Navega a la sección de "Elecciones"
4. Selecciona una elección existente o crea una nueva

#### Paso 2: Agregar Candidato
1. En la tarjeta de la elección, haz clic en **"Agregar Candidato"**
   - O ve a "Editar Elección" y busca la sección de candidatos

2. **Formulario de Candidato:**
   ```
   Nombre del Candidato *     [Requerido - validar que no esté vacío]
   Descripción (opcional)     [Opcional - puede estar vacío]
   URL de imagen (opcional)   [Opcional - debe ser URL válida si se proporciona]
   Orden en lista (opcional)  [Opcional - número entero, default 0]
   ```

3. **Casos de Prueba:**

   **Caso A: Candidato completo**
   - Nombre: "Juan Pérez"
   - Descripción: "Candidato con experiencia en liderazgo"
   - URL Imagen: "https://example.com/foto.jpg"
   - Orden: 1
   - **Resultado esperado:** ✅ Success message verde "Candidato agregado exitosamente"
   
   **Caso B: Solo nombre requerido**
   - Nombre: "María González"
   - Resto de campos: vacíos
   - **Resultado esperado:** ✅ Candidato creado exitosamente
   
   **Caso C: Nombre vacío (debe fallar)**
   - Nombre: [vacío]
   - Presionar "Agregar Candidato"
   - **Resultado esperado:** ❌ Error "Requerido" en el campo nombre
   
   **Caso D: Error de validación de electionId**
   - Intentar agregar candidato sin electionId válido
   - **Resultado esperado:** ❌ Error "ID de elección no válido"

#### Paso 3: Verificar Resultados

**Inmediatamente después de agregar:**
1. ✅ Mensaje de éxito aparece (fondo verde)
2. ✅ Navega automáticamente a la pantalla anterior
3. ✅ La lista de candidatos se actualiza automáticamente
4. ✅ El nuevo candidato aparece en la lista

**Verificar en Firestore Console:**
1. Abre [Firebase Console](https://console.firebase.google.com)
2. Ve a **Firestore Database**
3. Navega a: `elections/{electionId}/candidates/{candidateId}`
4. Verifica los datos guardados:
   ```json
   {
     "id": "{candidateId_generado}",
     "electionId": "{electionId}",
     "name": "Nombre del candidato",
     "description": "Descripción opcional",
     "imageUrl": "https://...",
     "order": 1,
     "voteCount": 0
   }
   ```

**Campos obligatorios:**
- ✅ `id` - Auto-generado por Firestore
- ✅ `electionId` - Debe coincidir con la elección padre
- ✅ `name` - Nombre del candidato
- ✅ `voteCount` - Inicializado en 0

**Campos opcionales:**
- `description` - Puede ser null o string vacío
- `imageUrl` - Puede ser null
- `order` - Default es 0

### Casos de Error a Probar

#### 1. ElectionId Inválido
- **Acción:** Modificar el código temporalmente para pasar electionId vacío
- **Error esperado:** "Error: ID de elección no válido"
- **Comportamiento:** No intenta crear el candidato

#### 2. Error de Firestore (reglas de seguridad)
- **Acción:** Remover temporalmente las reglas de seguridad en Firebase
- **Error esperado:** Mensaje de error rojo con detalles del error
- **Comportamiento:** Muestra el error específico de Firestore

#### 3. Sin conexión a internet
- **Acción:** Desconectar red
- **Comportamiento:** Firebase maneja offline automáticamente
- **Resultado:** Los datos se sincronizan cuando vuelve la conexión

### Criterios de Aceptación

**Funcionalidad:**
- ✅ El formulario valida que el nombre no esté vacío
- ✅ Los campos opcionales realmente son opcionales
- ✅ El electionId se valida antes de enviar
- ✅ Los errores muestran mensajes claros al usuario
- ✅ El éxito muestra mensaje verde claro
- ✅ La navegación de retorno funciona correctamente

**Datos:**
- ✅ Todos los campos se guardan correctamente en Firestore
- ✅ El ID del documento es auto-generado
- ✅ El electionId se guarda tanto en el path como en los datos
- ✅ voteCount inicia en 0
- ✅ order defaults a 0 si no se especifica

**Experiencia de Usuario:**
- ✅ Feedback inmediato después de enviar
- ✅ Mensajes de error descriptivos
- ✅ Loading indicator mientras se procesa
- ✅ Transiciones suaves entre pantallas

**Integración:**
- ✅ StreamBuilder actualiza la UI automáticamente
- ✅ No se requiere recargar manualmente
- ✅ Los cambios se reflejan en tiempo real

## Comandos Útiles

### Ejecutar la aplicación
```bash
flutter run -d windows
```

### Limpiar build (si hay problemas)
```bash
flutter clean
flutter pub get
flutter run -d windows
```

### Ver logs de Firebase
```bash
# En Firebase Console > Firestore Database
# Habilitar logs en tiempo real
```

## Solución de Problemas Comunes

### Problema: "Error: ID de elección no válido"
**Causa:** El electionId está vacío o es nulo
**Solución:** Verificar que se está navegando desde una elección válida

### Problema: El candidato no aparece en la lista
**Causa:** 
1. Error en las reglas de Firestore
2. StreamBuilder no está escuchando correctamente
**Solución:** 
1. Verificar reglas de Firestore en Firebase Console
2. Revisar que el stream esté correctamente configurado

### Problema: Error de permisos de Firestore
**Causa:** Reglas de seguridad bloquean la escritura
**Solución:** 
```javascript
match /elections/{electionId}/candidates/{candidateId} {
  allow create: if isAuthenticated();
}
```

### Problema: Datos incompletos en Firestore
**Causa:** El modelo Candidate no incluye todos los campos
**Solución:** Verificar que `toMap()` incluya todos los campos necesarios

## Referencias

- **Archivo principal:** `lib/features/elections/add_candidate_screen.dart`
- **Servicio:** `lib/services/election_service.dart`
- **Modelo:** `lib/core/models/candidate.dart`
- **Reglas:** `firestore.rules`
