# 🔧 SOLUCIÓN: El voto no se registra en Firebase

## Problema
La aplicación muestra "¡Voto Registrado!" pero los votos no aparecen en la base de datos.

## Causa
Estás mirando **Realtime Database** en Firebase, pero tu aplicación usa **Firestore Database**. Son bases de datos diferentes.

## Solución Paso a Paso

### Paso 1: Ir a Firestore Database (NO Realtime Database)

1. Abre [Firebase Console](https://console.firebase.google.com)
2. Selecciona tu proyecto "Sistema Integrado Sindicato"
3. En el menú izquierdo, haz clic en **Firestore Database** (está arriba de Realtime Database)

### Paso 2: Desplegar las reglas de seguridad

1. En Firestore Database, haz clic en la pestaña **Reglas** (Rules)
2. Copia el contenido del archivo `firestore_rules_for_deploy.txt` que está en este proyecto
3. Pega las reglas en el editor de Firebase Console
4. Haz clic en **Publicar**

### Paso 3: Verificar que Firestore esté habilitado

Si ves un mensaje que dice "Comenzar en modo bloqueado" o "Comenzar en modo de prueba":
- Selecciona **Comenzar en modo de prueba**
- Elige una ubicación (puede ser la que esté por defecto)
- Haz clic en **Siguiente** y luego en **Habilitar**

### Paso 4: Probar el voto

1. Ejecuta la aplicación: `flutter run -d windows`
2. Inicia sesión con un usuario
3. Ve a una elección y vota
4. Debería aparecer "¡Voto registrado correctamente!"
5. Ve a Firebase Console > Firestore Database > pestaña **Datos**
6. Navega a: `elections` → [tu elección] → `votes`
7. Deberías ver el documento del voto con:
   - `electionId`: ID de la elección
   - `userId`: ID del usuario que votó
   - `candidateId`: ID del candidato seleccionado
   - `votedAt`: timestamp

## Estructura de Firestore

Tu aplicación usa esta estructura:

```
elections/
  └── {electionId}/
      ├── (datos de la elección)
      ├── candidates/
      │   └── {candidateId}/
      │       ├── name: "Nombre"
      │       ├── voteCount: 5
      │       └── ...
      └── votes/
          └── {electionId_userId}/
              ├── electionId: "..."
              ├── userId: "..."
              ├── candidateId: "..."
              └── votedAt: Timestamp
```

## Reglas de Seguridad Importantes

Las reglas permiten crear un voto si:
- El usuario está autenticado (`request.auth != null`)
- El `userId` del voto coincide con el UID del usuario autenticado
- El ID del documento de voto no está vacío

## Si aún no funciona

1. **Verifica los errores en la consola:**
   - Ejecuta la app en modo debug
   - Presiona F12 para ver DevTools
   - Busca errores relacionados con Firestore

2. **Verifica que Firebase esté inicializado:**
   - Revisa `lib/main.dart` - Firebase debe inicializarse correctamente
   - Verifica que `firebase_options.dart` exista y esté configurado

3. **Limpia y reconstruye:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

## Diferencia entre las bases de datos

- **Firestore Database**: Base de datos documental (usa colecciones y documentos)
- **Realtime Database**: Base de datos JSON (usa estructura de árbol)

Tu aplicación usa **Firestore**, no Realtime Database.

## Notas Adicionales

- El archivo `firestore.rules` en el proyecto contiene las reglas correctas
- También puedes usar Firebase CLI para desplegar:
  ```powershell
  npm install -g firebase-tools
  firebase login
  firebase init firestore
  firebase deploy --only firestore
  ```
