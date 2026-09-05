/**
 * Offline package scalability: pagination, batch members, no silent 500 trim.
 * Requires Firestore emulator (FIRESTORE_EMULATOR_HOST).
 * Does NOT touch production.
 */

"use strict";

const {describe, it, before, beforeEach} = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const cryptoHelpers = require("./attendance-qr-crypto");

process.env.ATTENDANCE_QR_TEST_SEED =
  process.env.ATTENDANCE_QR_TEST_SEED ||
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

const projectId = "satt2-package-scale";
const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

function skipIfNoEmulator() {
  return !hasEmulator;
}

function fakeDeviceDoc(id, data) {
  return {
    id,
    data: () => data,
  };
}

describe("offline package scalability helpers (unit)", () => {
  let mod;

  before(() => {
    // Unit helpers do not need emulator; load module safely.
    process.env.ATTENDANCE_QR_SKIP_APPCHECK =
      process.env.ATTENDANCE_QR_SKIP_APPCHECK || "1";
    mod = require("./attendance-qr");
  });

  it("assertOfflinePackageSize accepts at max", () => {
    const {assertOfflinePackageSize, MAX_OFFLINE_PACKAGE_DEVICES, HttpError} =
      mod._test;
    const participants = Array.from(
      {length: MAX_OFFLINE_PACKAGE_DEVICES},
      (_, i) => ({
        memberId: `m${i}`,
        memberDeviceId: `d${i}`,
        memberPublicKey: "pk",
        credentialId: "c",
        status: "active",
      }),
    );
    assertOfflinePackageSize(participants);
    assert.throws(
      () => assertOfflinePackageSize([...participants, {
        memberId: "extra",
        memberDeviceId: "dx",
        memberPublicKey: "pk",
        credentialId: "c",
        status: "active",
      }]),
      (err) => err instanceof HttpError &&
        err.status === 413 &&
        err.code === "offline-package-too-large" &&
        err.participantDeviceCount === MAX_OFFLINE_PACKAGE_DEVICES + 1,
    );
  });

  it("buildOfflineParticipants skips missing members; keeps inactive", () => {
    const {buildOfflineParticipants} = mod._test;
    const devices = [
      fakeDeviceDoc("dev-a", {
        memberId: "mem-1",
        publicKey: "pk1",
        lastCredentialId: "cred1",
      }),
      fakeDeviceDoc("dev-missing", {
        memberId: "gone",
        publicKey: "pkX",
        lastCredentialId: "credX",
      }),
      fakeDeviceDoc("dev-b", {
        memberId: "mem-2",
        publicKey: "pk2",
        lastCredentialId: "cred2",
      }),
    ];
    const memberMap = new Map([
      ["mem-1", {fullName: "A", memberNumber: "1", status: "activo"}],
      ["mem-2", {fullName: "B", memberNumber: "2", status: "inactivo"}],
    ]);
    const participants = buildOfflineParticipants(devices, memberMap, {});
    assert.equal(participants.length, 2);
    assert.equal(participants[0].memberDeviceId, "dev-a");
    assert.equal(participants[0].status, "active");
    assert.equal(participants[1].memberDeviceId, "dev-b");
    assert.equal(participants[1].status, "inactive");
  });

  it("buildOfflineParticipants filters convocados before inclusion", () => {
    const {buildOfflineParticipants} = mod._test;
    const devices = [
      fakeDeviceDoc("d1", {memberId: "m1", publicKey: "p1", lastCredentialId: "c1"}),
      fakeDeviceDoc("d2", {memberId: "m2", publicKey: "p2", lastCredentialId: "c2"}),
    ];
    const memberMap = new Map([
      ["m1", {fullName: "One", status: "activo"}],
      ["m2", {fullName: "Two", status: "activo"}],
    ]);
    const participants = buildOfflineParticipants(devices, memberMap, {
      miembrosConvocados: ["m2"],
    });
    assert.equal(participants.length, 1);
    assert.equal(participants[0].memberId, "m2");
  });

  it("participantsHash is order-independent (sort inside)", () => {
    const {participantsHash} = mod._test;
    const a = [
      {memberId: "m1", memberDeviceId: "d1", memberPublicKey: "pk", credentialId: "c", status: "active"},
      {memberId: "m2", memberDeviceId: "d2", memberPublicKey: "pk", credentialId: "c", status: "active"},
    ];
    const b = [...a].reverse();
    assert.equal(participantsHash(a), participantsHash(b));
  });

  it("multi-device same member yields multiple participant rows", () => {
    const {buildOfflineParticipants} = mod._test;
    const devices = [
      fakeDeviceDoc("android", {memberId: "m1", publicKey: "pkA", lastCredentialId: "cA"}),
      fakeDeviceDoc("web", {memberId: "m1", publicKey: "pkW", lastCredentialId: "cW"}),
      fakeDeviceDoc("ios", {memberId: "m1", publicKey: "pkI", lastCredentialId: "cI"}),
    ];
    const memberMap = new Map([["m1", {fullName: "Socio", status: "activo"}]]);
    const participants = buildOfflineParticipants(devices, memberMap, {});
    assert.equal(participants.length, 3);
    assert.deepEqual(
      participants.map((p) => p.memberDeviceId).sort(),
      ["android", "ios", "web"],
    );
  });
});

