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
    if (!AUTH_HOST.includes("127.0.0.1") && !AUTH_HOST.includes("localhost")) {
      throw new Error(`Refusing non-local Auth emulator host: ${AUTH_HOST}`);
    }
    if (!FS_HOST.includes("127.0.0.1") && !FS_HOST.includes("localhost")) {
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
