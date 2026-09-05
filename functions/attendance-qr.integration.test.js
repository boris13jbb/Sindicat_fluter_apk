/**
 * Integration tests for Secure Attendance sync idempotency.
 * Requires Firestore emulator (firebase emulators:exec --only firestore).
 *
 * Does NOT touch production. Uses ATTENDANCE_QR_TEST_SEED only.
 */

const {describe, it, before, after, beforeEach} = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const cryptoHelpers = require("./attendance-qr-crypto");

process.env.ATTENDANCE_QR_TEST_SEED =
  process.env.ATTENDANCE_QR_TEST_SEED ||
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

const projectId = "satt2-sync-integration";
const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

function skipIfNoEmulator() {
  if (!hasEmulator) {
    // Soft-skip: parent harness must set FIRESTORE_EMULATOR_HOST.
    return true;
  }
  return false;
}

describe("attendanceSyncOfflineBatch idempotency (emulator)", () => {
  let db;
  let syncOneReceipt;
  let attendanceDocId;
  let METODO_SECURE;

  before(() => {
    if (skipIfNoEmulator()) return;
    process.env.GCLOUD_PROJECT = projectId;
    process.env.GOOGLE_CLOUD_PROJECT = projectId;
    if (!admin.apps.length) {
      admin.initializeApp({projectId});
    }
    db = admin.firestore();
    // Lazy-load module after env so getFirestore binds to emulator.
    const mod = require("./attendance-qr");
    syncOneReceipt = mod._test.syncOneReceipt;
    attendanceDocId = mod._test.attendanceDocId;
    METODO_SECURE = mod._test.METODO_SECURE;
  });

  beforeEach(async () => {
    if (skipIfNoEmulator()) return;
    // Clear nested asistencias then top-level fixtures.
    const events = await db.collection("attendance_events").get();
    for (const ev of events.docs) {
      const asist = await ev.ref.collection("asistencias").get();
      const batch = db.batch();
      asist.docs.forEach((d) => batch.delete(d.ref));
      batch.delete(ev.ref);
      await batch.commit();
    }
    for (const col of [
      "attendance_scanner_devices",
      "attendance_member_devices",
      "members",
    ]) {
      const snap = await db.collection(col).get();
      if (snap.empty) continue;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  });

  after(async () => {
    // Keep app for other suites in same process.
  });

  async function seedActiveFixture({
    scannerId = "scanner-a",
    memberId = "member-1",
    deviceId = "device-1",
    eventId = "event-1",
  } = {}) {
    const memberKp = cryptoHelpers.generateEd25519KeyPair();
    const scannerKp = cryptoHelpers.generateEd25519KeyPair();

    await db.collection("members").doc(memberId).set({
      status: "active",
      fullName: "Socio Test",
      memberNumber: "10",
    });
    await db.collection("attendance_member_devices").doc(deviceId).set({
      deviceId,
      uid: "uid-member",
      memberId,
      publicKey: memberKp.publicKeyBase64Url,
      status: "active",
      lastCredentialId: "cred-1",
    });
    await db.collection("attendance_scanner_devices").doc(scannerId).set({
      scannerId,
      publicKey: scannerKp.publicKeyBase64Url,
      status: "active",
      assignedUserId: "operator-1",
    });
    await db.collection("attendance_events").doc(eventId).set({
      nombre: "Asamblea",
      fecha: Date.now(),
      activo: true,
      asistenciaCount: 0,
    });

    return {memberKp, scannerKp, scannerId, memberId, deviceId, eventId};
  }

  function buildSignedReceipt({
    fixture,
    scannerKp,
    memberKp,
    localReceiptId,
    responseNonce,
    challengeId = "ch-1",
    challengeNonce = "cn-1",
    packageId = "pkg-1",
  }) {
    const scannedAtTrusted = Date.now();
    const scannedAtDevice = scannedAtTrusted;
    const responseFields = {
      v: "2",
      type: "SATT2R",
      eventId: fixture.eventId,
      scannerId: fixture.scannerId,
      challengeId,
      challengeNonce,
      memberDeviceId: fixture.deviceId,
      credentialId: "cred-1",
      responseNonce,
      issuedAt: String(scannedAtDevice),
      protocolVersion: "2",
    };
    const responseCanonical =
      cryptoHelpers.canonicalResponsePayload(responseFields);
    const memberSignature = cryptoHelpers.signUtf8(
      responseCanonical,
      memberKp.privateKey,
    );

    const receiptFields = {
      v: "2",
      type: "SATT2RCPT",
      localReceiptId,
      eventId: fixture.eventId,
      memberId: fixture.memberId,
      memberDeviceId: fixture.deviceId,
      scannerId: fixture.scannerId,
      challengeId,
      challengeNonce,
      responseNonce,
      memberSignature,
      packageId,
      scannedAtTrusted: String(scannedAtTrusted),
      scannedAtDevice: String(scannedAtDevice),
      locationStatus: "ok",
    };
    const receiptCanonical =
      cryptoHelpers.canonicalReceiptPayload(receiptFields);
    const scannerSignature = cryptoHelpers.signUtf8(
      receiptCanonical,
      scannerKp.privateKey,
    );

    return {
      localReceiptId,
      eventId: fixture.eventId,
      memberId: fixture.memberId,
      memberDeviceId: fixture.deviceId,
      scannerId: fixture.scannerId,
      challengeId,
      challengeNonce,
      responseNonce,
      memberSignature,
      scannerSignature,
      packageId,
      scannedAtTrusted,
      scannedAtDevice,
      responseIssuedAt: scannedAtDevice,
      credentialId: "cred-1",
      locationStatus: "ok",
    };
  }

  it("CASO A: same receipt twice → one canonical + already_synced", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }

    const {memberKp, scannerKp, ...ids} = await seedActiveFixture();
    const fixture = {memberKp, scannerKp, ...ids};
    const receipt = buildSignedReceipt({
      fixture,
      scannerKp,
      memberKp,
      localReceiptId: "r1",
      responseNonce: "rn-1",
    });

    const first = await syncOneReceipt({
      raw: receipt,
      scannerId: fixture.scannerId,
      scannerPub: scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(first.status, "synced");

    const afterFirst = await db.collection("attendance_events").doc(fixture.eventId).get();
    assert.equal(afterFirst.data().asistenciaCount, 1);

    const second = await syncOneReceipt({
      raw: receipt,
      scannerId: fixture.scannerId,
      scannerPub: scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(second.status, "already_synced");
    assert.equal(second.code, "duplicate");

    const afterSecond = await db.collection("attendance_events").doc(fixture.eventId).get();
    assert.equal(afterSecond.data().asistenciaCount, 1, "retry must not double-increment");

    const docId = attendanceDocId(fixture.eventId, fixture.memberId);
    const snap = await db
      .collection("attendance_events")
      .doc(fixture.eventId)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 1);
    assert.equal(snap.docs[0].id, docId);
    assert.equal(snap.docs[0].data().metodoRegistro, METODO_SECURE);
  });

  it("CASO B: two scanners same event/member → one canonical", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }

    const base = await seedActiveFixture({scannerId: "scanner-a"});
    const scannerB = cryptoHelpers.generateEd25519KeyPair();
    await db.collection("attendance_scanner_devices").doc("scanner-b").set({
      scannerId: "scanner-b",
      publicKey: scannerB.publicKeyBase64Url,
      status: "active",
      assignedUserId: "operator-2",
    });

    const receiptA = buildSignedReceipt({
      fixture: base,
      scannerKp: base.scannerKp,
      memberKp: base.memberKp,
      localReceiptId: "ra",
      responseNonce: "rn-a",
      challengeId: "ch-a",
    });

    const fixtureB = {...base, scannerId: "scanner-b"};
    const receiptB = buildSignedReceipt({
      fixture: fixtureB,
      scannerKp: scannerB,
      memberKp: base.memberKp,
      localReceiptId: "rb",
      responseNonce: "rn-b",
      challengeId: "ch-b",
    });

    const first = await syncOneReceipt({
      raw: receiptA,
      scannerId: "scanner-a",
      scannerPub: base.scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(first.status, "synced");

    const second = await syncOneReceipt({
      raw: receiptB,
      scannerId: "scanner-b",
      scannerPub: scannerB.publicKeyBase64Url,
      operatorUid: "operator-2",
    });
    assert.equal(second.status, "already_synced");
    assert.equal(second.code, "duplicate");

    const snap = await db
      .collection("attendance_events")
      .doc(base.eventId)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 1);
  });

  it("inactive member at sync → review (no canonical write)", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }

    const {memberKp, scannerKp, ...ids} = await seedActiveFixture();
    await db.collection("members").doc(ids.memberId).set({status: "inactive"});
    const fixture = {memberKp, scannerKp, ...ids};
    const receipt = buildSignedReceipt({
      fixture,
      scannerKp,
      memberKp,
      localReceiptId: "r-inactive",
      responseNonce: "rn-inactive",
    });

    const result = await syncOneReceipt({
      raw: receipt,
      scannerId: fixture.scannerId,
      scannerPub: scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(result.status, "review");
    assert.equal(result.code, "member-inactive-at-sync");

    const snap = await db
      .collection("attendance_events")
      .doc(fixture.eventId)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 0);
  });

  it("legacy missing asistenciaCount → rejected; count unchanged; no write", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }

    const {memberKp, scannerKp, ...ids} = await seedActiveFixture({
      eventId: "event-legacy-count",
    });
    await db.collection("attendance_events").doc(ids.eventId).set({
      nombre: "Legacy",
      fecha: Date.now(),
      activo: true,
    }, {merge: false});

    const fixture = {memberKp, scannerKp, ...ids};
    const receipt = buildSignedReceipt({
      fixture,
      scannerKp,
      memberKp,
      localReceiptId: "r-legacy",
      responseNonce: "rn-legacy",
    });

    const result = await syncOneReceipt({
      raw: receipt,
      scannerId: fixture.scannerId,
      scannerPub: scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(result.status, "rejected");
    assert.equal(result.code, "legacy-count-missing");

    const eventSnap = await db.collection("attendance_events").doc(ids.eventId).get();
    assert.equal(eventSnap.data().asistenciaCount, undefined);

    const snap = await db
      .collection("attendance_events")
      .doc(ids.eventId)
      .collection("asistencias")
      .get();
    assert.equal(snap.size, 0);
  });

  it("invalid scanner signature → count unchanged", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }

    const {memberKp, scannerKp, ...ids} = await seedActiveFixture({
      eventId: "event-bad-sig",
    });
    const fixture = {memberKp, scannerKp, ...ids};
    const receipt = buildSignedReceipt({
      fixture,
      scannerKp,
      memberKp,
      localReceiptId: "r-bad-sig",
      responseNonce: "rn-bad-sig",
    });
    receipt.scannerSignature = "AAAA";

    const result = await syncOneReceipt({
      raw: receipt,
      scannerId: fixture.scannerId,
      scannerPub: scannerKp.publicKeyBase64Url,
      operatorUid: "operator-1",
    });
    assert.equal(result.status, "rejected");
    assert.equal(result.code, "invalid-scanner-signature");

    const eventSnap = await db.collection("attendance_events").doc(ids.eventId).get();
    assert.equal(eventSnap.data().asistenciaCount, 0);
  });
});

