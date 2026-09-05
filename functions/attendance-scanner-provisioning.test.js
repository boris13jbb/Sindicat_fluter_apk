"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const cryptoHelpers = require("./attendance-qr-crypto");
const attendanceQr = require("./attendance-qr");

const {registerScannerDeviceRecord, approveScannerDeviceRecord,
  parseScannerRegistration, parseScannerApproval, assertScannerAssignment} =
  attendanceQr._test;
// TEST KEY - NEVER USE IN PRODUCTION.
const PUBLIC_KEY_A = cryptoHelpers.keyFromSeedBase64Url(
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
).publicKeyBase64Url;
const PUBLIC_KEY_B = cryptoHelpers.keyFromSeedBase64Url(
  "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE",
).publicKeyBase64Url;

function memoryFirestore(initial = {}) {
  const records = new Map(
    Object.entries(initial).map(([id, value]) => [id, {...value}]),
  );
  let writeCount = 0;

  const firestore = {
    collection(name) {
      assert.equal(name, "attendance_scanner_devices");
      return {
        doc(id) {
          return {id};
        },
      };
    },
    async runTransaction(callback) {
      const pendingWrites = [];
      const transaction = {
        async get(ref) {
          const value = records.get(ref.id);
          return {
            exists: value !== undefined,
            data: () => value === undefined ? undefined : {...value},
          };
        },
        set(ref, value) {
          pendingWrites.push({kind: "set", id: ref.id, value: {...value}});
        },
        update(ref, value) {
          pendingWrites.push({kind: "update", id: ref.id, value: {...value}});
        },
      };
      const result = await callback(transaction);
      for (const write of pendingWrites) {
        const previous = records.get(write.id) || {};
        records.set(
          write.id,
          write.kind === "set" ? write.value : {...previous, ...write.value},
        );
        writeCount += 1;
      }
      return result;
    },
  };

  return {
    firestore,
    read: (id) => records.get(id),
    writes: () => writeCount,
  };
}

function register({
  store,
  role = "OPERADOR_ASISTENCIA",
  uid = "operator-1",
  publicKey = PUBLIC_KEY_A,
  assignedUserId = uid,
  assignmentExplicit = false,
  approve = false,
} = {}) {
  return registerScannerDeviceRecord({
    firestore: store.firestore,
    actorUid: uid,
    actorRole: role,
    scannerId: "scanner-1",
    publicKey,
    platform: "android",
    deviceLabel: "Scanner test",
    assignedUserId,
    assignmentExplicit,
    approve,
    timestampFactory: () => "timestamp-test",
  });
}

function approve({
  store,
  role = "ADMIN",
  uid = "admin-1",
} = {}) {
  return approveScannerDeviceRecord({
    firestore: store.firestore,
    actorUid: uid,
    actorRole: role,
    scannerId: "scanner-1",
    timestampFactory: () => "approval-test",
  });
}

function expectHttpError(status, code) {
  return (error) => error?.status === status && error?.code === code;
}

