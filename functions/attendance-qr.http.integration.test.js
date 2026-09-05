/**
 * HTTP E2E Security Gate for attendanceSyncOfflineBatch.
 *
 * REQUIRES Firebase Emulator Suite (auth + firestore + functions).
 * Does NOT call syncOneReceipt() as the primary path — uses real HTTP.
 *
 * Project: demo-sindicat-attendance-qr-v2
 * Production: FORBIDDEN
 */

"use strict";

const {describe, it, before, after} = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const cryptoHelpers = require("./attendance-qr-crypto");

const PROJECT = "demo-sindicat-attendance-qr-v2";
const REGION = "us-central1";
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "";
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || "";
const FUNCTIONS_HOST = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST ||
  process.env.FUNCTIONS_EMULATOR_HOST ||
  "127.0.0.1:5001";

const TEST_SEED = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
process.env.ATTENDANCE_QR_TEST_SEED = TEST_SEED;

function emulatorsReady() {
  return Boolean(AUTH_HOST && FS_HOST);
}

function isLocalEmulatorHost(host) {
  const h = String(host || "");
  return h.includes("127.0.0.1") || h.includes("localhost");
}

function assertLocalAuthHost(authHost = AUTH_HOST) {
  if (!isLocalEmulatorHost(authHost)) {
    throw new Error(
      `Refusing non-local Auth emulator host for waitForEmulatorAuthReady: ${authHost}`,
    );
  }
}

/**
 * TEST-ONLY: poll Auth Emulator until Admin verifyIdToken accepts the token.
 * Closes the race where accounts:signUp returns an idToken before the
 * Functions emulator Admin SDK can verify it (HTTP 401 invalid-auth flake).
 *
 * Never logs tokens. Never targets production hosts.
 */
