"use strict";

const {VALID_ROLES} = require("./user-auth-sync");

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
}

function parseInvitePayload(body) {
  const email = normalizeEmail(body?.email);
  if (!isValidEmail(email)) {
    return {error: "Ingresa un correo válido."};
  }

  const role = String(body?.role || "VOTER").trim().toUpperCase();
  if (!VALID_ROLES.has(role)) {
    return {error: "Rol no válido."};
  }

  const displayName = String(body?.displayName || "").trim();
  const employeeNumber = String(body?.employeeNumber || "").trim();

  return {
    payload: {
      email,
      role,
      displayName: displayName || null,
      employeeNumber: employeeNumber || null,
    },
  };
}

function memberIsActive(data) {
  const status = String(data?.status || "active").toLowerCase();
  return status === "active" || status === "activo";
}

function createTemporaryPassword() {
  const crypto = require("node:crypto");
  return `${crypto.randomBytes(9).toString("base64url")}Aa1!`;
}

function parseAdminResetPayload(body) {
  const targetUserId = String(body?.targetUserId || "").trim();
  if (!targetUserId) {
    return {error: "Debe indicar el usuario objetivo."};
  }
  return {payload: {targetUserId}};
}

module.exports = {
  normalizeEmail,
  isValidEmail,
  parseInvitePayload,
  parseAdminResetPayload,
  memberIsActive,
  createTemporaryPassword,
};
