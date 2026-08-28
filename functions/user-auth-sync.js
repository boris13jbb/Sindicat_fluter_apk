"use strict";

const VALID_ROLES = new Set([
  "SUPERADMIN",
  "ADMIN",
  "OPERADOR_ASISTENCIA",
  "VOTER",
  "USER",
]);

function isActiveFlag(data) {
  return data?.isActive !== false;
}

/**
 * Devuelve `{disabled, revokeTokens}` si cambió el estado activo; `null` si no cambió.
 */
function resolveAuthActiveChange(before = {}, after = {}) {
  const wasActive = isActiveFlag(before);
  const isActive = isActiveFlag(after);
  if (wasActive === isActive) return null;

  return {
    disabled: !isActive,
    revokeTokens: !isActive,
  };
}

function roleChanged(before = {}, after = {}) {
  const prev = String(before.role || "");
  const next = String(after.role || "");
  return prev !== next && VALID_ROLES.has(next);
}

module.exports = {
  VALID_ROLES,
  isActiveFlag,
  resolveAuthActiveChange,
  roleChanged,
};
