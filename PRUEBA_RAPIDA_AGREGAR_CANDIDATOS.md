# 🧪 Guía Rápida de Prueba - Función Agregar Candidatos

## ✅ Estado de la Aplicación

**Aplicación compilada exitosamente:** `build\windows\x64\runner\Debug\fluter_apk.exe`

**Correcciones aplicadas:**
- ✅ Validación de electionId agregada
- ✅ Mejores mensajes de éxito (verde)
- ✅ Mejores mensajes de error (rojo)
- ✅ Integridad de datos en Firestore mejorada

---

## 🚀 Cómo Ejecutar la Aplicación

### Opción 1: Desde PowerShell (Recomendado)
```powershell
cd D:\Sindicat_fluter_apk
flutter run -d windows
```

### Opción 2: Ejecutable Directo
```powershell
.\build\windows\x64\runner\Debug\fluter_apk.exe
```

---

## 📋 Pasos para Probar "Agregar Candidatos"

### Paso 1: Iniciar Sesión
1. Abre la aplicación
2. Ingresa tus credenciales de administrador
3. Navega a la sección "Elecciones"

### Paso 2: Seleccionar una Elección
1. Busca una elección existente
2. Haz clic en el botón **"Agregar Candidato"** que aparece en la tarjeta de la elección

### Paso 3: Completar Formulario

**Prueba Exitosa:**
```
Nombre: Juan Pérez ⭐ (Requerido)
Descripción: Candidato con experiencia en liderazgo
URL de Imagen: https://via.placeholder.com/150
Orden: 1
```

**Botón:** "Agregar Candidato"

### Paso 4: Verificar Resultados

**Inmediatamente después de hacer clic:**

✅ **Éxito Esperado:**
- Mensaje verde: "Candidato agregado exitosamente"
- Vuelve automáticamente a la pantalla anterior
- El candidato aparece en la lista de candidatos
- En Firebase Console > Firestore > elections/{id}/candidates/{id}
  ```json
  {
    "id": "generado_automaticamente",
    "electionId": "id_de_eleccion",
    "name": "Juan Pérez",
    "description": "Candidato con experiencia en liderazgo",
    "imageUrl": "https://via.placeholder.com/150",
    "order": 1,
    "voteCount": 0
  }
  ```

❌ **Errores a Verificar:**

**Error 1 - Nombre vacío:**
- Deja el campo "Nombre" vacío
- Presiona "Agregar Candidato"
- **Resultado esperado:** Mensaje "Requerido" en el campo nombre

**Error 2 - ElectionId inválido:**
- Este caso es difícil de probar manualmente (requeriría modificar el código)
- **Resultado esperado:** Mensaje rojo "Error: ID de elección no válido"

**Error 3 - Error de Firestore:**
- Si las reglas de seguridad no están configuradas
- **Resultado esperado:** Mensaje rojo "Error al agregar: [detalle del error]"

---

## 🔍 ¿Qué Verificar en Firebase Console?

### 1. Ir a Firestore Database
URL: https://console.firebase.google.com

### 2. Navegar a la Colección
```
elections
  └─ {electionId}
      └─ candidates
          └─ {candidateId}
```

### 3. Verificar Campos del Documento
- ✅ `id`: Debe ser un string único generado por Firestore
- ✅ `electionId`: Debe coincidir con el ID de la elección padre
- ✅ `name`: Nombre completo del candidato
- ✅ `description`: Descripción o null
- ✅ `imageUrl`: URL válida o null
- ✅ `order`: Número entero (default 0)
- ✅ `voteCount`: Debe ser 0 para nuevos candidatos

---

## 🎯 Criterios de Aceptación

### Funcionalidad Básica
- [ ] El formulario abre correctamente
- [ ] Campo nombre es requerido
- [ ] Campos descripción, imagen y orden son opcionales
- [ ] Botón "Agregar Candidato" funciona

### Retroalimentación Visual
- [ ] Mensaje de éxito es VERDE
- [ ] Mensaje de éxito dice "Candidato agregado exitosamente"
- [ ] Mensaje de error es ROJO
- [ ] Mensaje de error incluye detalles del error

### Comportamiento
- [ ] Después de agregar, vuelve a la pantalla anterior
- [ ] La lista de candidatos se actualiza automáticamente
- [ ] No se requiere recargar la página
- [ ] El candidato nuevo aparece en la lista

### Datos
- [ ] Todos los campos se guardan en Firestore
- [ ] voteCount inicia en 0
- [ ] order defaults a 0 si no se especifica
- [ ] electionId se guarda correctamente

---

## 🐛 Solución de Problemas Comunes

### Problema: La aplicación no inicia
**Solución:**
```powershell
flutter clean
flutter pub get
flutter run -d windows
```

### Problema: Error "No such module: cloud_firestore"
**Solución:**
```powershell
flutter pub get
flutter clean
flutter run -d windows
```

### Problema: Candidato no aparece en Firestore
**Posibles causas:**
1. Reglas de seguridad no desplegadas
2. Usuario no autenticado
3. Error de conexión

**Solución:**
1. Verifica estar logueado como administrador
2. Revisa las reglas en Firebase Console > Firestore > Reglas
3. Asegúrate que las reglas digan:
   ```javascript
   match /candidates/{candidateId} {
     allow create: if isAuthenticated();
   }
   ```

### Problema: Mensaje de error poco claro
**Acción:** Revisa la consola de Flutter para ver el error completo
```
[ERROR:flutter/...] Detalle del error aquí
```

---

## 📊 Capturas de Pantalla Sugeridas

Para documentar las pruebas, toma capturas de:

1. ✅ Formulario de agregar candidato completo
2. ✅ Mensaje de éxito verde después de agregar
3. ✅ Lista de candidatos actualizada con el nuevo candidato
4. ✅ Documento en Firebase Console mostrando todos los campos
5. ❌ Mensaje de error cuando nombre está vacío
6. ❌ Mensaje de error rojo (si ocurre algún error)

---

## 📝 Checklist de Prueba Final

### Antes de Aprobar
- [ ] Probé agregar un candidato con todos los campos completos
- [ ] Probé agregar un candidato solo con nombre (mínimo requerido)
- [ ] Verifiqué que el mensaje de éxito es verde
- [ ] Verifiqué que la lista se actualiza automáticamente
- [ ] Verifiqué en Firebase Console que los datos se guardaron
- [ ] Probé dejar el nombre vacío y muestra error
- [ ] El candidato aparece con voteCount = 0

### Después de Aprobar
- [ ] Todos los criterios anteriores pasan
- [ ] Documenté cualquier problema encontrado
- [ ] Tomé capturas de pantalla de evidencia
- [ ] Verifiqué que no hay errores en la consola

---

## 🎉 Resultado Esperado

Si todas las pruebas pasan exitosamente:
- ✅ La funcionalidad "Agregar Candidatos" está lista para producción
- ✅ Los usuarios pueden agregar candidatos sin problemas
- ✅ La retroalimentación visual es clara y útil
- ✅ Los datos se integran correctamente con Firestore

---

## 📞 Soporte

Si encuentras problemas durante las pruebas:

1. **Revisa la consola de Flutter** - Muestra errores detallados
2. **Verifica Firebase Console** - Confirma que las reglas estén desplegadas
3. **Consulta la documentación completa** - `ADD_CANDIDATES_COMPLETE_REPORT.md`
4. **Revisa las correcciones aplicadas** - `ADD_CANDIDATE_FIX_SUMMARY.md`

---

**¡Listo para probar!** 🚀

Ejecuta la aplicación y sigue los pasos anteriores para verificar que las correcciones funcionen correctamente.
