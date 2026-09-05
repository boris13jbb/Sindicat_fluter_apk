"use strict";

// Real transaction/HTTP tests. TEST KEYS - NEVER USE IN PRODUCTION.
const {describe, it, before, after} = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const cryptoHelpers = require("./attendance-qr-crypto");
const PROJECT = "demo-sindicat-attendance-qr-v2";
const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const enabled = Boolean(fsHost && authHost);

describe("scanner provisioning real emulator security", {skip: !enabled}, () => {
  let app, db, api, keyA, keyB, operator, administrator;
  const ids = [];
  const prefix = `scanner-review-${Date.now()}`;
  const id = (suffix) => {
    const value = `${prefix}-${suffix}`;
    ids.push(value);
    return value;
  };

  before(async () => {
    // Fail closed before any SDK operation if this is not a loopback emulator.
    assert.match(fsHost, /^(127\.0\.0\.1|localhost):\d+$/);
    assert.match(authHost, /^(127\.0\.0\.1|localhost):\d+$/);
    const functionHost = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
    assert.match(functionHost, /^(127\.0\.0\.1|localhost):\d+$/);
    api = `http://${functionHost}/${PROJECT}/us-central1`;
    app = admin.initializeApp({projectId: PROJECT}, prefix);
    db = app.firestore();
    keyA = cryptoHelpers.keyFromSeedBase64Url(Buffer.alloc(32, 3).toString("base64url")).publicKeyBase64Url;
    keyB = cryptoHelpers.keyFromSeedBase64Url(Buffer.alloc(32, 4).toString("base64url")).publicKeyBase64Url;
    const createUser = async (role, label) => {
      const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test`, {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email: `${prefix}-${label}@test.invalid`,
          password: "emulator-only-test-password", returnSecureToken: true}),
      });
      assert.equal(response.status, 200);
      const result = await response.json();
      await db.collection("users").doc(result.localId).set({role, isActive: true});
      return {uid: result.localId, token: result.idToken};
    };
    operator = await createUser("OPERADOR_ASISTENCIA", "operator");
    administrator = await createUser("ADMIN", "admin");
  });

  after(async () => {
    if (!db) return;
    for (const scannerId of ids) await db.collection("attendance_scanner_devices").doc(scannerId).delete();
    for (const user of [operator, administrator].filter(Boolean)) {
      await db.collection("users").doc(user.uid).delete();
      await app.auth().deleteUser(user.uid);
    }
    await app.delete();
  });

  async function post(endpoint, user, body) {
    const response = await fetch(`${api}/${endpoint}`, {
      method: "POST", headers: {"Content-Type": "application/json",
        ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
      body: JSON.stringify(body),
    });
    return {status: response.status, body: await response.json()};
  }
  const registration = (scannerId, publicKey = keyA) => ({scannerId, publicKey, platform: "android"});
  const ref = (scannerId) => db.collection("attendance_scanner_devices").doc(scannerId);

  it("concurrent same-key registrations create one consistent pending identity", async () => {
    const scannerId = id("same-key");
    const results = await Promise.all(Array.from({length: 3}, () =>
      post("attendanceRegisterScannerDevice", operator, registration(scannerId))));
    assert.ok(results.every((r) => r.status === 200 && r.body.status === "pending"));
    const saved = (await ref(scannerId).get()).data();
    assert.equal(saved.publicKey, keyA);
    assert.equal(saved.assignedUserId, operator.uid);
  });

  it("concurrent different keys have one winner and one conflict", async () => {
    const scannerId = id("different-keys");
    const results = await Promise.all([keyA, keyB].map((key) =>
      post("attendanceRegisterScannerDevice", operator, registration(scannerId, key))));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
    assert.equal(results.find((r) => r.status === 409).body.code, "scanner-key-mismatch");
    assert.equal((await ref(scannerId).get()).data().publicKey,
      results[0].status === 200 ? keyA : keyB);
  });

  it("approve racing with repeated register cannot downgrade active or approvals", async () => {
    const scannerId = id("approve-race");
    assert.equal((await post("attendanceRegisterScannerDevice", operator, registration(scannerId))).status, 200);
    const results = await Promise.all([
      post("attendanceRegisterScannerDevice", operator, registration(scannerId)),
      post("attendanceApproveScannerDevice", administrator, {scannerId}),
    ]);
    assert.ok(results.every((r) => r.status === 200));
    const saved = (await ref(scannerId).get()).data();
    assert.equal(saved.status, "active");
    assert.equal(saved.approvedBy, administrator.uid);
    assert.equal(saved.assignedUserId, operator.uid);
    assert.equal(saved.publicKey, keyA);
  });

  it("approve racing with an administrative revocation leaves revoked", async () => {
    const scannerId = id("revoke-race");
    await post("attendanceRegisterScannerDevice", operator, registration(scannerId));
    const [approval] = await Promise.all([
      post("attendanceApproveScannerDevice", administrator, {scannerId}),
      ref(scannerId).update({status: "revoked"}),
    ]);
    assert.ok([200, 403].includes(approval.status));
    assert.equal((await ref(scannerId).get()).data().status, "revoked");
    assert.equal((await post("attendanceApproveScannerDevice", administrator, {scannerId})).status, 403);
  });

  it("manual operator requests cannot approve or assign another UID", async () => {
    for (const [extra, code] of [
      [{approve: true}, "only-admin-can-approve-scanner"],
      [{assignedUserId: administrator.uid}, "scanner-assignment-forbidden"],
    ]) {
      const scannerId = id(code);
      const r = await post("attendanceRegisterScannerDevice", operator, {...registration(scannerId), ...extra});
      assert.equal(r.status, 403);
      assert.equal(r.body.code, code);
      assert.equal((await ref(scannerId).get()).exists, false);
    }
    for (const scannerId of [id("missing-approval"), id("known-approval")]) {
      const r = await post("attendanceApproveScannerDevice", operator, {scannerId});
      assert.equal(r.status, 403);
      assert.equal(r.body.code, "only-admin-can-approve-scanner");
    }
  });

  it("approval ignores spoofed assignment, key and approver from body", async () => {
    const scannerId = id("spoof");
    await post("attendanceRegisterScannerDevice", operator, registration(scannerId));
    const r = await post("attendanceApproveScannerDevice", administrator, {
      scannerId, assignedUserId: administrator.uid, approvedBy: "forged", publicKey: keyB,
    });
    assert.equal(r.status, 200);
    const saved = (await ref(scannerId).get()).data();
    assert.equal(saved.assignedUserId, operator.uid);
    assert.equal(saved.approvedBy, administrator.uid);
    assert.equal(saved.publicKey, keyA);
  });

  it("unauthenticated registration and approval are rejected", async () => {
    for (const endpoint of ["attendanceRegisterScannerDevice", "attendanceApproveScannerDevice"]) {
      assert.equal((await post(endpoint, null, registration(id("no-auth")))).status, 401);
    }
  });

  it("stale client admin role cannot override authoritative backend role", async () => {
    await db.collection("users").doc(administrator.uid).update({role: "OPERADOR_ASISTENCIA"});
    const r = await post("attendanceRegisterScannerDevice", administrator,
      {...registration(id("stale-role")), approve: true});
    assert.equal(r.status, 403);
    await db.collection("users").doc(administrator.uid).update({role: "ADMIN"});
  });

  it("package and sync reject missing or wrong assignment before processing", async () => {
    for (const assignedUserId of [null, administrator.uid]) {
      const scannerId = id(`binding-${assignedUserId ? "other" : "missing"}`);
      await ref(scannerId).set({scannerId, publicKey: keyA, status: "active", assignedUserId});
      for (const [endpoint, extra] of [
        ["attendancePrepareOfflineEvent", {eventId: "unused"}],
        ["attendanceSyncOfflineBatch", {receipts: [{localReceiptId: "unused"}]}],
      ]) {
        const r = await post(endpoint, operator, {scannerId, ...extra});
        assert.equal(r.status, 403);
        assert.equal(r.body.code, "scanner-not-assigned");
      }
    }
  });

  it("malformed inputs are controlled errors without creating scanner documents", async () => {
    for (const extra of [{scannerId: "a/b/c"}, {deviceLabel: "x".repeat(129)}, {platform: {}},
      {assignedUserId: {}}, {publicKey: keyA + "="}]) {
      const r = await post("attendanceRegisterScannerDevice", operator,
        {...registration(id("bad-input")), ...extra});
      assert.equal(r.status, 400);
    }
  });

  it("registration and approval enforce separate persistent per-UID quotas", async () => {
    for (const [bucket, maximum, endpoint, user] of [
      ["att-scanner-register", 30, "attendanceRegisterScannerDevice", operator],
      ["att-scanner-approve", 60, "attendanceApproveScannerDevice", administrator],
    ]) {
      const rateRef = db.collection("_systemRateLimits").doc(`${bucket}-${cryptoHelpers.hashSha256Hex(user.uid)}`);
      await rateRef.set({count: maximum, windowStart: admin.firestore.Timestamp.now()});
      const scannerId = id(`limited-${bucket}`);
      const r = await post(endpoint, user, registration(scannerId));
      assert.equal(r.status, 429);
      assert.equal(r.body.code, "rate-limited");
      assert.equal((await ref(scannerId).get()).exists, false);
    }
  });
});
