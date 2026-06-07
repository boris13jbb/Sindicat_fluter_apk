# Correo profesional de recuperación de contraseña

> Manual completo y reutilizable:
> [manual-backend-recuperacion-contrasena-profesional.md](manual-backend-recuperacion-contrasena-profesional.md)

La aplicación usa el backend `requestPasswordReset` para emitir un token propio
de un solo uso y enviar un correo HTML por SMTP. La pantalla para completar el
cambio está publicada en:

`https://sistema-integrado-sindicato.web.app/auth-action.html`

Firebase Authentication controla el nombre del remitente, asunto y contenido
del correo.

## Arquitectura aplicada

Firebase rechazó editar la plantilla y la URL global de acción con:

`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`

Por esa razón, Flutter llama a `/api/request-password-reset`. La función:

1. limita intentos por correo e IP;
2. genera un token aleatorio de 256 bits y guarda únicamente su hash;
3. crea un enlace que abre `auth-action.html`;
4. envía la plantilla profesional mediante Gmail SMTP;
5. devuelve siempre un mensaje genérico para no revelar si una cuenta existe.

El token vence en 30 minutos. `confirmPasswordReset` valida y consume el token,
y Firebase Admin actualiza la contraseña sin utilizar el controlador genérico
de Firebase.

Los secretos `SMTP_USER` y `SMTP_PASSWORD` se guardan exclusivamente en Google
Cloud Secret Manager.

## Configuración y despliegue del backend

```powershell
./tool/setup_password_reset_secrets.ps1
firebase deploy --only functions,hosting --project sistema-integrado-sindicato
```

Para Gmail, `SMTP_PASSWORD` debe ser una contraseña de aplicación, nunca la
contraseña normal de la cuenta.

La plantilla HTML vigente se mantiene en `functions/email-template.js`. Los
correos nuevos no utilizan `%LINK%` ni el controlador genérico de Firebase.
