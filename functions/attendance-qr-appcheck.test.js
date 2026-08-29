/**
 * App Check gate unit tests for Secure Attendance QR HTTP endpoints.
 * No production tokens. No Admin verifyToken against live Firebase.
 */

"use strict";

const {describe, it, beforeEach, afterEach} = require("node:test");
const assert = require("node:assert/strict");

const mod = require("./attendance-qr");
const {
  shouldEnforceAttendanceAppCheck,
  assertAppCheck,
  assertBearerUid,
  assertAuthenticatedRequest,
  setVerifyAppCheckTokenForTests,
  resetVerifyAppCheckTokenForTests,
  HttpError,
} = mod._test;

function fakeReq({headers = {}, body = {}} = {}) {
  const normalized = {};
  for (const [k, v] of Object.entries(headers)) {
    normalized[String(k).toLowerCase()] = v;
  }
  return {
    body,
    get(name) {
      return normalized[String(name).toLowerCase()];
    },
  };
}

const savedEnv = {};

function stashEnv(keys) {
  for (const key of keys) {
    savedEnv[key] = process.env[key];
  }
}

function restoreEnv(keys) {
  for (const key of keys) {
    if (savedEnv[key] === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = savedEnv[key];
    }
  }
}

const ENV_KEYS = [
  "FUNCTIONS_EMULATOR",
  "ATTENDANCE_QR_SKIP_APPCHECK",
  "ATTENDANCE_QR_REQUIRE_APPCHECK",
];

describe("shouldEnforceAttendanceAppCheck", () => {
  beforeEach(() => {
    stashEnv(ENV_KEYS);
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.ATTENDANCE_QR_SKIP_APPCHECK;
    delete process.env.ATTENDANCE_QR_REQUIRE_APPCHECK;
  });

  afterEach(() => {
    restoreEnv(ENV_KEYS);
    resetVerifyAppCheckTokenForTests();
  });

  it("production default: enforce TRUE even when REQUIRE flag is absent", () => {
    assert.equal(shouldEnforceAttendanceAppCheck(), true);
  });

  it("production does not skip App Check merely because REQUIRE flag is unset", () => {
    delete process.env.ATTENDANCE_QR_REQUIRE_APPCHECK;
    assert.equal(shouldEnforceAttendanceAppCheck(process.env), true);
  });

  it("REQUIRE_APPCHECK=0 does not disable enforcement (legacy flag ignored)", () => {
    process.env.ATTENDANCE_QR_REQUIRE_APPCHECK = "0";
    assert.equal(shouldEnforceAttendanceAppCheck(process.env), true);
  });

  it("emulator bypass when FUNCTIONS_EMULATOR=true", () => {
    process.env.FUNCTIONS_EMULATOR = "true";
    assert.equal(shouldEnforceAttendanceAppCheck(process.env), false);
  });

  it("explicit test skip ATTENDANCE_QR_SKIP_APPCHECK=1", () => {
    process.env.ATTENDANCE_QR_SKIP_APPCHECK = "1";
    assert.equal(shouldEnforceAttendanceAppCheck(process.env), false);
  });
});

describe("assertAppCheck", () => {
  beforeEach(() => {
    stashEnv(ENV_KEYS);
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.ATTENDANCE_QR_SKIP_APPCHECK;
    delete process.env.ATTENDANCE_QR_REQUIRE_APPCHECK;
    resetVerifyAppCheckTokenForTests();
  });

  afterEach(() => {
    restoreEnv(ENV_KEYS);
    resetVerifyAppCheckTokenForTests();
  });

  it("production-like: missing App Check header → DENIED missing-app-check", async () => {
    await assert.rejects(
      () => assertAppCheck(fakeReq({headers: {authorization: "Bearer x"}})),
      (err) => err instanceof HttpError &&
        err.status === 401 &&
        err.code === "missing-app-check",
    );
  });

  it("invalid App Check token → DENIED invalid-app-check", async () => {
    setVerifyAppCheckTokenForTests(async () => {
      throw new Error("verify failed");
    });
    await assert.rejects(
      () => assertAppCheck(fakeReq({
        headers: {"X-Firebase-AppCheck": "bad-token"},
      })),
      (err) => err instanceof HttpError &&
        err.status === 401 &&
        err.code === "invalid-app-check",
    );
  });

  it("valid App Check token (mock) → PASS", async () => {
    let seen = "";
    setVerifyAppCheckTokenForTests(async (token) => {
      seen = token;
    });
    await assertAppCheck(fakeReq({
      headers: {"x-firebase-appcheck": "good-token"},
    }));
    assert.equal(seen, "good-token");
  });

  it("header name is case-insensitive", async () => {
    setVerifyAppCheckTokenForTests(async () => undefined);
    await assertAppCheck(fakeReq({
      headers: {"X-FIREBASE-APPCHECK": "tok"},
    }));
  });

  it("emulator bypass → PASS without header", async () => {
    process.env.FUNCTIONS_EMULATOR = "true";
    await assertAppCheck(fakeReq());
  });
});

describe("assertAuthenticatedRequest = App Check + Auth", () => {
  beforeEach(() => {
    stashEnv(ENV_KEYS);
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.ATTENDANCE_QR_SKIP_APPCHECK;
    setVerifyAppCheckTokenForTests(async () => undefined);
  });

  afterEach(() => {
    restoreEnv(ENV_KEYS);
    resetVerifyAppCheckTokenForTests();
  });

  it("App Check valid but missing Auth → DENIED missing-auth", async () => {
    await assert.rejects(
      () => assertAuthenticatedRequest(fakeReq({
        headers: {"X-Firebase-AppCheck": "good"},
      })),
      (err) => err instanceof HttpError &&
        err.status === 401 &&
        err.code === "missing-auth",
    );
  });

  it("Auth present but App Check missing → DENIED missing-app-check", async () => {
    await assert.rejects(
      () => assertAuthenticatedRequest(fakeReq({
        headers: {Authorization: "Bearer id-token"},
      })),
      (err) => err instanceof HttpError &&
        err.status === 401 &&
        err.code === "missing-app-check",
    );
  });

  it("assertBearerUid alone rejects missing bearer", async () => {
    await assert.rejects(
      () => assertBearerUid(fakeReq()),
      (err) => err instanceof HttpError && err.code === "missing-auth",
    );
  });
});