describe("isConfirmedAsistenciaCount (unit)", () => {
  it("accepts only non-negative integers", () => {
    const {isConfirmedAsistenciaCount} = require("./attendance-qr")._test;
    assert.equal(isConfirmedAsistenciaCount(0), true);
    assert.equal(isConfirmedAsistenciaCount(5), true);
    assert.equal(isConfirmedAsistenciaCount(undefined), false);
    assert.equal(isConfirmedAsistenciaCount(null), false);
    assert.equal(isConfirmedAsistenciaCount("0"), false);
    assert.equal(isConfirmedAsistenciaCount(-1), false);
    assert.equal(isConfirmedAsistenciaCount(1.5), false);
  });
});

describe("package signature integrity (unit)", () => {
  it("tampering eventId breaks package signature", () => {
    const kp = cryptoHelpers.keyFromSeedBase64Url(
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    );
    const fields = {
      v: "2",
      type: "SATT2PKG",
      packageId: "p1",
      eventId: "event-a",
      eventName: "Asamblea",
      startAt: "1",
      endAt: "2",
      issuedAtServer: "3",
      expiresAt: "4",
      serverTimeAtPreparation: "3",
      scannerId: "s1",
      scannerPublicKey: "pub",
      geofenceEnabled: "0",
      geofenceRadiusMeters: "150",
      participantsHash: "abc",
      keyVersion: "v1",
    };
    const canonical = cryptoHelpers.canonicalPackagePayload(fields);
    const sig = cryptoHelpers.signUtf8(canonical, kp.privateKey);
    assert.equal(
      cryptoHelpers.verifyUtf8(canonical, sig, kp.publicKeyBase64Url),
      true,
    );
    const tampered = cryptoHelpers.canonicalPackagePayload({
      ...fields,
      eventId: "event-b",
    });
    assert.equal(
      cryptoHelpers.verifyUtf8(tampered, sig, kp.publicKeyBase64Url),
      false,
    );
  });
});
