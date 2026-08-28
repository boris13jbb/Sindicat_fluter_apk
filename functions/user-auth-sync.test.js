"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  resolveAuthActiveChange,
  roleChanged,
  isActiveFlag,
} = require("./user-auth-sync");

describe("resolveAuthActiveChange", () => {
  it("returns disable + revoke when user is deactivated", () => {
    assert.deepEqual(
      resolveAuthActiveChange({isActive: true}, {isActive: false}),
      {disabled: true, revokeTokens: true},
    );
  });

  it("returns enable when user is reactivated", () => {
    assert.deepEqual(
      resolveAuthActiveChange({isActive: false}, {isActive: true}),
      {disabled: false, revokeTokens: false},
    );
  });

  it("returns null when active flag did not change", () => {
    assert.equal(
      resolveAuthActiveChange({isActive: true}, {isActive: true}),
      null,
    );
  });
});

describe("roleChanged", () => {
  it("detects valid role updates", () => {
    assert.equal(
      roleChanged({role: "VOTER"}, {role: "ADMIN"}),
      true,
    );
  });

  it("ignores invalid target roles", () => {
    assert.equal(
      roleChanged({role: "VOTER"}, {role: "HACKER"}),
      false,
    );
  });
});

describe("isActiveFlag", () => {
  it("defaults missing flag to active", () => {
    assert.equal(isActiveFlag({}), true);
    assert.equal(isActiveFlag({isActive: false}), false);
  });
});
