"use strict";

const PUBLIC_APP_URL = "https://sistema-integrado-sindicato.web.app";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function buildBrandedResetUrl(firebaseResetLink) {
  const firebaseUrl = new URL(firebaseResetLink);
  const brandedUrl = new URL("/auth-action.html", PUBLIC_APP_URL);

  for (const key of ["mode", "oobCode", "apiKey", "lang", "continueUrl"]) {
    const value = firebaseUrl.searchParams.get(key);
    if (value) brandedUrl.searchParams.set(key, value);
  }

  return brandedUrl.toString();
}

function buildBackendResetUrl(token) {
  const brandedUrl = new URL("/auth-action.html", PUBLIC_APP_URL);
  brandedUrl.searchParams.set("token", token);
  return brandedUrl.toString();
}

function buildPasswordResetEmail({email, resetUrl}) {
  const safeEmail = escapeHtml(email);
  const safeResetUrl = escapeHtml(resetUrl);

  const subject = "Restablece tu contraseña | Sistema Integrado Sindicato";
  const text = [
    "Sistema Integrado Sindicato",
    "",
    "Recibimos una solicitud para restablecer la contraseña de tu cuenta.",
    `Cuenta: ${email}`,
    "",
    "Crea una nueva contraseña usando este enlace seguro:",
    resetUrl,
    "",
    "Este enlace es personal y de un solo uso.",
    "Si no solicitaste este cambio, puedes ignorar este correo.",
  ].join("\n");

  const html = `<!doctype html>
<html lang="es">
<body style="margin:0;padding:0;background:#f5f1fb;font-family:Arial,Helvetica,sans-serif;color:#2b2265;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f1fb;padding:28px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 12px 36px rgba(43,34,101,.12);">
          <tr>
            <td style="padding:30px 34px;background:#47328d;color:#ffffff;">
              <div style="font-size:12px;font-weight:bold;letter-spacing:.8px;color:#ddd2ff;">SISTEMA INTEGRADO SINDICATO</div>
              <h1 style="margin:14px 0 8px;font-size:27px;line-height:1.2;">Restablece tu contraseña</h1>
              <p style="margin:0;font-size:15px;line-height:1.55;color:#eee8ff;">Recupera el acceso a tu cuenta de forma segura.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 34px;">
              <p style="margin:0 0 15px;font-size:15px;line-height:1.65;">Hola:</p>
              <p style="margin:0 0 10px;font-size:15px;line-height:1.65;color:#514a63;">Recibimos una solicitud para crear una nueva contraseña para:</p>
              <p style="margin:0 0 24px;font-size:15px;font-weight:bold;color:#2b2265;">${safeEmail}</p>
              <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 auto 24px;">
                <tr>
                  <td align="center" bgcolor="#6847be" style="border-radius:12px;">
                    <a href="${safeResetUrl}" style="display:inline-block;padding:15px 26px;color:#ffffff;text-decoration:none;font-size:15px;font-weight:bold;border-radius:12px;">Crear nueva contraseña</a>
                  </td>
                </tr>
              </table>
              <div style="padding:15px 17px;background:#f2ecff;border-radius:12px;color:#514a63;font-size:13px;line-height:1.55;">
                Por seguridad, este enlace es personal y de un solo uso. Si no solicitaste este cambio, puedes ignorar este correo.
              </div>
              <p style="margin:24px 0 7px;font-size:12px;line-height:1.5;color:#777086;">Si el botón no funciona, abre este enlace:</p>
              <p style="margin:0;word-break:break-all;font-size:11px;line-height:1.5;color:#6847be;">${safeResetUrl}</p>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 34px;background:#faf8fd;border-top:1px solid #eee9f4;color:#777086;font-size:11px;line-height:1.5;text-align:center;">
              Mensaje automático de Sistema Integrado Sindicato. Nunca compartas tu contraseña.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return {subject, text, html};
}

module.exports = {
  PUBLIC_APP_URL,
  buildBackendResetUrl,
  buildBrandedResetUrl,
  buildPasswordResetEmail,
};
