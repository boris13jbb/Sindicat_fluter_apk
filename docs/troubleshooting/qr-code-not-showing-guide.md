# Guía para Resolver Problema: Código QR No Aparece (0 Socios en Firestore)

## Diagnóstico del Problema

El sistema muestra "Código QR no disponible" porque **no hay socios importados en la base de datos Firestore**. Los logs confirman:
```
Total miembros activos en Firestore: 0
```

Esto significa que la colección `members` en Firestore está completamente vacía o no tiene documentos con `status: 'active'`.

---

## Pasos para Verificar y Solucionar

### PASO 1: Verificar Datos en Firebase Console

1. **Abrir Firebase Console**
   - Ir a: https://console.firebase.google.com/
   - Seleccionar tu proyecto

2. **Navegar a Firestore Database**
   - En el menú lateral, hacer clic en "Firestore Database"
   - Verificar que estás en la base de datos correcta

3. **Revisar Colección `members`**
   - Buscar la colección llamada `members`
   - Si NO existe → **Los socios nunca fueron importados**
   - Si existe pero está vacía → **La importación falló o se borraron los datos**
   - Si tiene documentos → Expandir uno y verificar campos:
     ```
     ✅ Debe tener:
     - status: "active" (string)
     - workerCode: "XXX" (string, OBLIGATORIO para QR)
     - memberNumber: número
     - firstName: string
     - lastName: string
     - documentId: string (cédula)
     
     ❌ Si falta alguno:
     - Re-importar con archivo correcto
     ```

4. **Contar Documentos**
   - Ver cuántos documentos hay en total
   - Si hay 0 → Ir al PASO 2
   - Si hay documentos pero ningún socio aparece → Verificar campo `status`

---

### PASO 2: Importar Socios Correctamente

#### Opción A: Desde la Aplicación (Recomendado)

1. **Iniciar sesión como Superadmin**
   - Usar credenciales de administrador con rol `superadmin`

2. **Ir al Panel de Administración**
   - Navegar a la sección "Administración" o "Gestión de Socios"
   - Buscar botón "Importar Socios" o "Import Members"

3. **Preparar Archivo CSV/Excel**
   
   **Formato CSV (ejemplo):**
   ```csv
   numero_socio,nombres,apellidos,documento,email,telefono,worker_code
   1,Juan,Pérez,1234567890,juan@email.com,555-1234,W001
   2,María,García,0987654321,maria@email.com,555-5678,W002
   ```

   **Columnas OBLIGATORIAS:**
   - `numero_socio` → Número único del socio
   - `nombres` → Primer nombre(s)
   - `apellidos` → Apellido(s)
   - `documento` → Cédula o documento de identidad
   - `worker_code` → **CÓDIGO DE TRABAJADOR (OBLIGATORIO PARA QR)**

   **Columnas OPCIONALES:**
   - `email` → Correo electrónico (recomendado para matching automático)
   - `telefono` → Teléfono de contacto

   **⚠️ IMPORTANTE:**
   - El archivo debe tener encabezados en la primera fila
   - `worker_code` es **OBLIGATORIO** para generar códigos QR
   - Sin `worker_code`, el socio se importa pero NO podrá ver su QR
   - El email debe coincidir exactamente con el email del usuario autenticado

4. **Subir Archivo**
   - Seleccionar archivo CSV o Excel (.xlsx)
   - Confirmar importación
   - Esperar mensaje de éxito

5. **Verificar Resumen de Importación**
   - Revisar conteo de:
     - ✅ Importados correctamente
     - ⚠️ Duplicados omitidos
     - ❌ Errores de validación
   - Si hay errores, descargar reporte y corregir archivo

#### Opción B: Importación Manual desde Firebase Console

Si la importación desde la app falla, puedes agregar manualmente:

1. **En Firebase Console > Firestore Database**
2. **Crear colección `members`** (si no existe)
3. **Agregar documento** con ID automático
4. **Campos requeridos:**
   ```
   Field Name        | Type    | Example Value
   ------------------|---------|---------------------------
   memberNumber      | number  | 1
   firstName         | string  | "Juan"
   lastName          | string  | "Pérez"
   fullName          | string  | "Juan Pérez"
   workerCode        | string  | "W001"
   documentId        | string  | "1234567890"
   email             | string  | "juan@email.com"
   phone             | string  | "555-1234"
   status            | string  | "active"
   createdAt         | number  | 1712678400000 (timestamp ms)
   updatedAt         | number  | 1712678400000 (timestamp ms)
   createdBy         | string  | "userId_del_admin"
   ```

5. **Repetir** para cada socio

---

### PASO 3: Verificar Después de Importar

1. **Recargar la aplicación**
   - Cerrar y reabrir la app
   - O forzar recarga (Ctrl+R en Web, pull-to-refresh en móvil)

2. **Iniciar sesión nuevamente**
   - Cerrar sesión actual
   - Volver a iniciar con el mismo usuario

3. **Navegar a "Mi Perfil" → "Código QR"**
   - Si ahora aparece el QR → ✅ **Problema resuelto**
   - Si aún dice "No hay socios importados" → Verificar PASO 4
   - Si dice "Posibles causas" (mensaje naranja) → Verificar PASO 5

---

### PASO 4: Diagnóstico Avanzado (Si Sigue Sin Funcionar)

#### Verificar Logs de Consola