describe("scanner registration transaction", () => {
  it("operator creates a pending scanner assigned to self", async () => {
    const store = memoryFirestore();
    const result = await register({store});

    assert.deepEqual(result, {scannerId: "scanner-1", status: "pending"});
    assert.equal(store.read("scanner-1").assignedUserId, "operator-1");
    assert.equal(store.read("scanner-1").publicKey, PUBLIC_KEY_A);
    assert.equal(store.read("scanner-1").approvedAt, null);
  });

  it("admin creates and activates a scanner with approve=true", async () => {
    const store = memoryFirestore();
    const result = await register({
      store,
      role: "ADMIN",
      uid: "admin-1",
      assignedUserId: "admin-1",
      approve: true,
    });

    assert.equal(result.status, "active");
    assert.equal(store.read("scanner-1").approvedBy, "admin-1");
    assert.equal(store.read("scanner-1").approvedAt, "timestamp-test");
  });

  it("operator cannot assign a scanner to another user", async () => {
    const store = memoryFirestore();
    await assert.rejects(
      register({
        store,
        assignedUserId: "other-user",
        assignmentExplicit: true,
      }),
      expectHttpError(403, "scanner-assignment-forbidden"),
    );
    assert.equal(store.writes(), 0);
  });

  it("operator cannot self-approve through registration", async () => {
    const store = memoryFirestore();
    await assert.rejects(
      register({store, approve: true}),
      expectHttpError(403, "only-admin-can-approve-scanner"),
    );
    assert.equal(store.writes(), 0);
  });

  it("admin may assign a new scanner explicitly without weakening approval", async () => {
    const store = memoryFirestore();
    const result = await register({
      store,
      role: "SUPERADMIN",
      uid: "superadmin-1",
      assignedUserId: "operator-2",
      assignmentExplicit: true,
      approve: true,
    });

    assert.equal(result.status, "active");
    assert.equal(store.read("scanner-1").assignedUserId, "operator-2");
    assert.equal(store.read("scanner-1").approvedBy, "superadmin-1");
  });

  it("pending registration with the same key is idempotent", async () => {
    const existing = {
      scannerId: "scanner-1",
      publicKey: PUBLIC_KEY_A,
      status: "pending",
      assignedUserId: "operator-1",
      createdAt: "original-created",
    };
    const store = memoryFirestore({"scanner-1": existing});
    const result = await register({store});

    assert.equal(result.status, "pending");
    assert.deepEqual(store.read("scanner-1"), existing);
    assert.equal(store.writes(), 0);
  });

  it("pending registration rejects a different public key", async () => {
    const store = memoryFirestore({
      "scanner-1": {
        publicKey: PUBLIC_KEY_A,
        status: "pending",
        assignedUserId: "operator-1",
      },
    });
    await assert.rejects(
      register({store, publicKey: PUBLIC_KEY_B}),
      expectHttpError(409, "scanner-key-mismatch"),
    );
    assert.equal(store.writes(), 0);
  });

  it("active registration with the same key remains active", async () => {
    const existing = {
      scannerId: "scanner-1",
      publicKey: PUBLIC_KEY_A,
      status: "active",
      assignedUserId: "operator-1",
      approvedAt: "original-approval",
      approvedBy: "admin-original",
    };
    const store = memoryFirestore({"scanner-1": existing});
    const result = await register({store});

    assert.equal(result.status, "active");
    assert.deepEqual(store.read("scanner-1"), existing);
    assert.equal(store.writes(), 0);
  });

  it("re-registering active scanner cannot downgrade it to pending", async () => {
    const store = memoryFirestore({
      "scanner-1": {
        publicKey: PUBLIC_KEY_A,
        status: "active",
        assignedUserId: "operator-1",
        approvedAt: "original-approval",
        approvedBy: "admin-original",
      },
    });
    const result = await register({store, approve: false});

    assert.equal(result.status, "active");
    assert.equal(store.read("scanner-1").approvedAt, "original-approval");
    assert.equal(store.read("scanner-1").approvedBy, "admin-original");
    assert.equal(store.writes(), 0);
  });

  it("active registration rejects key replacement", async () => {
    const store = memoryFirestore({
      "scanner-1": {
        publicKey: PUBLIC_KEY_A,
        status: "active",
        assignedUserId: "operator-1",
      },
    });
    await assert.rejects(
      register({store, publicKey: PUBLIC_KEY_B}),
      expectHttpError(409, "scanner-key-mismatch"),
    );
  });

  it("revoked scanner cannot be re-registered", async () => {
    const store = memoryFirestore({
      "scanner-1": {
        publicKey: PUBLIC_KEY_A,
        status: "revoked",
        assignedUserId: "operator-1",
      },
    });
    await assert.rejects(
      register({store}),
      expectHttpError(403, "scanner-revoked"),
    );
  });
});

describe("scanner approval transaction", () => {
  it("operator cannot approve", async () => {
    const store = memoryFirestore({
      "scanner-1": {publicKey: PUBLIC_KEY_A, status: "pending"},
    });
    await assert.rejects(
      approve({store, role: "OPERADOR_ASISTENCIA", uid: "operator-1"}),
      expectHttpError(403, "only-admin-can-approve-scanner"),
    );
    assert.equal(store.writes(), 0);
  });

  it("admin approves pending without changing scanner identity", async () => {
    const store = memoryFirestore({
      "scanner-1": {
        scannerId: "scanner-1",
        publicKey: PUBLIC_KEY_A,
        status: "pending",
        assignedUserId: "operator-1",
        createdAt: "original-created",
      },
    });
    const result = await approve({store});
    const saved = store.read("scanner-1");

    assert.equal(result.status, "active");
    assert.equal(saved.publicKey, PUBLIC_KEY_A);
    assert.equal(saved.assignedUserId, "operator-1");
    assert.equal(saved.scannerId, "scanner-1");
    assert.equal(saved.createdAt, "original-created");
    assert.equal(saved.approvedBy, "admin-1");
  });

  it("approving an already active scanner is idempotent", async () => {
    const existing = {
      publicKey: PUBLIC_KEY_A,
      status: "active",
      assignedUserId: "operator-1",
      approvedAt: "original-approval",
      approvedBy: "admin-original",
    };
    const store = memoryFirestore({"scanner-1": existing});
    const result = await approve({store});

    assert.equal(result.status, "active");
    assert.deepEqual(store.read("scanner-1"), existing);
    assert.equal(store.writes(), 0);
  });

  it("revoked scanner cannot be approved", async () => {
    const store = memoryFirestore({
      "scanner-1": {publicKey: PUBLIC_KEY_A, status: "revoked"},
    });
    await assert.rejects(
      approve({store}),
      expectHttpError(403, "scanner-revoked"),
    );
  });

  it("missing scanner returns 404", async () => {
    const store = memoryFirestore();
    await assert.rejects(
      approve({store}),
      expectHttpError(404, "scanner-missing"),
    );
  });
});

