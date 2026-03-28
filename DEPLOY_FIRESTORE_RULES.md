# Desplegar reglas de Firestore

Para que los votos se guarden correctamente y no se pueda votar dos veces, las reglas de Firestore deben permitir escribir en `elections/{id}/votes`.

## Opción 1: Firebase Console (rápido)

1. Entra en [Firebase Console](https://console.firebase.google.com) y selecciona tu proyecto.
2. Ve a **Firestore Database** → pestaña **Reglas**.
3. Sustituye o añade las reglas de la sección **votes** (subcolección de elections). Debe haber algo como:

```
match /elections/{electionId} {
  allow read: if request.auth != null;
  allow create, update, delete: if request.auth != null;
  match /votes/{voteId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null
      && request.resource.data.userId == request.auth.uid
      && request.resource.data.electionId == electionId;
    allow update, delete: if false;
  }
  match /candidates/{candidateId} {
    allow read, write: if request.auth != null;
  }
}
```

4. Pulsa **Publicar**.

## Opción 2: Firebase CLI

1. Instala Firebase CLI: `npm install -g firebase-tools`
2. En la carpeta del proyecto: `firebase login` y luego `firebase init firestore` (elige el proyecto y el archivo `firestore.rules` que está en esta carpeta).
3. Despliega: `firebase deploy --only firestore`

El archivo `firestore.rules` en esta carpeta contiene las reglas completas para votos, elecciones, usuarios y asistencia.

## Comprobar que el voto se guarda

Después de desplegar las reglas:

1. Inicia sesión en la app.
2. Entra en una elección y vota por un candidato.
3. Deberías ver "¡Voto registrado correctamente!".
4. Sal con "Volver" y vuelve a entrar en la misma elección.
5. Debe aparecer "¡Voto Registrado! Ya has participado en esta elección" y no la lista de candidatos.

Si sigue fallando, en Firebase Console → Firestore → pestaña **Reglas** revisa que no haya errores de sintaxis y que la subcolección `votes` tenga la regla `allow create` con `request.resource.data.userId == request.auth.uid`.
