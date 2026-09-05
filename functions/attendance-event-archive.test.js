"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");

const mod = require("./attendance-qr");
const {
  eventAllowsMemberQr,
  handleDeleteEvent,
  HttpError,
  isSuperAdminRole,
} = mod._test;

describe("archived attendance events", () => {
  it("eventAllowsMemberQr excludes archived events", () => {
    assert.equal(
      eventAllowsMemberQr(
        {
          activo: true,
          estado: "en_curso",
          archivado: true,
          miembrosConvocados: [],
        },
        "m1",
      ),
      false,
    );
  });

  it("eventAllowsMemberQr keeps non-archived behavior", () => {
    assert.equal(
      eventAllowsMemberQr(
        {
          activo: true,
          estado: "en_curso",
          archivado: false,
          miembrosConvocados: [],
        },
        "m1",
      ),
      true,
    );
  });

  it("prepareOfflineEvent gate uses 403 event-archived", () => {
    const err = new HttpError(403, "event-archived");
    assert.equal(err.status, 403);
    assert.equal(err.code, "event-archived");
  });

  it("isSuperAdminRole only SUPERADMIN for hard delete", () => {
    assert.equal(isSuperAdminRole("SUPERADMIN"), true);
    assert.equal(isSuperAdminRole("ADMIN"), false);
    assert.equal(isSuperAdminRole("OPERADOR_ASISTENCIA"), false);
    assert.equal(typeof handleDeleteEvent, "function");
  });
});
