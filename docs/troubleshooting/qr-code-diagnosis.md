# Diagnóstico del Problema: Código QR No Aparece

## Resumen del Problema

El código QR no aparece en la pantalla "Mi Perfil" después de iniciar sesión, mostrando el mensaje "Código QR no disponible".

## Causas Identificadas

Después de analizar el código, el problema ocurre porque **el sistema no puede encontrar el registro del socio** que corresponde al usuario autenticado. El código QR requiere el campo `workerCode` del socio, pero primero necesita encontrar el registro correcto.

## Estrategias de Búsqueda Implementadas (5 Niveles)

El sistema ahora intenta 5 estrategias diferentes para encontrar tu socio:

### 1. **Búsqueda por Email** (`searchMembers`)
- Busca coincidencias parciales del email del usuario en los campos: email, nombre, documento
- **Requisito**: El campo `email` debe existir en el registro del socio importado

### 2. **Búsqueda por EmployeeNumber/WorkerCode**
- Compara `AppUser.employeeNumber` con `Member.workerCode`
- **Requisito**: El usuario debe tener `employeeNumber` configurado Y debe coincidir exactamente con `workerCode` del socio

### 3. **Búsqueda por UserID como DocumentId**
- Compara `AppUser.id` (Firebase UID) con `Member.documentId`
- **Requisito**: El `documentId` del socio debe ser igual al UID de Firebase del usuario

### 4. **Escaneo Completo con Comparación Exacta**
- Recorre TODOS los miembros activos y compara:
  - Email exacto (case-insensitive, trimmed)
  - WorkerCode exacto (si existe employeeNumber)
  - DocumentId exacto (si existe employeeNumber)
- **Ventaja**: Muestra los primeros 5 miembros para diagnóstico visual

### 5. **Búsqueda por Nombre/DisplayName** (NUEVA)
- Compara `AppUser.displayName` con `Member.fullName`
- Detecta coincidencias exactas del nombre completo
- También detecta coincidencias parciales (solo informativo)

## Cómo Diagnosticar el Problema Exacto

### Paso 1: Ejecutar la Aplicación con Logs

1. Abre una terminal en la carpeta del proyecto:
   ```powershell
   cd d:\Sindicat_fluter_apk
   ```

2. Ejecuta la aplicación en modo debug:
   ```powershell
   flutter run -d windows
   # O para web:
   .\run_web.ps1
   ```

3. Inicia sesión con el usuario que debería tener código QR

4. Navega a "Mi Perfil" → pestaña "Código QR"

### Paso 2: Revisar los Logs en la Consola

Busca en la consola los logs que comienzan con:
```
🔍 UserProfile: Iniciando búsqueda de socio...
```

Los logs mostrarán información detallada como:

```
🔍 UserProfile: Iniciando búsqueda de socio...
   Datos del usuario autenticado:
   - ID: abc123xyz789
   - Email: usuario@ejemplo.com
   - EmployeeNumber: EMP001
   - DisplayName: Juan Pérez

📧 Estrategia 1: Búsqueda por email...
   Resultados de searchMembers: 0 encontrados

🔢 Estrategia 2: Búsqueda por employeeNumber...
   ❌ No se encontró miembro con workerCode=EMP001

🆔 Estrategia 3: Búsqueda por userId como documentId...
   ❌ No se encontró miembro con documentId=abc123xyz789

🔎 Estrategia 4: Escaneo completo de miembros...
   Total miembros activos en Firestore: 150
   
   📋 Primeros 5 miembros activos:
   [0] María González
       - workerCode: WC001
       - documentId: 123456789
       - email: maria@ejemplo.com
       - memberNumber: SOC001
   [1] Juan Pérez
       - workerCode: WC002
       - documentId: 987654321
       - email: juan.perez@gmail.com
       - memberNumber: SOC002
   ...
   
❌ RESULTADO: NO SE ENCONTRÓ SOCIO
   Se intentaron 5 estrategias de búsqueda
   ...
```

### Paso 3: Identificar la Causa Raíz

Basándote en los logs, identifica cuál es el problema:

#### **Caso A: Email no coincide**
```
Usuario email: "usuario@empresa.com"
Miembro email: "usuario@gmail.com"
```
**Solución**: Actualiza el email del socio en Firestore o cambia el email del usuario para que coincidan.

#### **Caso B: Email está vacío en el socio**
```
[0] Juan Pérez
    - workerCode: WC002
    - documentId: 987654321
    - email: N/A  ← ¡VACÍO!
```
**Solución**: Re-importa los socios asegurándote de incluir la columna "email" en el CSV/Excel.

#### **Caso C: EmployeeNumber no coincide con workerCode**
```
User employeeNumber: "EMP001"
Member workerCode: "WC002"
```
**Solución**: 
- Opción 1: Actualizar `employeeNumber` del usuario para que coincida con `workerCode`
- Opción 2: Actualizar `workerCode` del socio para que coincida con `employeeNumber`

#### **Caso D: No hay miembros activos**
```
Total miembros activos en Firestore: 0
⚠️ NO HAY MIEMBROS ACTIVOS en la base de datos
```
**Solución**: Verifica que la importación se completó correctamente y que los socios tienen `status: "active"`.

