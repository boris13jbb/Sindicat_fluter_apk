"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildBackendResetUrl,
  buildBrandedResetUrl,
  buildPasswordResetEmail,
} = require("./email-template");

test("buildBackendResetUrl points to the professional page", () => {
  const result = new URL(buildBackendResetUrl("secure-random-token"));

  assert.equal(result.origin, "https://sistema-integrado-sindicato.web.app");
  assert.equal(result.pathname, "/auth-action.html");
  assert.equal(result.searchParams.get("token"), "secure-random-token");
});

test("buildBrandedResetUrl sends Firebase action data to the professional page", () => {
  const result = new URL(
    buildBrandedResetUrl(
      "https://sistema-integrado-sindicato.firebaseapp.com/__/auth/action" +
        "?mode=resetPassword&oobCode=secure-code&apiKey=public-key&lang=es",
    ),
  );

  assert.equal(result.origin, "https://sistema-integrado-sindicato.web.app");
  assert.equal(result.pathname, "/auth-action.html");
  assert.equal(result.searchParams.get("mode"), "resetPassword");
  assert.equal(result.searchParams.get("oobCode"), "secure-code");
  assert.equal(result.searchParams.get("apiKey"), "public-key");
  assert.equal(result.searchParams.get("lang"), "es");
});

test("buildPasswordResetEmail creates branded HTML and escapes user data", () => {
  const message = buildPasswordResetEmail({
    email: 'member"<script>@example.com',
    resetUrl: "https://example.com/reset?oobCode=abc&mode=resetPassword",
  });

  assert.match(message.subject, /Sistema Integrado Sindicato/);
  assert.match(message.html, /Crear nueva contraseña/);
  assert.doesNotMatch(message.html, /member"<script>/);
  assert.match(message.html, /&amp;mode=resetPassword/);
  assert.match(message.text, /https:\/\/example.com\/reset/);
});
