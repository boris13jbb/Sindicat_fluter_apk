'use strict';

/**
 * Normaliza identificadores estables (no nombres).
 * @param {unknown} value
 * @returns {string}
 */
function normalizeId(value) {
  if (value == null) return '';
  return String(value).trim();
}

/**
 * Email en minúsculas sin espacios.
 * @param {unknown} value
 * @returns {string}
 */
function normalizeEmail(value) {
  return normalizeId(value).toLowerCase();
}

/**
 * Replica `AttendanceService` / `AsistenciaService` `_safeDocSegment`.
 * @param {string} raw
 * @returns {string}
 */
function safeDocSegment(raw) {
  const trimmed = normalizeId(raw);
  if (!trimmed) return '_';
  const encoded = Buffer.from(trimmed, 'utf8').toString('base64url');
  return encoded.replace(/=/g, '') || '_';
}

/**
 * ID determinístico legacy asistencia (evento + persona).
 * @param {string} eventoId
 * @param {string} personaId
 */
function legacyAsistenciaId(eventoId, personaId) {
  return `${safeDocSegment(eventoId)}_${safeDocSegment(personaId)}`;
}

/**
 * ID determinístico moderno asistencia (solo memberId en subcolección).
 * @param {string} memberId
 */
function modernAsistenciaDocId(memberId) {
  return safeDocSegment(memberId);
}

module.exports = {
  normalizeId,
  normalizeEmail,
  safeDocSegment,
  legacyAsistenciaId,
  modernAsistenciaDocId,
};