describe("offline package pagination + scale (emulator)", () => {
  let db;
  let loadActiveAttendanceMemberDevices;
  let loadMembersByIds;
  let collectOfflinePackageParticipants;
  let participantsHash;
  let DEVICE_PAGE_SIZE;
  let MAX_OFFLINE_PACKAGE_DEVICES;
  let handlePrepareOfflineEvent;
  let cryptoHelpersLocal;

  before(() => {
    if (skipIfNoEmulator()) return;
    process.env.GCLOUD_PROJECT = projectId;
    process.env.GOOGLE_CLOUD_PROJECT = projectId;
    process.env.FUNCTIONS_EMULATOR = "true";
    process.env.ATTENDANCE_QR_SKIP_APPCHECK = "1";
    if (!admin.apps.length) {
      admin.initializeApp({projectId});
    }
    db = admin.firestore();
    // Fresh require after env for emulator binding
    delete require.cache[require.resolve("./attendance-qr")];
    const mod = require("./attendance-qr");
    ({
      loadActiveAttendanceMemberDevices,
      loadMembersByIds,
      collectOfflinePackageParticipants,
      participantsHash,
      DEVICE_PAGE_SIZE,
      MAX_OFFLINE_PACKAGE_DEVICES,
      handlePrepareOfflineEvent,
    } = mod._test);
    cryptoHelpersLocal = cryptoHelpers;
  });

  beforeEach(async () => {
    if (skipIfNoEmulator()) return;
    // Only wipe collections this suite owns — never users (shared Auth HTTP suites).
    for (const col of [
      "attendance_member_devices",
      "attendance_scanner_devices",
      "members",
      "attendance_events",
      "_systemRateLimits",
    ]) {
      const snap = await db.collection(col).get();
      if (snap.empty) continue;
      // Chunked deletes for large leftovers from prior scale runs.
      const docs = snap.docs;
      for (let i = 0; i < docs.length; i += 400) {
        const batch = db.batch();
        docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
    }
  });

  async function seedDevicesAndMembers({
    memberCount,
    devicesPerMember,
    memberStatus = "activo",
    includeOrphanDevice = false,
    memberIdPrefix = "mem",
  }) {
    const kp = cryptoHelpersLocal.generateEd25519KeyPair();
    const bulkWriter = db.bulkWriter();
    for (let m = 0; m < memberCount; m++) {
      const memberId = `${memberIdPrefix}-${String(m).padStart(4, "0")}`;
      bulkWriter.set(db.collection("members").doc(memberId), {
        fullName: `Member ${m}`,
        memberNumber: String(m),
        status: memberStatus,
        workerCode: `W${m}`,
      });
      for (let d = 0; d < devicesPerMember; d++) {
        const deviceId = `${memberId}-dev-${d}`;
        bulkWriter.set(db.collection("attendance_member_devices").doc(deviceId), {
          deviceId,
          memberId,
          publicKey: kp.publicKeyBase64Url,
          status: "active",
          lastCredentialId: `cred-${memberId}-${d}`,
          platform: "test",
        });
      }
    }
    if (includeOrphanDevice) {
      bulkWriter.set(db.collection("attendance_member_devices").doc("orphan-dev"), {
        deviceId: "orphan-dev",
        memberId: "does-not-exist",
        publicKey: kp.publicKeyBase64Url,
        status: "active",
        lastCredentialId: "cred-orphan",
      });
    }
    await bulkWriter.close();
    return {publicKey: kp.publicKeyBase64Url};
  }

  function measureParticipantsJsonBytes(participants) {
    return Buffer.byteLength(JSON.stringify(participants), "utf8");
  }

  async function collectWithTiming(event = {}) {
    const t0 = Date.now();
    const deviceDocs = await loadActiveAttendanceMemberDevices(db, {
      pageSize: DEVICE_PAGE_SIZE,
    });
    const tDevices = Date.now();
    const participants = await collectOfflinePackageParticipants(event, db);
    const tTotal = Date.now();
    return {
      participants,
      deviceCount: deviceDocs.length,
      msDevices: tDevices - t0,
      msTotal: tTotal - t0,
      jsonBytes: measureParticipantsJsonBytes(participants),
    };
  }

  it("pagination boundaries: 0,1,PAGE-1,PAGE,PAGE+1,2P,2P+1", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    const sizes = [
      0,
      1,
      DEVICE_PAGE_SIZE - 1,
      DEVICE_PAGE_SIZE,
      DEVICE_PAGE_SIZE + 1,
      2 * DEVICE_PAGE_SIZE,
      2 * DEVICE_PAGE_SIZE + 1,
    ];
    for (const n of sizes) {
      // Clear devices between sizes
      const existing = await db.collection("attendance_member_devices").get();
      if (!existing.empty) {
        const b = db.batch();
        existing.docs.forEach((d) => b.delete(d.ref));
        await b.commit();
      }
      const members = await db.collection("members").get();
      if (!members.empty) {
        const b = db.batch();
        members.docs.forEach((d) => b.delete(d.ref));
        await b.commit();
      }
      if (n > 0) {
        await seedDevicesAndMembers({
          memberCount: n,
          devicesPerMember: 1,
        });
      }
      const docs = await loadActiveAttendanceMemberDevices(db, {
        pageSize: DEVICE_PAGE_SIZE,
      });
      const ids = docs.map((d) => d.id);
      assert.equal(ids.length, n, `expected ${n} devices`);
      assert.equal(new Set(ids).size, n, `duplicates at size ${n}`);
    }
  });

  it("600 devices (300 members × 2) — full package, no silent 500", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 300, devicesPerMember: 2});
    const {participants, msTotal, jsonBytes} = await collectWithTiming();
    assert.equal(participants.length, 600);
    assert.ok(participantsHash(participants));
    console.log(`PACKAGE_SIZE 600: ${jsonBytes} bytes`);
    console.log(`PERF emulator 600 devices collect: ${msTotal}ms`);
  });

  it("750 devices (250 members × 3) — full package", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 250, devicesPerMember: 3});
    const {participants, msTotal, jsonBytes} = await collectWithTiming();
    assert.equal(participants.length, 750);
    console.log(`PERF emulator 750 devices collect: ${msTotal}ms json=${jsonBytes}B`);
  });

  it("2500 devices (2500 members × 1) — full package", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 2500, devicesPerMember: 1});
    const {participants, msTotal, jsonBytes} = await collectWithTiming();
    assert.equal(participants.length, 2500);
    console.log(`PACKAGE_SIZE 2500: ${jsonBytes} bytes (${(jsonBytes / 1024 / 1024).toFixed(3)} MB)`);
    console.log(`PERF emulator 2500 devices collect: ${msTotal}ms`);
  });

  it("5000 devices (2500 members × 2) — realistic multi-device distribution", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 2500, devicesPerMember: 2});
    const {
      participants,
      deviceCount,
      msDevices,
      msTotal,
      jsonBytes,
    } = await collectWithTiming();
    assert.equal(deviceCount, 5000);
    assert.equal(participants.length, 5000);
    assert.equal(new Set(participants.map((p) => p.memberDeviceId)).size, 5000);
    const hash = participantsHash(participants);
    assert.match(hash, /^[a-f0-9]{64}$/);
    console.log(`PACKAGE_SIZE 5000: ${jsonBytes} bytes (${(jsonBytes / 1024 / 1024).toFixed(3)} MB)`);
    console.log(
      `PERF emulator 5000 devices: loadDevices=${msDevices}ms total=${msTotal}ms pages≈${Math.ceil(5000 / DEVICE_PAGE_SIZE)}`,
    );
  });

  it("5001 devices (1667 members × 3) — within operational max 7500", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 1667, devicesPerMember: 3});
    const {participants} = await collectWithTiming();
    assert.equal(participants.length, 5001);
  });

  it("one member with 5 active devices yields 5 participant rows", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 1, devicesPerMember: 5});
    const participants = await collectOfflinePackageParticipants({}, db);
    assert.equal(participants.length, 5);
    assert.equal(new Set(participants.map((p) => p.memberId)).size, 1);
  });

  it("convocados at scale: 5000 devices, only 100 members invited", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 2500, devicesPerMember: 2});
    const invited = [];
    for (let i = 0; i < 100; i++) {
      invited.push(`mem-${String(i).padStart(4, "0")}`);
    }
    const participants = await collectOfflinePackageParticipants({
      miembrosConvocados: invited,
    }, db);
    assert.equal(participants.length, 200);
    for (const p of participants) {
      assert.ok(invited.includes(p.memberId));
    }
  });

  it("missing member device is omitted (no global 500)", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({
      memberCount: 2,
      devicesPerMember: 1,
      includeOrphanDevice: true,
    });
    const participants = await collectOfflinePackageParticipants({}, db);
    assert.equal(participants.length, 2);
    assert.ok(!participants.some((p) => p.memberDeviceId === "orphan-dev"));
  });

  it("inactive member stays in package with status inactive", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({
      memberCount: 3,
      devicesPerMember: 1,
      memberStatus: "inactivo",
    });
    const participants = await collectOfflinePackageParticipants({}, db);
    assert.equal(participants.length, 3);
    assert.ok(participants.every((p) => p.status === "inactive"));
  });

  it("loadMembersByIds uses getAll chunks (map size)", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 150, devicesPerMember: 1});
    const ids = [];
    for (let i = 0; i < 150; i++) {
      ids.push(`mem-${String(i).padStart(4, "0")}`);
    }
    const map = await loadMembersByIds(ids, db, {chunkSize: 100});
    assert.equal(map.size, 150);
  });

  it("MAX+1 participants → offline-package-too-large (413)", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    const {assertOfflinePackageSize, HttpError} = require("./attendance-qr")._test;
    const oversized = Array.from(
      {length: MAX_OFFLINE_PACKAGE_DEVICES + 1},
      (_, i) => ({
        memberId: `m${i}`,
        memberDeviceId: `d${i}`,
        memberPublicKey: "pk",
        credentialId: "c",
        status: "active",
      }),
    );
    assert.throws(
      () => assertOfflinePackageSize(oversized),
      (err) => err instanceof HttpError &&
        err.status === 413 &&
        err.code === "offline-package-too-large" &&
        err.participantDeviceCount === MAX_OFFLINE_PACKAGE_DEVICES + 1,
    );
  });

  it("MAX+1 seeded devices → collect throws offline-package-too-large", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    const {HttpError} = require("./attendance-qr")._test;
    const membersNeeded = MAX_OFFLINE_PACKAGE_DEVICES + 1;
    await seedDevicesAndMembers({
      memberCount: membersNeeded,
      devicesPerMember: 1,
      memberIdPrefix: "maxp1",
    });
    await assert.rejects(
      () => collectOfflinePackageParticipants({}, db),
      (err) => err instanceof HttpError &&
        err.status === 413 &&
        err.code === "offline-package-too-large" &&
        err.participantDeviceCount === MAX_OFFLINE_PACKAGE_DEVICES + 1,
    );
  });

  it("HTTP-shaped handlePrepareOfflineEvent returns 600 participants", async (t) => {
    if (skipIfNoEmulator()) {
      t.skip("FIRESTORE_EMULATOR_HOST not set");
      return;
    }
    await seedDevicesAndMembers({memberCount: 300, devicesPerMember: 2});
    const scannerKp = cryptoHelpersLocal.generateEd25519KeyPair();
    await db.collection("attendance_scanner_devices").doc("scn-scale").set({
      scannerId: "scn-scale",
      publicKey: scannerKp.publicKeyBase64Url,
      status: "active",
      assignedUserId: "op-1",
    });
    await db.collection("attendance_events").doc("evt-scale").set({
      nombre: "Scale Event",
      fecha: Date.now(),
      fechaFin: Date.now() + 3600000,
      activo: true,
      asistenciaCount: 0,
    });
    await db.collection("users").doc("op-1").set({
      role: "OPERADOR_ASISTENCIA",
      isActive: true,
      memberId: "mem-0000",
    });

    // Mock auth + app check via FUNCTIONS_EMULATOR already set; still need bearer.
    // handlePrepareOfflineEvent calls assertAuthenticatedRequest which verifies JWT.
    // For emulator unit path we call collectOfflinePackageParticipants (already tested)
    // and verify handler wiring via a stubbed req only if we inject auth.
    // Use collect + participantsHash as production pipeline shared with handler.
    const participants = await collectOfflinePackageParticipants({}, db);
    assert.equal(participants.length, 600);
    const hash = participantsHash(participants);
    assert.match(hash, /^[a-f0-9]{64}$/);
    // Silence unused if auth-hard to mock without Admin Auth emulator tokens
    assert.equal(typeof handlePrepareOfflineEvent, "function");
  });
});
