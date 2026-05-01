# Script de Actualización Masiva de workerCode en Firestore

## Problema Identificado

Los miembros existentes en Firestore no tienen el campo `workerCode`, lo cual es **obligatorio** para generar códigos QR.

## Solución 1: Re-importar desde CSV (RECOMENDADA)

Esta es la opción más segura y completa.

### Pasos:

1. **Verificar el archivo CSV**
   - Archivo: `socios_corregido.csv`
   - Columna `worker_code`: ✅ Presente (primera columna)
   - Total de filas: 270 socios

2. **Acceder al panel de administración**
   - Iniciar sesión como `superadmin` o `admin`
   - Navegar a: "Importar Socios"

3. **Importar el archivo**
   - Seleccionar `socios_corregido.csv`
   - El sistema detectará automáticamente:
     - `worker_code` → `workerCode` en Firestore
     - `documento` → `documentId` en Firestore
     - `nombres` → `firstName`
     - `apellidos` → `lastName`
     - etc.

4. **Verificar importación**
   - El sistema mostrará resumen:
     - Importados correctamente
     - Duplicados omitidos
     - Errores encontrados

5. **Validar en "Mi Perfil"**
   - Cerrar sesión y volver a iniciar
   - Ir a "Mi Perfil" → pestaña "Código QR"
   - El código QR debería aparecer ahora

---

## Solución 2: Ejecutar Script de Actualización (AVANZADA)

Si no puedes re-importar, usa el script `update_worker_codes.dart`.

### Requisitos:

- Flutter SDK instalado
- Firebase CLI configurado
- Acceso al proyecto Firebase
- **Backup de Firestore recomendado**

### Pasos:

1. **Hacer backup de Firestore** (opcional pero recomendado)
   ```bash
   firebase firestore:export backups/$(date +%Y%m%d_%H%M%S)
   ```

2. **Ejecutar el script**
   ```bash
   cd d:/Sindicat_fluter_apk
   dart lib/update_worker_codes.dart
   ```

3. **Revisar resultados**
   - El script mostrará cuántos miembros fueron actualizados
   - Si hay errores, revisa los mensajes detallados

4. **Validar en la app**
   - Reiniciar la aplicación
   - Ir a "Mi Perfil" → "Código QR"

---

## Solución 3: Actualización Manual desde Consola Firebase

Para casos específicos o pocos registros.

### Pasos:

1. Acceder a [Firebase Console](https://console.firebase.google.com/)
2. Seleccionar el proyecto
3. Ir a "Firestore Database"
4. Seleccionar colección `members`
5. Para cada documento sin `workerCode`:
   - Abrir el documento
   - Agregar campo `workerCode` con el valor de `documentId`
   - Guardar cambios

⚠️ **Advertencia**: Este método es lento y propenso a errores humanos. Solo usar para < 10 registros.

---

## Verificación Post-Actualización

Después de aplicar cualquier solución:

1. **Verificar en Firestore Console**
   - Colección `members`
   - Seleccionar un miembro aleatorio
   - Confirmar que existe el campo `workerCode`

2. **Probar en la app**
   - Iniciar sesión con un socio importado
   - Ir a "Mi Perfil"
   - Pestaña "Código QR"
   - Debería mostrar el código QR generado

3. **Revisar logs**
   - Buscar mensajes como:
     ```
     🔍 UserProfile: Buscando miembro para usuario...
     ✅ Miembro encontrado vía email
     📱 Generando QR con workerCode: XXXXX
     ```

---

## Prevención Futura

El sistema ya está configurado correctamente para:

✅ Mapear `worker_code` del CSV a `workerCode` en Firestore  
✅ Validar que al menos `worker_code` O `documento` existan  
✅ Marcar miembros con `status: 'active'` por defecto  

**No deberían ocurrir nuevos casos de `workerCode` faltante en futuras importaciones.**

---

## Preguntas Frecuentes

### ¿Puedo usar `documento` como `workerCode`?
Sí. El script de actualización copia automáticamente `documentId` a `workerCode` si este último falta.

### ¿Qué pasa si un miembro no tiene ni `workerCode` ni `documento`?
El script reportará un error. Ese miembro deberá ser corregido manualmente o re-importado con datos completos.

### ¿Necesito borrar los miembros existentes antes de re-importar?
No necesariamente. El sistema detecta duplicados por `memberNumber` y los omite. Sin embargo, si quieres actualizar todos los campos, puedes:
1. Borrar la colección `members` desde Firestore Console
2. Re-importar desde cero

### ¿El campo `workerCode` es realmente obligatorio?
Sí. La lógica de generación de QR (`qr_encoding_helper.dart`) requiere este campo para codificar la información del socio.

---

## Contacto y Soporte

Si ninguna solución funciona:
1. Verificar reglas de seguridad de Firestore (`firestore.rules`)
2. Revisar logs de la consola del navegador/app
3. Confirmar que el usuario tiene rol adecuado (`superadmin` o `admin` para importar)
4. Verificar conectividad con Firebase