Ejecutar la app y revisar consola (DevTools o terminal):

```bash
# Para Web
flutter run -d chrome --web-port=8080

# Para Windows
./run_windows.ps1
```

Buscar estos logs específicos:

```
🔍 UserProfile: Iniciando búsqueda de socio...
   Total miembros activos en Firestore: X
```

**Escenario A: `X = 0`**
- La colección sigue vacía
- La importación no se ejecutó correctamente
- **Solución:** Repetir PASO 2, verificar permisos de escritura en Firestore

**Escenario B: `X > 0` pero no encuentra al usuario**
- Hay miembros pero no coincide el email/workerCode
- **Solución:** Ir al PASO 5

#### Verificar Reglas de Firestore

En Firebase Console > Firestore > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regla para colección members
    match /members/{memberId} {
      // Lectura permitida para usuarios autenticados
      allow read: if request.auth != null;
      
      // Escritura solo para admin/superadmin
      allow write: if request.auth != null && 
                   get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'superadmin'];
    }
  }
}
```

Si las reglas son más restrictivas, ajustar temporalmente para pruebas:
```javascript
// SOLO PARA PRUEBAS - NO USAR EN PRODUCCIÓN
allow read, write: if true;
```

---

### PASO 5: Verificar Matching de Usuario

Si hay miembros en la BD pero el QR no aparece:

1. **Verificar Email del Usuario Autenticado**
   - En la app, ir a "Mi Perfil" → pestaña "Información"
   - Anotar el email mostrado
   - Comparar con el email en Firestore del socio correspondiente
   - Deben ser **IDÉNTICOS** (case-sensitive)

2. **Verificar WorkerCode**
   - En Firestore, buscar el documento del socio
   - Verificar que el campo `workerCode` existe y no está vacío
   - Comparar con `employeeNumber` del usuario (si existe)

3. **Verificar Status**
   - En Firestore, verificar que `status` sea exactamente `"active"` (minúsculas)
   - Si es `"Active"`, `"ACTIVO"`, `"activo"` → El sistema debería manejarlo, pero mejor estandarizar

4. **Corregir Discrepancias**
   - Actualizar email del usuario en Firebase Auth para que coincida
   - O actualizar email del socio en Firestore
   - Agregar `workerCode` si falta
   - Cambiar `status` a `"active"` si es diferente

---

## Ejemplo de Archivo CSV Correcto

```csv
numero_socio,nombres,apellidos,documento,email,telefono,worker_code
1,Juan Carlos,Pérez García,1234567890,juan.perez@empresa.com,555-1234,W001
2,María Elena,Rodríguez López,0987654321,maria.rodriguez@empresa.com,555-5678,W002
3,Carlos Alberto,Martínez Silva,1122334455,carlos.martinez@empresa.com,555-9012,W003
```

**Notas:**
- Primera fila = encabezados (obligatorio)
- Separador = coma (,)
- Encoding = UTF-8
- Sin espacios extra en nombres de columnas
- `worker_code` es **OBLIGATORIO** para QR

---

## Validación Final

Después de completar todos los pasos:

✅ **Verificación Exitosa:**
1. Firestore tiene documentos en colección `members`
2. Al menos un socio tiene `status: "active"`
3. El socio tiene `workerCode` válido (no vacío)
4. El email del usuario autenticado coincide con el email del socio
5. En "Mi Perfil" → "Código QR" aparece el código QR escaneable

❌ **Si Aún Falla:**
1. Capturar screenshot de la pantalla "Mi Perfil"
2. Copiar logs completos de la consola (desde el inicio hasta el error)
3. Capturar screenshot de Firebase Console mostrando la colección `members`
4. Proporcionar esta información para diagnóstico adicional

---

## Comandos Útiles para Debugging

```bash
# Limpiar build y reinstalar dependencias
flutter clean
flutter pub get

# Ejecutar con logs detallados
flutter run -d chrome --verbose

# Analizar código en busca de errores
flutter analyze

# Ejecutar tests (si existen)
flutter test
```

---

## Preguntas Frecuentes

**P: ¿Puedo importar socios sin worker_code?**
R: Sí, pero esos socios NO podrán ver su código QR. El worker_code es obligatorio para la generación de QR.

**P: ¿Qué pasa si importo el mismo archivo dos veces?**
R: El sistema detecta duplicados por `documento` (cédula) y omite registros repetidos.

**P: ¿Cuánto tarda en aparecer el QR después de importar?**
R: Inmediatamente. Solo necesitas cerrar sesión y volver a iniciar para refrescar los datos.

**P: ¿Puedo editar un socio después de importarlo?**
R: Sí, desde Firebase Console o desde el panel de administración si la app lo permite.

**P: ¿El QR cambia si actualizo los datos del socio?**
R: No. El QR se genera basado en `workerCode`, que no debería cambiar. Si cambia el workerCode, el QR será diferente.

---

## Contacto de Soporte

Si después de seguir todos los pasos el problema persiste:
1. Reunir toda la información de debugging mencionada arriba
2. Documentar exactamente qué pasos se siguieron
3. Indicar plataforma donde ocurre el problema (Web/Android/iOS/Windows)
4. Proporcionar versión de Flutter: `flutter --version`

---

**Última actualización:** 2026-04-09  
**Versión del sistema:** MVP Sindicat_fluter_apk