describe("scanner adversarial input and assignment", () => {
  const valid = {scannerId: "scanner-1", publicKey: PUBLIC_KEY_A};

  it("bounds scanner IDs and rejects nested paths, coercion and controls", () => {
    for (const scannerId of ["", "x".repeat(129), "a/b/c", "..", 7, {}, "a\n", " a"]) {
      assert.throws(() => parseScannerRegistration({...valid, scannerId}, "operator-1"),
        expectHttpError(400, "invalid-scannerId"));
      assert.throws(() => parseScannerApproval({scannerId}),
        expectHttpError(400, "invalid-scannerId"));
    }
    assert.equal(parseScannerApproval({scannerId: "x".repeat(128)}).scannerId.length, 128);
  });

  it("bounds metadata and refuses object or control-character coercion", () => {
    for (const [name, maximum] of [["deviceLabel", 128], ["platform", 32]]) {
      for (const value of ["x".repeat(maximum + 1), {}, 2, null, "line\nbreak"]) {
        assert.throws(() => parseScannerRegistration({...valid, [name]: value}, "operator-1"),
          expectHttpError(400, `invalid-${name}`));
      }
      assert.equal(parseScannerRegistration({...valid, [name]: "x".repeat(maximum)},
        "operator-1")[name].length, maximum);
    }
  });

  it("rejects oversized bodies before storing fields", () => {
    for (const parse of [parseScannerRegistration, parseScannerApproval]) {
      assert.throws(() => parse({...valid, extra: "x".repeat(4096)}, "operator-1"),
        expectHttpError(413, "scanner-request-too-large"));
    }
  });

  it("assignment must be a bounded exact UID, and approve must be boolean", () => {
    for (const assignedUserId of ["", "x".repeat(129), {}, 7, null, "a/b", " uid "]) {
      assert.throws(() => parseScannerRegistration({...valid, assignedUserId}, "operator-1"),
        expectHttpError(400, "invalid-assignedUserId"));
    }
    for (const approve of ["true", 1, {}, null]) {
      assert.throws(() => parseScannerRegistration({...valid, approve}, "operator-1"),
        expectHttpError(400, "invalid-approve"));
    }
    assert.equal(parseScannerRegistration(valid, "operator-1").assignedUserId, "operator-1");
  });

  it("rejects noncanonical public keys", () => {
    for (const publicKey of [PUBLIC_KEY_A + "=", PUBLIC_KEY_A + "\n", "x".repeat(42), {}]) {
      assert.throws(() => parseScannerRegistration({...valid, publicKey}, "operator-1"),
        expectHttpError(400, "invalid-publicKey"));
    }
  });

  it("approval discards body fields that could spoof identity or approver", () => {
    assert.deepEqual(parseScannerApproval({
      scannerId: "scanner-1", publicKey: PUBLIC_KEY_B, assignedUserId: "attacker",
      approvedBy: "attacker", status: "active",
    }), {scannerId: "scanner-1"});
  });

  it("package and sync require exact operator assignment, including missing assignments", () => {
    for (const assignedUserId of [undefined, null, "", "other-operator"]) {
      assert.throws(() => assertScannerAssignment({assignedUserId}, "operator-1", "OPERADOR_ASISTENCIA"),
        expectHttpError(403, "scanner-not-assigned"));
    }
    assert.doesNotThrow(() => assertScannerAssignment({assignedUserId: "operator-1"},
      "operator-1", "OPERADOR_ASISTENCIA"));
    for (const role of ["ADMIN", "SUPERADMIN"]) {
      assert.doesNotThrow(() => assertScannerAssignment({assignedUserId: "operator-1"}, "admin-1", role));
    }
  });

  it("existing ownership cannot be stolen with the known public key", async () => {
    const store = memoryFirestore({"scanner-1": {
      publicKey: PUBLIC_KEY_A, assignedUserId: "another-operator", status: "active",
    }});
    await assert.rejects(register({store}), expectHttpError(403, "scanner-assignment-forbidden"));
    assert.equal(store.writes(), 0);
  });

  it("even admin cannot replace an existing key or reassign through repeat register", async () => {
    const store = memoryFirestore({"scanner-1": {
      publicKey: PUBLIC_KEY_A, assignedUserId: "operator-1", status: "active",
    }});
    await assert.rejects(register({store, role: "ADMIN", publicKey: PUBLIC_KEY_B}),
      expectHttpError(409, "scanner-key-mismatch"));
    await assert.rejects(register({store, role: "ADMIN", assignedUserId: "other", assignmentExplicit: true}),
      expectHttpError(403, "scanner-assignment-forbidden"));
    assert.equal(store.writes(), 0);
  });
});