#### **Caso E: Nombre coincide pero otros campos no**
```
👤 Estrategia 5: Búsqueda por nombre/displayName...
⚠️ Coincidencia PARCIAL de nombre detectada (no usada automáticamente):
   User: "juan pérez"
   Member: "juan perez"
   💡 Si este es tu socio, verifica que el email o workerCode coincidan
```
**Solución**: Este log indica que el socio existe pero los identificadores (email/workerCode) no coinciden. Debes corregir uno de ellos.

#### **Caso F: Socio encontrado pero sin workerCode**
```
⚠️ Socio encontrado pero sin workerCode:
   Member ID: abc123xyz
   Nombre: Juan Gabriel Burbano Bonifaz
   Email: boris13jb@gmail.com
   workerCode: NULO
   💡 SOLUCIÓN: Actualiza el campo workerCode en Firestore para este socio
```
**Pantalla que verás**: Mensaje naranja con:
- ⚠️ "Tu registro de socio está incompleto"
- Nombre, email y estado del workerCode

**Solución**:
1. Abre Firebase Console → Firestore → colección `members`
2. Busca el socio por nombre o email
3. Agrega o actualiza el campo `workerCode` con el valor correcto (ej: "37325")
4. Reinicia la app - el código QR aparecerá automáticamente

## Soluciones Recomendadas

### Solución 1: Re-importar Socios con Email Correcto

Si el problema es que falta el email o está incorrecto:

1. Prepara un archivo CSV/Excel con estas columnas mínimas:
   ```
   memberNumber,firstName,lastName,email,workerCode,documentId
   SOC001,Juan,Pérez,juan@ejemplo.com,EMP001,123456789
   ```

2. Asegúrate de que:
   - La columna `email` tenga el **mismo email** que usaste para crear la cuenta de usuario
   - La columna `workerCode` tenga el valor que quieres usar para el código QR
   - El estado sea `active` (por defecto)

3. Importa el archivo desde la interfaz de administración

### Solución 2: Actualizar Manualmente el Socio en Firestore

Si solo necesitas corregir un socio específico:

1. Ve a Firebase Console → Firestore Database
2. Encuentra la colección `members`
3. Busca el documento del socio
4. Edita los campos:
   - `email`: debe coincidir con el email del usuario
   - `workerCode`: debe tener un valor válido (requerido para QR)
   - `status`: debe ser `"active"`

### Solución 3: Vincular Usuario con Socio mediante employeeNumber

Para vincular permanentemente el usuario con su socio:

1. En Firebase Console → Authentication, encuentra el usuario
2. Copia su UID (ej: `abc123xyz789`)
3. En Firestore → colección `users`, busca el documento con ese UID
4. Agrega/actualiza el campo:
   ```json
   {
     "employeeNumber": "WC002"  // Debe coincidir con workerCode del socio
   }
   ```

5. En Firestore → colección `members`, verifica que el socio tenga:
   ```json
   {
     "workerCode": "WC002"  // Debe coincidir con employeeNumber del usuario
   }
   ```

### Solución 4: Usar documentId como Puente

Alternativamente, puedes usar el `documentId` para vincular:

1. Establece el `documentId` del socio igual al UID del usuario de Firebase:
   ```json
   // En members/{memberId}
   {
     "documentId": "abc123xyz789"  // UID del usuario
   }
   ```

2. El sistema encontrará automáticamente el socio usando la Estrategia 3.

## Verificación Final

Después de aplicar la solución:

1. Cierra sesión completamente
2. Vuelve a iniciar sesión
3. Ve a "Mi Perfil" → "Código QR"
4. Deberías ver el código QR generado con el formato:
   ```json
   {
     "nombres": "Juan",
     "apellidos": "Pérez",
     "identificador": "WC002"
   }
   ```

## Notas Importantes

### Sobre el Campo `workerCode`

El campo `workerCode` es **CRÍTICO** para generar el código QR. Sin él, el sistema lanza una excepción:

```dart
if (member.workerCode == null || member.workerCode!.isEmpty) {
  throw Exception('No se puede generar QR: El socio no tiene Número de Trabajador (workerCode) asignado');
}
```

**Asegúrate de que:**
- Todos los socios importados tengan `workerCode` poblado
- El `workerCode` sea único por socio
- No esté vacío ni nulo

### Sobre las Coincidencias Parciales

La Estrategia 5 detecta coincidencias parciales de nombre pero **NO las usa automáticamente** para evitar falsos positivos. Si ves un log como:

```
⚠️ Coincidencia PARCIAL de nombre detectada (no usada automáticamente)
```

Esto significa que el socio probablemente existe, pero necesitas corregir el email o workerCode para que coincidan exactamente.

## Próximos Pasos

1. **Ejecuta la aplicación** y revisa los logs detallados
2. **Identifica la causa raíz** comparando los datos del usuario con los del socio
3. **Aplica la solución apropiada** (re-importar, actualizar manualmente, o vincular campos)
4. **Verifica** que el código QR aparezca correctamente

Si después de seguir estos pasos el problema persiste, comparte los logs completos de la consola para un análisis más detallado.
