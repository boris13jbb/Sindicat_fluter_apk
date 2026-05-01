# Scripts de Utilidad

Este directorio contiene scripts de utilidad para mantenimiento y operaciones en la base de datos.

## update_missing_worker_codes.dart

### Propósito

Actualiza miembros existentes en Firestore que no tienen el campo `workerCode`, copiando el valor de `memberNumber` como fallback.

Esto es necesario porque:
- El código QR requiere el campo `workerCode` para generarse correctamente
- Miembros importados antes de la corrección pueden no tener este campo
- La columna `worker_code` del CSV corresponde directamente a `numero_socio` (son el mismo identificador único)

### Cuándo usarlo

- Después de importar socios desde CSV/Excel si algunos no tienen `workerCode`
- Si los códigos QR no se generan para algunos miembros
- Como operación de mantenimiento después de actualizar la lógica de importación

### Cómo ejecutarlo

```bash
cd d:\Sindicat_fluter_apk
dart run scripts/update_missing_worker_codes.dart
```

### Qué hace el script

1. **Conecta a Firebase** usando las credenciales configuradas en `firebase_options.dart`
2. **Lee todos los miembros** de la colección `members` en Firestore
3. **Identifica miembros** sin `workerCode` o con `workerCode` vacío
4. **Actualiza cada miembro** estableciendo `workerCode = memberNumber`
5. **Muestra un resumen** con:
   - Total de miembros procesados
   - Miembros actualizados exitosamente
   - Miembros omitidos (ya tenían workerCode o no tienen memberNumber válido)
   - Errores encontrados (si los hay)

### Ejemplo de salida

```
🚀 Iniciando actualización de workerCode faltantes...

✅ Firebase inicializado correctamente

📋 Obteniendo todos los miembros de Firestore...
   Total de miembros encontrados: 270

   ✅ Actualizado: ID=21295, workerCode=21295
   ✅ Actualizado: ID=76992, workerCode=76992
   ...
   
============================================================
📊 RESUMEN DE ACTUALIZACIÓN
============================================================
   Total de miembros procesados: 270
   Miembros actualizados:        245
   Miembros omitidos:            25
   Errores:                      0
============================================================

✅ ¡Actualización completada exitosamente!
   245 miembros ahora tienen workerCode configurado.
```

### Seguridad

- ✅ El script es **idempotente**: puedes ejecutarlo múltiples veces sin riesgo
- ✅ Solo actualiza miembros que realmente necesitan el campo
- ✅ No modifica miembros que ya tienen `workerCode` configurado
- ✅ Registra timestamp de actualización (`updatedAt`)
- ✅ Muestra errores detallados si ocurren problemas

### Requisitos

- Flutter/Dart instalado
- Configuración de Firebase correcta en `lib/firebase_options.dart`
- Acceso de escritura a la colección `members` en Firestore

### Solución de problemas

**Error: "No hay miembros en la base de datos"**
- Verifica que hayas importado socios primero usando la función de importación CSV/Excel
- Confirma que estás conectado al proyecto correcto de Firebase

**Error: "Firebase initialization failed"**
- Verifica que `firebase_options.dart` esté correctamente configurado
- Asegúrate de haber ejecutado `flutter pub get`

**Errores de permisos**
- Verifica las reglas de Firestore en `firestore.rules`
- Asegúrate de estar autenticado con permisos de escritura

### Estructura esperada del documento en Firestore

```javascript
{
  "memberNumber": "21295",           // Número de socio (requerido)
  "firstName": "SEGUNDO MANUEL",     // Nombres
  "lastName": "LLAMUCA CARGUACUNDO", // Apellidos
  "fullName": "SEGUNDO MANUEL LLAMUCA CARGUACUNDO",
  "workerCode": "21295",             // ← Este campo se actualiza
  "documentId": "602322711",         // Cédula/DNI
  "email": null,
  "phone": null,
  "status": "active",
  "createdAt": 1234567890000,
  "updatedAt": 1234567890000,
  "createdBy": "user_uid_here"
}
```

### Notas importantes

- El script usa `DefaultFirebaseOptions.currentPlatform`, por lo que funcionará en la plataforma donde se ejecute
- Para producción, considera hacer un backup de Firestore antes de ejecutar actualizaciones masivas
- El script no elimina ni modifica otros campos, solo añade/actualiza `workerCode`
