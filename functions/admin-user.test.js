"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  parseInvitePayload,
  parseAdminResetPayload,
  memberIsActive,
  createTemporaryPassword,
} = require("./admin-user");

describe("parseInvitePayload", () => {
  it("accepts valid invite data", () => {
    const result = parseInvitePayload({
      email: " Ana@Example.COM ",
      role: "admin",
      displayName: "Ana Perez",
      employeeNumber: "W-100",
    });
    assert.equal(result.error, undefined);
    assert.deepEqual(result.payload, {
      email: "ana@example.com",
      role: "ADMIN",
      displayName: "Ana Perez",
      employeeNumber: "W-100",
    });
  });

  it("rejects invalid email", () => {
    const result = parseInvitePayload({email: "bad"});
    assert.match(result.error, /correo/i);
  });

  it("rejects invalid role", () => {
    const result = parseInvitePayload({
      email: "a@b.com",
      role: "ROOT",
    });
    assert.match(result.error, /rol/i);
  });
});

describe("parseAdminResetPayload", () => {
  it("accepts valid target user id", () => {
    const result = parseAdminResetPayload({targetUserId: " abc123 "});
    assert.equal(result.error, undefined);
    assert.deepEqual(result.payload, {targetUserId: "abc123"});
  });

  it("rejects missing target user id", () => {
    const result = parseAdminResetPayload({});
    assert.match(result.error, /usuario objetivo/i);
  });
});

describe("memberIsActive", () => {
  it("accepts active statuses", () => {
    assert.equal(memberIsActive({status: "active"}), true);
    assert.equal(memberIsActive({status: "Activo"}), true);
    assert.equal(memberIsActive({status: "inactive"}), false);
  });
});

describe("createTemporaryPassword", () => {
  it("generates a reasonably long password", () => {
    const password = createTemporaryPassword();
    assert.ok(password.length >= 12);
  });
});
