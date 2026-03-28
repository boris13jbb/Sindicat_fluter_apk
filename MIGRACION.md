# Migración a Flutter - Sistema Integrado Sindicato

Proyecto migrado desde la app Android (Kotlin/Compose) a Flutter en esta carpeta.

## Estructura migrada

- **Auth**: Login, registro (con número de trabajador), recuperar contraseña, cierre de sesión.
- **Home**: Pantalla principal con acceso a **Sistema de Voto** y (solo admin) **Sistema de Asistencia** (placeholder).
- **Módulo Voto**:
  - Lista de elecciones (activas para votantes, todas para admin).
  - Crear elección (admin).
  - Agregar candidatos (admin).
  - Votar (selección de candidato y confirmación).
  - Ver resultados (total votos y ranking).
  - Editar/Eliminar elección (admin; edición completa pendiente de ampliar).

## Firebase

- Se usa el **mismo proyecto Firebase** que la app Android (`sistema-integrado-sindicato`).
- `android/app/google-services.json` está copiado y el `applicationId` de la app Flutter es `com.skyrunner.sindicato` para reutilizar la misma configuración.
- Colecciones: `users`, `elections`, subcolecciones `elections/{id}/candidates` y `elections/{id}/votes`.

## Cómo ejecutar

1. `flutter pub get`
2. Conectar dispositivo o emulador Android.
3. `flutter run`

Para **iOS** hay que añadir `GoogleService-Info.plist` desde Firebase Console y configurar Firebase en Xcode.

## Dependencias principales

- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `provider` para estado (auth)

## Pendiente / opcional

- Módulo **Asistencia** (eventos, escáner, personas, exportar) como en la app Android.
- Edición completa de elección (fechas, descripción, etc.) en pantalla propia.
- Subida de foto de candidato (Firebase Storage).
- Regla “requerir asistencia” para votar (comprobar evento de asistencia).