async function waitForEmulatorAuthReady({
  idToken,
  expectedUid,
  authHost = AUTH_HOST,
  verifyIdToken,
  delaysMs = [25, 50, 100, 200, 400, 800, 1600, 3200],
  maxWaitMs = 10000,
} = {}) {
  assertLocalAuthHost(authHost);
  if (typeof idToken !== "string" || !idToken.trim()) {
    throw new Error("AUTH_EMULATOR_NOT_READY: missing idToken");
  }
  if (typeof expectedUid !== "string" || !expectedUid.trim()) {
    throw new Error("AUTH_EMULATOR_NOT_READY: missing expectedUid");
  }

  const verify =
    verifyIdToken ||
    (async (token) => admin.auth().verifyIdToken(token));

  const started = Date.now();
  let lastError = null;
  for (let i = 0; i < delaysMs.length; i++) {
    if (Date.now() - started > maxWaitMs) break;
    try {
      const decoded = await verify(idToken);
      if (decoded && decoded.uid === expectedUid) {
        return decoded;
      }
      lastError = new Error(
        `AUTH_EMULATOR_NOT_READY: uid mismatch (expected bound uid)`,
      );
      // Wrong UID is definitive — do not keep polling forever.
      throw lastError;
    } catch (err) {
      if (
        err &&
        typeof err.message === "string" &&
        err.message.includes("uid mismatch")
      ) {
        throw err;
      }
      lastError = err;
      const delay = delaysMs[i];
      if (Date.now() - started + delay > maxWaitMs) break;
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  const detail =
    lastError && lastError.message ? String(lastError.message) : "unknown";
  // Never include token material in the error.
  throw new Error(`AUTH_EMULATOR_NOT_READY: ${detail}`);
}

/**
 * TEST-ONLY: ensure the Functions emulator Admin SDK can verify the token.
 * Admin verifyIdToken in the test process can succeed slightly before the
 * Functions runtime accepts the same Bearer token (cross-process Auth lag).
 */
async function waitForFunctionsAuthReady({
  idToken,
  authHost = AUTH_HOST,
  httpPost = httpSync,
  delaysMs = [25, 50, 100, 200, 400, 800, 1600, 3200],
  maxWaitMs = 10000,
} = {}) {
  assertLocalAuthHost(authHost);
  if (typeof idToken !== "string" || !idToken.trim()) {
    throw new Error("AUTH_EMULATOR_NOT_READY: missing idToken");
  }
  const started = Date.now();
  let lastStatus = null;
  let lastCode = null;
  for (let i = 0; i < delaysMs.length; i++) {
    if (Date.now() - started > maxWaitMs) break;
    const res = await httpPost({
      idToken,
      scannerId: "auth-ready-probe",
      receipts: [],
    });
    lastStatus = res.status;
    lastCode = res.body && res.body.code;
    // Auth accepted: endpoint validates payload (400 empty-batch) or other
    // non-auth business errors — never treat unexpected 401 as success.
    if (res.status !== 401) {
      return res;
    }
    const delay = delaysMs[i];
    if (Date.now() - started + delay > maxWaitMs) break;
    await new Promise((r) => setTimeout(r, delay));
  }
  throw new Error(
    `AUTH_EMULATOR_NOT_READY: functions still rejecting auth ` +
      `(lastStatus=${lastStatus} lastCode=${lastCode || "n/a"})`,
  );
}

async function stabilizeEmulatorAuthSession({idToken, expectedUid}) {
  await waitForEmulatorAuthReady({idToken, expectedUid});
  await waitForFunctionsAuthReady({idToken});
}

function syncUrl() {
  // Cloud Functions emulator HTTP shape
  const host = FUNCTIONS_HOST.includes("://")
    ? FUNCTIONS_HOST
    : `http://${FUNCTIONS_HOST}`;
  return `${host}/${PROJECT}/${REGION}/attendanceSyncOfflineBatch`;
}

async function authSignUp(email, password) {
  const url =
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(`authSignUp failed: ${res.status} ${JSON.stringify(body)}`);
  }
  return {uid: body.localId, idToken: body.idToken};
}

async function httpSync({idToken, scannerId, receipts}) {
  const headers = {"Content-Type": "application/json"};
  if (idToken !== undefined) {
    headers.Authorization = `Bearer ${idToken}`;
  }
  const res = await fetch(syncUrl(), {
    method: "POST",
    headers,
    body: JSON.stringify({scannerId, receipts}),
  });
  let body;
  try {
    body = await res.json();
  } catch (_) {
    body = {raw: await res.text()};
  }
  return {status: res.status, body};
}

function buildSignedReceipt({
  eventId,
  memberId,
  deviceId,
  scannerId,
  memberKp,
  scannerKp,
  localReceiptId,
  responseNonce,
  challengeId,
  challengeNonce,
}) {
  const scannedAtTrusted = Date.now();
  const scannedAtDevice = scannedAtTrusted;
  const responseFields = {
    v: "2",
    type: "SATT2R",
    eventId,
    scannerId,
    challengeId,
    challengeNonce,
    memberDeviceId: deviceId,
    credentialId: "cred-http-1",
    responseNonce,
    issuedAt: String(scannedAtDevice),
    protocolVersion: "2",
  };
  const memberSignature = cryptoHelpers.signUtf8(
    cryptoHelpers.canonicalResponsePayload(responseFields),
    memberKp.privateKey,
  );

  const receiptFields = {
    v: "2",
    type: "SATT2RCPT",
    localReceiptId,
    eventId,
    memberId,
    memberDeviceId: deviceId,
    scannerId,
    challengeId,
    challengeNonce,
    responseNonce,
    memberSignature,
    packageId: "pkg-http-1",
    scannedAtTrusted: String(scannedAtTrusted),
    scannedAtDevice: String(scannedAtDevice),
    locationStatus: "ok",
  };
  const scannerSignature = cryptoHelpers.signUtf8(
    cryptoHelpers.canonicalReceiptPayload(receiptFields),
    scannerKp.privateKey,
  );

  return {
    localReceiptId,
    eventId,
    memberId,
    memberDeviceId: deviceId,
    scannerId,
    challengeId,
    challengeNonce,
    responseNonce,
    memberSignature,
    scannerSignature,
    packageId: "pkg-http-1",
    scannedAtTrusted,
    scannedAtDevice,
    responseIssuedAt: scannedAtDevice,
    credentialId: "cred-http-1",
    locationStatus: "ok",
  };
}

describe("HTTP E2E attendanceSyncOfflineBatch (Auth+Firestore+Functions Emulator)", () => {
  let db;
  let operatorToken;
  let voterToken;
  let operatorUid;
  let voterUid;
  let memberKp;
  let scannerAKp;
  let scannerBKp;

  const memberId = "http-member-1";
  const deviceId = "http-device-1";
  const eventId = "http-event-1";
  const scannerA = "http-scanner-a";
  const scannerB = "http-scanner-b";

  before(async () => {
    if (!emulatorsReady()) {
      console.warn(
        "SKIP HTTP E2E: FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST missing",
      );
      return;
    }

    // Hard guard: refuse if pointing at production hosts.
    if (!isLocalEmulatorHost(AUTH_HOST)) {
      throw new Error(`Refusing non-local Auth emulator host: ${AUTH_HOST}`);
    }
    if (!isLocalEmulatorHost(FS_HOST)) {
      throw new Error(`Refusing non-local Firestore emulator host: ${FS_HOST}`);
    }

    process.env.GCLOUD_PROJECT = PROJECT;
    process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
    if (!admin.apps.length) {
      admin.initializeApp({projectId: PROJECT});
    }
    db = admin.firestore();

    memberKp = cryptoHelpers.generateEd25519KeyPair();
    scannerAKp = cryptoHelpers.generateEd25519KeyPair();
    scannerBKp = cryptoHelpers.generateEd25519KeyPair();

    const op = await authSignUp(
      `operator-${Date.now()}@test.emulator`,
      "Password123!",
    );
    operatorUid = op.uid;
    operatorToken = op.idToken;

    const voter = await authSignUp(
      `voter-${Date.now()}@test.emulator`,
      "Password123!",
    );
    voterUid = voter.uid;
    voterToken = voter.idToken;

    // Fail-fast: Auth Emulator + Functions must accept tokens before HTTP cases.
    await stabilizeEmulatorAuthSession({
      idToken: operatorToken,
      expectedUid: operatorUid,
    });
    await stabilizeEmulatorAuthSession({
      idToken: voterToken,
      expectedUid: voterUid,
    });

    await db.collection("users").doc(operatorUid).set({
      email: "operator@test.emulator",
      role: "OPERADOR_ASISTENCIA",
      isActive: true,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
    await db.collection("users").doc(voterUid).set({
      email: "voter@test.emulator",
      role: "VOTER",
      isActive: true,
      memberId,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await db.collection("members").doc(memberId).set({
      status: "active",
      fullName: "HTTP Socio Test",
      memberNumber: "9001",
      workerCode: "W-HTTP-1",
    });
    await db.collection("attendance_member_devices").doc(deviceId).set({
      deviceId,
      uid: voterUid,
      memberId,
      publicKey: memberKp.publicKeyBase64Url,
      status: "active",
      lastCredentialId: "cred-http-1",
      algorithm: "Ed25519",
    });
    await db.collection("attendance_scanner_devices").doc(scannerA).set({
      scannerId: scannerA,
      publicKey: scannerAKp.publicKeyBase64Url,
      status: "active",
      assignedUserId: operatorUid,
      approvedBy: "admin-test",
      algorithm: "Ed25519",
    });
    await db.collection("attendance_scanner_devices").doc(scannerB).set({
      scannerId: scannerB,
      publicKey: scannerBKp.publicKeyBase64Url,
      status: "active",
      assignedUserId: operatorUid,
      approvedBy: "admin-test",
      algorithm: "Ed25519",
    });
    await db.collection("attendance_events").doc(eventId).set({
      nombre: "HTTP E2E Asamblea",
      fecha: Date.now(),
      activo: true,
      creadoPor: operatorUid,
      asistenciaCount: 0,
    });

    // Smoke: Functions emulator must be reachable.
    const probe = await fetch(syncUrl(), {method: "OPTIONS"}).catch((e) => e);
    if (probe instanceof Error) {
      throw new Error(
        `Functions emulator unreachable at ${syncUrl()}: ${probe.message}`,
      );
    }
  });

  after(async () => {
    // Emulator data is ephemeral; no production cleanup needed.
  });

  it("CASO A: same receipt twice via HTTP → synced then already_synced; 1 doc", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }

    const receipt = buildSignedReceipt({
      eventId,
      memberId,
      deviceId,
      scannerId: scannerA,
      memberKp,
      scannerKp: scannerAKp,
      localReceiptId: "http-r1",
      responseNonce: "http-rn-1",
      challengeId: "http-ch-1",
      challengeNonce: "http-cn-1",
    });

    const first = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts: [receipt],
    });
    assert.equal(first.status, 200, JSON.stringify(first.body));
    assert.equal(first.body.ok, true);
    assert.equal(first.body.results[0].status, "synced");

    const second = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts: [receipt],
    });
    assert.equal(second.status, 200, JSON.stringify(second.body));
    assert.equal(second.body.results[0].status, "already_synced");
    assert.equal(second.body.results[0].code, "duplicate");

    const snap = await db
      .collection("attendance_events")
      .doc(eventId)
      .collection("asistencias")
      .where("personaId", "==", memberId)
      .get();
    assert.equal(snap.size, 1);
    assert.equal(snap.docs[0].data().metodoRegistro, "SECURE_QR_V2");
  });

  it("CASO B: two scanners same member/event via HTTP → one canonical", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }

    const eventB = "http-event-2";
    await db.collection("attendance_events").doc(eventB).set({
      nombre: "HTTP E2E Dual Scanner",
      fecha: Date.now(),
      activo: true,
      asistenciaCount: 0,
    });

    const receiptA = buildSignedReceipt({
      eventId: eventB,
      memberId,
      deviceId,
      scannerId: scannerA,
      memberKp,
      scannerKp: scannerAKp,
      localReceiptId: "http-ra",
      responseNonce: "http-rn-a",
      challengeId: "http-ch-a",
      challengeNonce: "http-cn-a",
    });
    const receiptB = buildSignedReceipt({
      eventId: eventB,
      memberId,
      deviceId,
      scannerId: scannerB,
      memberKp,
      scannerKp: scannerBKp,
      localReceiptId: "http-rb",
      responseNonce: "http-rn-b",
      challengeId: "http-ch-b",
      challengeNonce: "http-cn-b",
    });

    const a = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts: [receiptA],
    });
    assert.equal(a.status, 200, JSON.stringify(a.body));
    assert.equal(a.body.results[0].status, "synced");

    const b = await httpSync({
      idToken: operatorToken,
      scannerId: scannerB,
      receipts: [receiptB],
    });
    assert.equal(b.status, 200, JSON.stringify(b.body));
    assert.ok(
      ["already_synced", "duplicate", "review"].includes(b.body.results[0].status) ||
        ["duplicate", "already_synced", "review"].includes(b.body.results[0].code),
      JSON.stringify(b.body),
    );
    // Contract: status already_synced with code duplicate
    assert.equal(b.body.results[0].status, "already_synced");

    const snap = await db
      .collection("attendance_events")
      .doc(eventB)
      .collection("asistencias")
      .where("personaId", "==", memberId)
      .get();
    assert.equal(snap.size, 1);
  });

  it("AUTH: missing Authorization → 401", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const res = await httpSync({
      idToken: undefined,
      scannerId: scannerA,
      receipts: [{localReceiptId: "x"}],
    });
    // fetch without Authorization header
    const raw = await fetch(syncUrl(), {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({scannerId: scannerA, receipts: [{localReceiptId: "x"}]}),
    });
    assert.equal(raw.status, 401);
    const body = await raw.json();
    assert.equal(body.ok, false);
    assert.equal(body.code, "missing-auth");
  });

  it("AUTH: invalid token → 401", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const res = await httpSync({
      idToken: "not-a-valid-emulator-token",
      scannerId: scannerA,
      receipts: [{localReceiptId: "x"}],
    });
    assert.equal(res.status, 401);
    assert.equal(res.body.ok, false);
  });

  it("AUTH: VOTER → 403", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const receipt = buildSignedReceipt({
      eventId,
      memberId,
      deviceId,
      scannerId: scannerA,
      memberKp,
      scannerKp: scannerAKp,
      localReceiptId: "http-voter",
      responseNonce: "http-rn-voter",
      challengeId: "http-ch-voter",
      challengeNonce: "http-cn-voter",
    });
    const res = await httpSync({
      idToken: voterToken,
      scannerId: scannerA,
      receipts: [receipt],
    });
    assert.equal(res.status, 403);
    assert.equal(res.body.code, "forbidden");
  });

  it("REVOKED scanner → rejected; no new canonical for that receipt", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const eventR = "http-event-revoked";
    await db.collection("attendance_events").doc(eventR).set({
      nombre: "revoked test",
      fecha: Date.now(),
      activo: true,
      asistenciaCount: 0,
    });
    const scannerR = "http-scanner-revoked";
    const scannerRKp = cryptoHelpers.generateEd25519KeyPair();
    await db.collection("attendance_scanner_devices").doc(scannerR).set({
      scannerId: scannerR,
      publicKey: scannerRKp.publicKeyBase64Url,
      status: "revoked",
      assignedUserId: operatorUid,
    });

    const receipt = buildSignedReceipt({
      eventId: eventR,
      memberId,
      deviceId,
      scannerId: scannerR,
      memberKp,
      scannerKp: scannerRKp,
      localReceiptId: "http-revoked",
      responseNonce: "http-rn-rev",
      challengeId: "http-ch-rev",
      challengeNonce: "http-cn-rev",
    });

    const res = await httpSync({
      idToken: operatorToken,
      scannerId: scannerR,
      receipts: [receipt],
    });
    assert.equal(res.status, 403);
    assert.equal(res.body.code, "scanner-revoked");

    const snap = await db
      .collection("attendance_events")
      .doc(eventR)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 0);
  });

  it("MEMBER inactive at sync → review; no canonical write", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const eventI = "http-event-inactive";
    const memberI = "http-member-inactive";
    const deviceI = "http-device-inactive";
    await db.collection("members").doc(memberI).set({
      status: "inactive",
      fullName: "Inactive",
    });
    await db.collection("attendance_member_devices").doc(deviceI).set({
      deviceId: deviceI,
      uid: "uid-inactive",
      memberId: memberI,
      publicKey: memberKp.publicKeyBase64Url,
      status: "active",
      lastCredentialId: "cred-http-1",
    });
    await db.collection("attendance_events").doc(eventI).set({
      nombre: "inactive sync",
      fecha: Date.now(),
      activo: true,
      asistenciaCount: 0,
    });

    const receipt = buildSignedReceipt({
      eventId: eventI,
      memberId: memberI,
      deviceId: deviceI,
      scannerId: scannerA,
      memberKp,
      scannerKp: scannerAKp,
      localReceiptId: "http-inactive",
      responseNonce: "http-rn-inact",
      challengeId: "http-ch-inact",
      challengeNonce: "http-cn-inact",
    });

    const res = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts: [receipt],
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.results[0].status, "review");
    assert.equal(res.body.results[0].code, "member-inactive-at-sync");

    const snap = await db
      .collection("attendance_events")
      .doc(eventI)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 0);
  });

  it("MALFORMED: empty batch → 400 (not 500)", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const res = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts: [],
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.code, "empty-batch");
    assert.notEqual(res.status, 500);
  });

  it("MALFORMED: missing scannerId → 400", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const res = await fetch(syncUrl(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${operatorToken}`,
      },
      body: JSON.stringify({receipts: [{localReceiptId: "x"}]}),
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.code, "missing-scannerId");
  });

  it("MALFORMED: batch too large → 400", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const receipts = Array.from({length: 51}, (_, i) => ({
      localReceiptId: `big-${i}`,
    }));
    const res = await httpSync({
      idToken: operatorToken,
      scannerId: scannerA,
      receipts,
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.code, "batch-too-large");
  });
});

describe("HTTP E2E attendancePrepareOfflineEvent scale (>500 devices)", () => {
  let db;
  let operatorToken;
  let operatorUid;

  function prepareUrl() {
    const host = FUNCTIONS_HOST.includes("://")
      ? FUNCTIONS_HOST
      : `http://${FUNCTIONS_HOST}`;
    return `${host}/${PROJECT}/${REGION}/attendancePrepareOfflineEvent`;
  }

  async function wipeScaleCollections() {
    for (const col of [
      "attendance_member_devices",
      "members",
      "attendance_scanner_devices",
      "attendance_events",
    ]) {
      const snap = await db.collection(col).get();
      const docs = snap.docs;
      for (let i = 0; i < docs.length; i += 400) {
        const batch = db.batch();
        docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
    }
  }

  async function seedScaleDevices({memberCount, devicesPerMember, memberIdPrefix = "http-scale-m"}) {
    const kp = cryptoHelpers.generateEd25519KeyPair();
    const bulkWriter = db.bulkWriter();
    for (let m = 0; m < memberCount; m++) {
      const memberId = `${memberIdPrefix}-${m}`;
      bulkWriter.set(db.collection("members").doc(memberId), {
        fullName: `Scale ${m}`,
        status: "activo",
        memberNumber: String(m),
        workerCode: `W${m}`,
      });
      for (let d = 0; d < devicesPerMember; d++) {
        const deviceId = `${memberId}-d${d}`;
        bulkWriter.set(db.collection("attendance_member_devices").doc(deviceId), {
          deviceId,
          memberId,
          publicKey: kp.publicKeyBase64Url,
          status: "active",
          lastCredentialId: `cred-${m}-${d}`,
        });
      }
    }
    await bulkWriter.close();
    return kp;
  }

  async function seedScannerAndEvent(scannerId, eventId) {
    const scannerKp = cryptoHelpers.generateEd25519KeyPair();
    await db.collection("attendance_scanner_devices").doc(scannerId).set({
      scannerId,
      publicKey: scannerKp.publicKeyBase64Url,
      status: "active",
      assignedUserId: operatorUid,
    });
    await db.collection("attendance_events").doc(eventId).set({
      nombre: "HTTP Scale Package",
      fecha: Date.now(),
      fechaFin: Date.now() + 3_600_000,
      activo: true,
      asistenciaCount: 0,
    });
  }

  before(async () => {
    if (!emulatorsReady()) {
      console.warn("SKIP HTTP prepare scale: emulators not ready");
      return;
    }
    process.env.GCLOUD_PROJECT = PROJECT;
    process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
    process.env.FUNCTIONS_EMULATOR = "true";
    process.env.ATTENDANCE_QR_SKIP_APPCHECK = "1";
    if (!admin.apps.length) {
      admin.initializeApp({projectId: PROJECT});
    }
    db = admin.firestore();
    const op = await authSignUp(
      `pkg-op-${Date.now()}@test.emulator`,
      "Password123!",
    );
    operatorUid = op.uid;
    operatorToken = op.idToken;
    await stabilizeEmulatorAuthSession({
      idToken: operatorToken,
      expectedUid: operatorUid,
    });
    await db.collection("users").doc(operatorUid).set({
      role: "OPERADOR_ASISTENCIA",
      isActive: true,
      email: "pkg-op@test.emulator",
    });
  });

  it("600 active devices → package.participants.length === 600", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }

    await wipeScaleCollections();
    const scannerId = "http-pkg-scanner-600";
    const eventId = "http-pkg-event-600";
    await seedScaleDevices({memberCount: 300, devicesPerMember: 2});
    await seedScannerAndEvent(scannerId, eventId);

    const t0 = Date.now();
    const res = await fetch(prepareUrl(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${operatorToken}`,
      },
      body: JSON.stringify({eventId, scannerId}),
    });
    const body = await res.json();
    const ms = Date.now() - t0;
    console.log(`PERF HTTP prepareOfflineEvent 600 devices: ${ms}ms status=${res.status}`);

    assert.equal(res.status, 200, JSON.stringify(body));
    assert.equal(body.ok, true);
    assert.equal(body.package.participants.length, 600);
    assert.ok(body.package.participantsHash);
    assert.ok(body.package.signature);
  });

  it("5000 active devices → package.participants.length === 5000", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }

    await wipeScaleCollections();
    const scannerId = "http-pkg-scanner-5k";
    const eventId = "http-pkg-event-5k";
    const seedT0 = Date.now();
    await seedScaleDevices({memberCount: 2500, devicesPerMember: 2});
    console.log(`PERF HTTP seed 5000 devices: ${Date.now() - seedT0}ms`);
    await seedScannerAndEvent(scannerId, eventId);

    const t0 = Date.now();
    const res = await fetch(prepareUrl(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${operatorToken}`,
      },
      body: JSON.stringify({eventId, scannerId}),
    });
    const body = await res.json();
    const ms = Date.now() - t0;
    console.log(`PERF HTTP prepareOfflineEvent 5000 devices: ${ms}ms status=${res.status}`);

    assert.equal(res.status, 200, JSON.stringify(body));
    assert.equal(body.ok, true);
    assert.equal(body.package.participants.length, 5000);
    assert.equal(
      new Set(body.package.participants.map((p) => p.memberDeviceId)).size,
      5000,
    );
    assert.ok(body.package.participantsHash);
    assert.ok(body.package.signature);
    const pkgBytes = Buffer.byteLength(JSON.stringify(body.package), "utf8");
    console.log(`PACKAGE_SIZE HTTP 5000 full: ${pkgBytes} bytes (${(pkgBytes / 1024 / 1024).toFixed(3)} MB)`);
  });

  it("MAX+1 active devices → HTTP 413 offline-package-too-large", async (t) => {
    if (!emulatorsReady()) {
      t.skip("emulators not ready");
      return;
    }
    const {MAX_OFFLINE_PACKAGE_DEVICES} = require("./attendance-qr")._test;
    const over = MAX_OFFLINE_PACKAGE_DEVICES + 1;

    await wipeScaleCollections();
    const scannerId = "http-pkg-scanner-over";
    const eventId = "http-pkg-event-over";
    await seedScaleDevices({
      memberCount: over,
      devicesPerMember: 1,
      memberIdPrefix: "http-over-m",
    });
    await seedScannerAndEvent(scannerId, eventId);

    const res = await fetch(prepareUrl(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${operatorToken}`,
      },
      body: JSON.stringify({eventId, scannerId}),
    });
    const body = await res.json();

    assert.equal(res.status, 413, JSON.stringify(body));
    assert.equal(body.ok, false);
    assert.equal(body.code, "offline-package-too-large");
    assert.equal(body.participantDeviceCount, over);
    assert.equal(body.package, undefined);
  });
});

describe("waitForEmulatorAuthReady (test-only helper)", () => {
  it("refuses non-local Auth host", async () => {
    await assert.rejects(
      () =>
        waitForEmulatorAuthReady({
          idToken: "tok",
          expectedUid: "uid",
          authHost: "securetoken.googleapis.com",
          delaysMs: [1],
          maxWaitMs: 100,
          verifyIdToken: async () => ({uid: "uid"}),
        }),
      /Refusing non-local Auth emulator host/,
    );
  });

  it("valid token + correct uid → PASS", async () => {
    const decoded = await waitForEmulatorAuthReady({
      idToken: "tok-ok",
      expectedUid: "uid-1",
      authHost: "127.0.0.1:9099",
      delaysMs: [1],
      maxWaitMs: 1000,
      verifyIdToken: async () => ({uid: "uid-1"}),
    });
    assert.equal(decoded.uid, "uid-1");
  });

  it("valid token + wrong uid → FAIL", async () => {
    await assert.rejects(
      () =>
        waitForEmulatorAuthReady({
          idToken: "tok-ok",
          expectedUid: "uid-expected",
          authHost: "localhost:9099",
          delaysMs: [1],
          maxWaitMs: 1000,
          verifyIdToken: async () => ({uid: "uid-other"}),
        }),
      /AUTH_EMULATOR_NOT_READY: uid mismatch/,
    );
  });

  it("invalid token → controlled FAIL (timeout path)", async () => {
    await assert.rejects(
      () =>
        waitForEmulatorAuthReady({
          idToken: "not-a-jwt",
          expectedUid: "uid-1",
          authHost: "127.0.0.1:9099",
          delaysMs: [5, 5],
          maxWaitMs: 50,
          verifyIdToken: async () => {
            throw new Error("Decoding Firebase ID token failed");
          },
        }),
      /AUTH_EMULATOR_NOT_READY/,
    );
  });

  it("timeout → AUTH_EMULATOR_NOT_READY", async () => {
    let calls = 0;
    await assert.rejects(
      () =>
        waitForEmulatorAuthReady({
          idToken: "tok-slow",
          expectedUid: "uid-1",
          authHost: "127.0.0.1:9099",
          delaysMs: [10, 10, 10, 10],
          maxWaitMs: 25,
          verifyIdToken: async () => {
            calls += 1;
            throw new Error("auth/id-token-expired");
          },
        }),
      /AUTH_EMULATOR_NOT_READY/,
    );
    assert.ok(calls >= 1);
  });

  it("functions probe refuses persistent 401", async () => {
    await assert.rejects(
      () =>
        waitForFunctionsAuthReady({
          idToken: "tok",
          authHost: "127.0.0.1:9099",
          delaysMs: [5, 5],
          maxWaitMs: 40,
          httpPost: async () => ({status: 401, body: {code: "invalid-auth"}}),
        }),
      /AUTH_EMULATOR_NOT_READY: functions still rejecting auth/,
    );
  });

  it("functions probe accepts non-401 business response", async () => {
    const res = await waitForFunctionsAuthReady({
      idToken: "tok",
      authHost: "localhost:9099",
      delaysMs: [1],
      maxWaitMs: 1000,
      httpPost: async () => ({status: 400, body: {code: "empty-batch"}}),
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.code, "empty-batch");
  });
});
