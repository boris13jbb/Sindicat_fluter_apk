"use strict";

/**
 * Secure Attendance QR V2 — Cloud Functions (enrollment, credential,
 * offline package, sync). Writes of metodoRegistro=SECURE_QR_V2 are
 * performed only via Admin SDK here.
 *
 * Secrets: ATTENDANCE_QR_SIGNING_PRIVATE_KEY (seed base64url) — NOT set in
 * this task. Tests inject keys; production set is a separate authorized step.
 */

const {initializeApp, getApps} = require("firebase-admin/app");
const {FieldValue, FieldPath, Timestamp, getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {logger} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const cryptoHelpers = require("./attendance-qr-crypto");
const {memberIsActive} = require("./admin-user");

// Safe when required before/after index.js initializeApp (emulator + tests).
if (!getApps().length) {
  initializeApp();
}

const db = getFirestore();
const attendanceQrSigningKey = defineSecret("ATTENDANCE_QR_SIGNING_PRIVATE_KEY");

const MEMBER_DEVICES = "attendance_member_devices";
const SCANNER_DEVICES = "attendance_scanner_devices";
const RATE_LIMIT_COLLECTION = "_systemRateLimits";
const METODO_SECURE = "SECURE_QR_V2";
const KEY_VERSION = "v1";
const CREDENTIAL_MAX_MS = 7 * 24 * 60 * 60 * 1000;
const BATCH_MAX = 50;

/** Pagination size for active member-device queries (deterministic orderBy __name__). */
const DEVICE_PAGE_SIZE = 200;
/** Admin SDK getAll() chunk size for members/{id} batch reads. */
const MEMBER_GETALL_CHUNK = 100;
/**
 * Operational max participants (devices) in one offline package.
 * Minimum guaranteed capacity: 5000 active devices (requirement).
 * Headroom to 7500 (~1.74 MB full HTTP package in fixture measurements;
 * participants JSON alone ~1.74 MB at 7500) stays under Cloud Functions v2 /
 * Hosting proxy comfort with margin vs MAX_PARTICIPANTS_JSON_BYTES.
 * Exceeding this yields HTTP 413 offline-package-too-large (never silent trim).
 */
const MAX_OFFLINE_PACKAGE_DEVICES = 7500;
/** Absolute scan ceiling while paginating active devices (DoS / memory guard). */
const MAX_ACTIVE_DEVICE_SCAN = 20000;
/**
 * JSON size guard on participants array alone (UTF-8 bytes).
 * ~2.32 MB at 10k fixture participants; 7500 ≈ 1.74 MB measured.
 */
const MAX_PARTICIPANTS_JSON_BYTES = 3 * 1024 * 1024;

const ENROLL_LIMIT = {maximum: 10, windowMs: 60 * 60 * 1000};
const PREP_LIMIT = {maximum: 30, windowMs: 60 * 60 * 1000};
const SYNC_LIMIT = {maximum: 60, windowMs: 60 * 60 * 1000};

class HttpError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

function hash(value) {
  return cryptoHelpers.hashSha256Hex(String(value || ""));
}

function requestIp(req) {
  const forwarded = req.get("x-forwarded-for");
  return forwarded ? forwarded.split(",")[0].trim() : req.ip || "unknown";
}

async function enforceNamedRateLimit(bucket, key, limit) {
  const ref = db.collection(RATE_LIMIT_COLLECTION).doc(`${bucket}-${hash(key)}`);
  const nowMs = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? snap.data() : null;
    const windowStart = current?.windowStart?.toMillis?.() || 0;
    const isCurrent = nowMs - windowStart < limit.windowMs;
    const count = isCurrent ? Number(current?.count || 0) : 0;
    if (count >= limit.maximum) {
      throw new HttpError(429, "rate-limited", "Too many requests");
    }
    tx.set(ref, {
      count: count + 1,
      windowStart: Timestamp.fromMillis(isCurrent ? windowStart : nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function assertBearerUid(req) {
  const authHeader = String(req.get("authorization") || "");
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new HttpError(401, "missing-auth");
  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    return decoded.uid;
  } catch (_) {
    throw new HttpError(401, "invalid-auth");
  }
}

/**
 * App Check enforcement policy for Secure Attendance HTTP endpoints.
 *
 * Production: REQUIRED by default (independent of Auth).
 * Emulator: bypass when FUNCTIONS_EMULATOR=true.
 * Tests: bypass only with explicit ATTENDANCE_QR_SKIP_APPCHECK=1
 *        or by injecting verifyAppCheckTokenForTests.
 *
 * Never treat a missing ATTENDANCE_QR_REQUIRE_APPCHECK as "security off".
 * That legacy flag is ignored for enforcement decisions.
 */
function shouldEnforceAttendanceAppCheck(env = process.env) {
  if (String(env.FUNCTIONS_EMULATOR || "") === "true") return false;
  if (String(env.ATTENDANCE_QR_SKIP_APPCHECK || "") === "1") return false;
  return true;
}

/** Injectable verifier for unit tests (production uses Admin SDK). */
let verifyAppCheckTokenImpl = async (appCheckToken) => {
  const {getAppCheck} = require("firebase-admin/app-check");
  await getAppCheck().verifyToken(appCheckToken);
};

function setVerifyAppCheckTokenForTests(fn) {
  verifyAppCheckTokenImpl = fn;
}

function resetVerifyAppCheckTokenForTests() {
  verifyAppCheckTokenImpl = async (appCheckToken) => {
    const {getAppCheck} = require("firebase-admin/app-check");
    await getAppCheck().verifyToken(appCheckToken);
  };
}

/**
 * Asserts X-Firebase-AppCheck (case-insensitive via req.get).
 * Token is never accepted from query/body/URL.
 */
async function assertAppCheck(req) {
  if (!shouldEnforceAttendanceAppCheck()) return;
  const appCheckToken = String(req.get("x-firebase-appcheck") || "").trim();
  if (!appCheckToken) {
    throw new HttpError(401, "missing-app-check");
  }
  try {
    await verifyAppCheckTokenImpl(appCheckToken);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(401, "invalid-app-check");
  }
}

async function assertAuthenticatedRequest(req) {
  await assertAppCheck(req);
  return assertBearerUid(req);
}

async function loadActiveUser(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) throw new HttpError(403, "user-missing");
  const data = snap.data() || {};
  if (data.isActive === false) throw new HttpError(403, "user-inactive");
  return {uid, ...data};
}

function isOperatorRole(role) {
  return ["SUPERADMIN", "ADMIN", "OPERADOR_ASISTENCIA"].includes(role);
}

function isAdminRole(role) {
  return ["SUPERADMIN", "ADMIN"].includes(role);
}

function resolveServerKeyPair() {
  // Prefer secret; tests may set process.env.ATTENDANCE_QR_TEST_SEED.
  const seed = process.env.ATTENDANCE_QR_TEST_SEED ||
    (typeof attendanceQrSigningKey.value === "function"
      ? (() => {
        try {
          return attendanceQrSigningKey.value();
        } catch (_) {
          return "";
        }
      })()
      : "");
  if (!seed || !String(seed).trim()) {
    throw new HttpError(
      503,
      "signing-key-missing",
      "ATTENDANCE_QR_SIGNING_PRIVATE_KEY not configured",
    );
  }
  return cryptoHelpers.keyFromSeedBase64Url(String(seed).trim());
}

function participantsHash(participants) {
  const normalized = participants
    .map((p) => `${p.memberId}|${p.memberDeviceId}|${p.memberPublicKey}|${p.credentialId}|${p.status}`)
    .sort()
    .join("\n");
  return cryptoHelpers.hashSha256Hex(normalized);
}

/**
 * Loads ALL active attendance_member_devices with deterministic pagination.
 * Never silently truncates: throws offline-package-too-large / scan-too-large.
 *
 * @param {FirebaseFirestore.Firestore} [firestore]
 * @param {{pageSize?: number, maxScan?: number}} [opts]
 * @return {Promise<FirebaseFirestore.QueryDocumentSnapshot[]>}
 */
async function loadActiveAttendanceMemberDevices(
  firestore = db,
  {
    pageSize = DEVICE_PAGE_SIZE,
    maxScan = MAX_ACTIVE_DEVICE_SCAN,
  } = {},
) {
  const docs = [];
  let lastDoc = null;
  let pageHasMore = true;
  while (pageHasMore) {
    let query = firestore
      .collection(MEMBER_DEVICES)
      .where("status", "==", "active")
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) {
      pageHasMore = false;
      break;
    }
    for (const doc of snap.docs) {
      docs.push(doc);
      if (docs.length > maxScan) {
        throw new HttpError(
          413,
          "offline-package-scan-too-large",
          `Active device scan exceeded ${maxScan}`,
        );
      }
    }
    if (snap.size < pageSize) {
      pageHasMore = false;
    } else {
      lastDoc = snap.docs[snap.docs.length - 1];
    }
  }
  return docs;
}

/**
 * Batch-loads members by id via Admin getAll (chunked). No per-device N+1.
 * Missing docs are omitted from the map (caller skips those devices).
 *
 * @param {Iterable<string>} memberIds
 * @param {FirebaseFirestore.Firestore} [firestore]
 * @param {{chunkSize?: number}} [opts]
 * @return {Promise<Map<string, object>>}
 */
async function loadMembersByIds(
  memberIds,
  firestore = db,
  {chunkSize = MEMBER_GETALL_CHUNK} = {},
) {
  const unique = [...new Set([...memberIds].map((id) => String(id || "").trim()).filter(Boolean))];
  const map = new Map();
  for (let i = 0; i < unique.length; i += chunkSize) {
    const chunk = unique.slice(i, i + chunkSize);
    const refs = chunk.map((id) => firestore.collection("members").doc(id));
    const snaps = await firestore.getAll(...refs);
    for (const snap of snaps) {
      if (snap.exists) {
        map.set(snap.id, snap.data() || {});
      }
    }
  }
  return map;
}

/**
 * Builds offline package participants from device docs + member map.
 * Preserves multi-device-per-member. Missing members are skipped (no 500).
 * Inactive members are included with status "inactive" (existing policy).
 *
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} deviceDocs
 * @param {Map<string, object>} memberMap
 * @param {object} event
 * @return {object[]}
 */
function buildOfflineParticipants(deviceDocs, memberMap, event) {
  const convocados = Array.isArray(event.miembrosConvocados)
    ? event.miembrosConvocados.map((id) => String(id))
    : [];
  const convocadosSet = convocados.length > 0 ? new Set(convocados) : null;

  const participants = [];
  for (const doc of deviceDocs) {
    const d = doc.data() || {};
    const memberId = String(d.memberId || "");
    if (!memberId) continue;
    if (convocadosSet && !convocadosSet.has(memberId)) continue;

    const m = memberMap.get(memberId);
    if (!m) continue;

    const status = memberIsActive(m) ? "active" : "inactive";
    participants.push({
      memberId,
      memberDeviceId: doc.id,
      memberPublicKey: String(d.publicKey || ""),
      credentialId: String(d.lastCredentialId || ""),
      status,
      displayName: String(m.fullName || `${m.firstName || ""} ${m.lastName || ""}`.trim()),
      memberNumber: String(m.memberNumber || ""),
      workerCode: String(m.workerCode || ""),
    });
  }
  return participants;
}

/**
 * Asserts package participant count / JSON size are within operational bounds.
 * Never truncates — fails closed with offline-package-too-large.
 */
function assertOfflinePackageSize(participants) {
  const count = participants.length;
  if (count > MAX_OFFLINE_PACKAGE_DEVICES) {
    const err = new HttpError(
      413,
      "offline-package-too-large",
      `Participant device count ${count} exceeds max ${MAX_OFFLINE_PACKAGE_DEVICES}`,
    );
    err.participantDeviceCount = count;
    throw err;
  }
  const jsonBytes = Buffer.byteLength(JSON.stringify(participants), "utf8");
  if (jsonBytes > MAX_PARTICIPANTS_JSON_BYTES) {
    const err = new HttpError(
      413,
      "offline-package-too-large",
      `Participants JSON ${jsonBytes} bytes exceeds max ${MAX_PARTICIPANTS_JSON_BYTES}`,
    );
    err.participantDeviceCount = count;
    throw err;
  }
}

/**
 * Full pipeline: paginate devices → filter convocados → batch members → participants.
 */
async function collectOfflinePackageParticipants(event, firestore = db) {
  const deviceDocs = await loadActiveAttendanceMemberDevices(firestore);
  const convocados = Array.isArray(event.miembrosConvocados)
    ? event.miembrosConvocados.map((id) => String(id))
    : [];
  const convocadosSet = convocados.length > 0 ? new Set(convocados) : null;

  const candidateDocs = [];
  const memberIds = [];
  for (const doc of deviceDocs) {
    const memberId = String((doc.data() || {}).memberId || "");
    if (!memberId) continue;
    if (convocadosSet && !convocadosSet.has(memberId)) continue;
    candidateDocs.push(doc);
    memberIds.push(memberId);
  }

  const memberMap = await loadMembersByIds(memberIds, firestore);
  const participants = buildOfflineParticipants(candidateDocs, memberMap, event);
  assertOfflinePackageSize(participants);
  return participants;
}

function jsonOk(res, body) {
  res.status(200).json({ok: true, ...body});
}

function jsonErr(res, error) {
  const status = error.status || 500;
  if (status >= 500) logger.error("attendance-qr error", error);
  const body = {
    ok: false,
    code: error.code || "internal",
    message: error.message || "error",
  };
  if (typeof error.participantDeviceCount === "number") {
    body.participantDeviceCount = error.participantDeviceCount;
  }
  res.status(status).json(body);
}

/**
 * POST /api/attendance-enroll-member-device
 * Body: { deviceId, publicKey, platform, deviceLabel? }
 */
async function handleEnrollMemberDevice(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    await enforceNamedRateLimit("att-enroll", uid, ENROLL_LIMIT);
    const user = await loadActiveUser(uid);
    const memberId = String(user.memberId || "").trim();
    if (!memberId) throw new HttpError(403, "missing-memberId");

    const memberSnap = await db.collection("members").doc(memberId).get();
    if (!memberSnap.exists) throw new HttpError(404, "member-missing");
    if (!memberIsActive(memberSnap.data())) {
      throw new HttpError(403, "member-inactive");
    }

    const deviceId = String(req.body?.deviceId || "").trim();
    const publicKey = String(req.body?.publicKey || "").trim();
    const platform = String(req.body?.platform || "unknown").trim();
    if (!deviceId || deviceId.length > 128) {
      throw new HttpError(400, "invalid-deviceId");
    }
    if (!publicKey || publicKey.length < 40) {
      throw new HttpError(400, "invalid-publicKey");
    }
    // Validate public key parses
    cryptoHelpers.publicKeyFromBase64Url(publicKey);

    const ref = db.collection(MEMBER_DEVICES).doc(deviceId);
    await ref.set({
      deviceId,
      uid,
      memberId,
      publicKey,
      algorithm: "Ed25519",
      keyVersion: KEY_VERSION,
      platform,
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      revokedAt: null,
      createdBy: uid,
    }, {merge: true});

    jsonOk(res, {deviceId, memberId, status: "active"});
  } catch (error) {
    jsonErr(res, error);
  }
}

/**
 * POST /api/attendance-prepare-offline-credential
 * Body: { deviceId, preparedAtClient?, preparedLatitude?, ... }
 */
async function handlePrepareOfflineCredential(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    await enforceNamedRateLimit("att-cred", uid, PREP_LIMIT);
    const user = await loadActiveUser(uid);
    const memberId = String(user.memberId || "").trim();
    if (!memberId) throw new HttpError(403, "missing-memberId");

    const deviceId = String(req.body?.deviceId || "").trim();
    const deviceSnap = await db.collection(MEMBER_DEVICES).doc(deviceId).get();
    if (!deviceSnap.exists) throw new HttpError(404, "device-missing");
    const device = deviceSnap.data() || {};
    if (device.uid !== uid) throw new HttpError(403, "device-owner-mismatch");
    if (device.status !== "active") throw new HttpError(403, "device-revoked");
    if (device.memberId !== memberId) throw new HttpError(403, "member-mismatch");

    const memberSnap = await db.collection("members").doc(memberId).get();
    if (!memberSnap.exists || !memberIsActive(memberSnap.data())) {
      throw new HttpError(403, "member-inactive");
    }

    const serverKey = resolveServerKeyPair();
    const nowMs = Date.now();
    const credentialId = cryptoHelpers.secureNonce(16);
    const expiresAt = nowMs + CREDENTIAL_MAX_MS;
    const fields = {
      v: "2",
      type: "SATT2CRED",
      credentialId,
      uid,
      memberId,
      memberDeviceId: deviceId,
      memberPublicKey: String(device.publicKey),
      issuedAtServer: String(nowMs),
      expiresAt: String(expiresAt),
      keyVersion: KEY_VERSION,
    };
    const canonical = cryptoHelpers.canonicalCredentialPayload(fields);
    const signature = cryptoHelpers.signUtf8(canonical, serverKey.privateKey);

    const audit = {
      credentialPreparedAtServer: nowMs,
      credentialPreparedAtClient: req.body?.preparedAtClient ?? null,
      locationPermission: req.body?.locationPermission ?? null,
      preparedLatitude: req.body?.preparedLatitude ?? null,
      preparedLongitude: req.body?.preparedLongitude ?? null,
      preparedAccuracyMeters: req.body?.preparedAccuracyMeters ?? null,
      preparedLocationCapturedAt: req.body?.preparedLocationCapturedAt ?? null,
    };

    await deviceSnap.ref.set({
      lastSeenAt: FieldValue.serverTimestamp(),
      lastCredentialId: credentialId,
      lastCredentialExpiresAt: expiresAt,
    }, {merge: true});

    jsonOk(res, {
      credential: {
        ...fields,
        signature,
        serverPublicKey: serverKey.publicKeyBase64Url,
        audit,
      },
    });
  } catch (error) {
    jsonErr(res, error);
  }
}

/**
 * POST /api/attendance-prepare-offline-event
 * Body: { eventId, scannerId }
 */
async function handlePrepareOfflineEvent(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    await enforceNamedRateLimit("att-pkg", uid, PREP_LIMIT);
    const user = await loadActiveUser(uid);
    if (!isOperatorRole(user.role)) throw new HttpError(403, "forbidden");

    const eventId = String(req.body?.eventId || "").trim();
    const scannerId = String(req.body?.scannerId || "").trim();
    if (!eventId || !scannerId) throw new HttpError(400, "missing-fields");

    const scannerSnap = await db.collection(SCANNER_DEVICES).doc(scannerId).get();
    if (!scannerSnap.exists) throw new HttpError(404, "scanner-missing");
    const scanner = scannerSnap.data() || {};
    if (scanner.status !== "active") throw new HttpError(403, "scanner-revoked");
    if (scanner.assignedUserId && scanner.assignedUserId !== uid && !isAdminRole(user.role)) {
      throw new HttpError(403, "scanner-not-assigned");
    }

    const eventSnap = await db.collection("attendance_events").doc(eventId).get();
    if (!eventSnap.exists) throw new HttpError(404, "event-missing");
    const event = eventSnap.data() || {};

    const participants = await collectOfflinePackageParticipants(event, db);

    const serverKey = resolveServerKeyPair();
    const nowMs = Date.now();
    const packageId = cryptoHelpers.secureNonce(16);
    const endAt = Number(event.fechaFin || event.fecha || nowMs) || nowMs;
    const startAt = Number(event.fecha || nowMs) || nowMs;
    const expiresAt = Math.max(endAt, nowMs) + 2 * 60 * 60 * 1000; // +2h margin
    const pHash = participantsHash(participants);

    const fields = {
      v: "2",
      type: "SATT2PKG",
      packageId,
      eventId,
      eventName: String(event.nombre || ""),
      startAt: String(startAt),
      endAt: String(endAt),
      issuedAtServer: String(nowMs),
      expiresAt: String(expiresAt),
      serverTimeAtPreparation: String(nowMs),
      scannerId,
      scannerPublicKey: String(scanner.publicKey || ""),
      geofenceEnabled: event.geofenceEnabled === true ? "1" : "0",
      latitude: event.latitude != null ? String(event.latitude) : "",
      longitude: event.longitude != null ? String(event.longitude) : "",
      geofenceRadiusMeters: String(event.geofenceRadiusMeters || 150),
      participantsHash: pHash,
      keyVersion: KEY_VERSION,
    };
    const canonical = cryptoHelpers.canonicalPackagePayload(fields);
    const signature = cryptoHelpers.signUtf8(canonical, serverKey.privateKey);

    jsonOk(res, {
      package: {
        packageId,
        eventId,
        eventName: fields.eventName,
        startAt,
        endAt,
        issuedAtServer: nowMs,
        expiresAt,
        serverTimeAtPreparation: nowMs,
        scannerId,
        scannerPublicKey: fields.scannerPublicKey,
        geofence: {
          enabled: event.geofenceEnabled === true,
          latitude: event.latitude ?? null,
          longitude: event.longitude ?? null,
          radiusMeters: Number(event.geofenceRadiusMeters || 150),
          requireScannerLocation: event.requireScannerLocation === true,
        },
        participants,
        participantsHash: pHash,
        keyVersion: KEY_VERSION,
        signature,
        serverPublicKey: serverKey.publicKeyBase64Url,
      },
    });
  } catch (error) {
    jsonErr(res, error);
  }
}

/**
 * POST /api/attendance-register-scanner-device
 * Body: { scannerId, publicKey, platform, deviceLabel?, assignedUserId?, approve? }
 *
 * OPERADOR puede registrar como `pending`.
 * Solo ADMIN/SUPERADMIN puede activar con approve=true (o vía approve endpoint).
 */
async function handleRegisterScannerDevice(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    const user = await loadActiveUser(uid);
    if (!isOperatorRole(user.role)) throw new HttpError(403, "forbidden");

    const scannerId = String(req.body?.scannerId || "").trim();
    const publicKey = String(req.body?.publicKey || "").trim();
    if (!scannerId || !publicKey) throw new HttpError(400, "missing-fields");
    cryptoHelpers.publicKeyFromBase64Url(publicKey);

    const wantApprove = req.body?.approve === true;
    if (wantApprove && !isAdminRole(user.role)) {
      throw new HttpError(403, "only-admin-can-approve-scanner");
    }

    const status = wantApprove && isAdminRole(user.role) ? "active" : "pending";
    const payload = {
      scannerId,
      publicKey,
      algorithm: "Ed25519",
      status,
      assignedUserId: req.body?.assignedUserId || uid,
      deviceLabel: req.body?.deviceLabel || "",
      platform: req.body?.platform || "unknown",
      createdAt: FieldValue.serverTimestamp(),
      revokedAt: null,
    };
    if (status === "active") {
      payload.approvedAt = FieldValue.serverTimestamp();
      payload.approvedBy = uid;
    } else {
      payload.approvedAt = null;
      payload.approvedBy = null;
    }

    await db.collection(SCANNER_DEVICES).doc(scannerId).set(payload, {merge: true});
    jsonOk(res, {scannerId, status});
  } catch (error) {
    jsonErr(res, error);
  }
}

/**
 * POST /api/attendance-approve-scanner-device
 * Body: { scannerId }
 * Solo ADMIN/SUPERADMIN.
 */
async function handleApproveScannerDevice(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    const user = await loadActiveUser(uid);
    if (!isAdminRole(user.role)) throw new HttpError(403, "forbidden");

    const scannerId = String(req.body?.scannerId || "").trim();
    if (!scannerId) throw new HttpError(400, "missing-scannerId");

    const ref = db.collection(SCANNER_DEVICES).doc(scannerId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpError(404, "scanner-missing");
    if (snap.data()?.status === "revoked") {
      throw new HttpError(403, "scanner-revoked");
    }

    await ref.set({
      status: "active",
      approvedAt: FieldValue.serverTimestamp(),
      approvedBy: uid,
    }, {merge: true});

    jsonOk(res, {scannerId, status: "active"});
  } catch (error) {
    jsonErr(res, error);
  }
}

function attendanceDocId(eventId, memberId) {
  return Buffer.from(`${eventId}_${memberId}`, "utf8").toString("base64url");
}

/**
 * POST /api/attendance-sync-offline-batch
 * Body: { scannerId, receipts: [...] }
 */
async function handleSyncOfflineBatch(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    await enforceNamedRateLimit("att-sync", uid, SYNC_LIMIT);
    const user = await loadActiveUser(uid);
    if (!isOperatorRole(user.role)) throw new HttpError(403, "forbidden");

    const scannerId = String(req.body?.scannerId || "").trim();
    const receipts = Array.isArray(req.body?.receipts) ? req.body.receipts : [];
    if (!scannerId) throw new HttpError(400, "missing-scannerId");
    if (receipts.length === 0) throw new HttpError(400, "empty-batch");
    if (receipts.length > BATCH_MAX) throw new HttpError(400, "batch-too-large");

    const scannerSnap = await db.collection(SCANNER_DEVICES).doc(scannerId).get();
    if (!scannerSnap.exists || scannerSnap.data()?.status !== "active") {
      throw new HttpError(403, "scanner-revoked");
    }
    const scannerPub = String(scannerSnap.data().publicKey || "");

    const results = [];
    for (const raw of receipts) {
      const result = await syncOneReceipt({
        raw,
        scannerId,
        scannerPub,
        operatorUid: uid,
      });
      results.push(result);
    }

    jsonOk(res, {results});
  } catch (error) {
    jsonErr(res, error);
  }
}

async function syncOneReceipt({raw, scannerId, scannerPub, operatorUid}) {
  const localReceiptId = String(raw?.localReceiptId || "");
  try {
    if (!localReceiptId) {
      return {localReceiptId, status: "rejected", code: "missing-id"};
    }

    const eventId = String(raw.eventId || "");
    const memberId = String(raw.memberId || "");
    const memberDeviceId = String(raw.memberDeviceId || "");
    if (!eventId || !memberId || !memberDeviceId) {
      return {localReceiptId, status: "rejected", code: "missing-fields"};
    }
    if (String(raw.scannerId) !== scannerId) {
      return {localReceiptId, status: "rejected", code: "wrong-scanner"};
    }

    const receiptFields = {
      v: "2",
      type: "SATT2RCPT",
      localReceiptId,
      eventId,
      memberId,
      memberDeviceId,
      scannerId,
      challengeId: String(raw.challengeId || ""),
      challengeNonce: String(raw.challengeNonce || ""),
      responseNonce: String(raw.responseNonce || ""),
      memberSignature: String(raw.memberSignature || ""),
      packageId: String(raw.packageId || ""),
      scannedAtTrusted: String(raw.scannedAtTrusted || ""),
      scannedAtDevice: String(raw.scannedAtDevice || ""),
      scanLatitude: raw.scanLatitude != null ? String(raw.scanLatitude) : "",
      scanLongitude: raw.scanLongitude != null ? String(raw.scanLongitude) : "",
      scanAccuracy: raw.scanAccuracy != null ? String(raw.scanAccuracy) : "",
      locationStatus: String(raw.locationStatus || "unknown"),
    };

    const receiptCanonical = cryptoHelpers.canonicalReceiptPayload(receiptFields);
    const scannerSigOk = cryptoHelpers.verifyUtf8(
      receiptCanonical,
      String(raw.scannerSignature || ""),
      scannerPub,
    );
    if (!scannerSigOk) {
      return {localReceiptId, status: "rejected", code: "invalid-scanner-signature"};
    }

    const deviceSnap = await db.collection(MEMBER_DEVICES).doc(memberDeviceId).get();
    if (!deviceSnap.exists) {
      return {localReceiptId, status: "rejected", code: "device-missing"};
    }
    const device = deviceSnap.data() || {};
    if (device.status === "revoked") {
      return {localReceiptId, status: "rejected", code: "device-revoked"};
    }
    if (String(device.memberId) !== memberId) {
      return {localReceiptId, status: "rejected", code: "member-mismatch"};
    }

    const memberSnap = await db.collection("members").doc(memberId).get();
    if (!memberSnap.exists) {
      return {localReceiptId, status: "rejected", code: "member-missing"};
    }
    if (!memberIsActive(memberSnap.data())) {
      return {localReceiptId, status: "review", code: "member-inactive-at-sync"};
    }

    // Verify member signature (SATT2R challenge-response or SATT2M dynamic QR).
    const isMemberQr =
      String(raw.qrMode || "") === "SATT2M" ||
      String(raw.challengeNonce || "") === "SATT2M";
    let memberSigOk = false;
    if (isMemberQr) {
      const memberFields = {
        v: "2",
        type: "SATT2M",
        eventId,
        memberDeviceId,
        credentialId: String(raw.credentialId || device.lastCredentialId || ""),
        timeWindow: String(raw.timeWindow || raw.challengeId || ""),
        issuedAt: String(raw.responseIssuedAt || ""),
        expiresAt: String(raw.memberQrExpiresAt || ""),
        responseNonce: receiptFields.responseNonce,
        protocolVersion: "2",
      };
      const memberCanonical = cryptoHelpers.canonicalMemberQrPayload(memberFields);
      memberSigOk = cryptoHelpers.verifyUtf8(
        memberCanonical,
        String(raw.memberSignature || ""),
        String(device.publicKey || ""),
      );
    } else {
      const responseFields = {
        v: "2",
        type: "SATT2R",
        eventId,
        scannerId,
        challengeId: receiptFields.challengeId,
        challengeNonce: receiptFields.challengeNonce,
        memberDeviceId,
        credentialId: String(raw.credentialId || device.lastCredentialId || ""),
        responseNonce: receiptFields.responseNonce,
        issuedAt: String(raw.responseIssuedAt || raw.scannedAtDevice || ""),
        protocolVersion: "2",
      };
      const responseCanonical = cryptoHelpers.canonicalResponsePayload(responseFields);
      memberSigOk = cryptoHelpers.verifyUtf8(
        responseCanonical,
        String(raw.memberSignature || ""),
        String(device.publicKey || ""),
      );
    }
    if (!memberSigOk) {
      return {localReceiptId, status: "rejected", code: "invalid-member-signature"};
    }

    const docId = attendanceDocId(eventId, memberId);
    const ref = db
      .collection("attendance_events")
      .doc(eventId)
      .collection("asistencias")
      .doc(docId);

    const outcome = await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      if (existing.exists) {
        return {status: "already_synced", code: "duplicate"};
      }
      tx.set(ref, {
        id: docId,
        eventoId: eventId,
        personaId: memberId,
        asistio: true,
        metodoRegistro: METODO_SECURE,
        fechaRegistro: FieldValue.serverTimestamp(),
        registeredAtServer: FieldValue.serverTimestamp(),
        offlineScannedAt: Number(raw.scannedAtTrusted) || null,
        registradoPor: operatorUid,
        scannerId,
        memberDeviceId,
        receiptId: localReceiptId,
        packageId: String(raw.packageId || ""),
        securityVersion: 2,
        location: {
          latitude: raw.scanLatitude ?? null,
          longitude: raw.scanLongitude ?? null,
          accuracy: raw.scanAccuracy ?? null,
          status: raw.locationStatus || "unknown",
        },
      });
      return {status: "synced", code: "created"};
    });

    return {localReceiptId, ...outcome};
  } catch (error) {
    logger.error("syncOneReceipt", error);
    return {
      localReceiptId,
      status: "rejected",
      code: error.code || "sync-error",
    };
  }
}

function createAttendanceQrHttpsOptions(extra = {}) {
  return {
    region: "us-central1",
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 60,
    ...extra,
  };
}

const attendanceEnrollMemberDevice = onRequest(
  createAttendanceQrHttpsOptions(),
  handleEnrollMemberDevice,
);

const attendancePrepareOfflineCredential = onRequest(
  createAttendanceQrHttpsOptions({secrets: [attendanceQrSigningKey]}),
  handlePrepareOfflineCredential,
);

const attendancePrepareOfflineEvent = onRequest(
  createAttendanceQrHttpsOptions({secrets: [attendanceQrSigningKey]}),
  handlePrepareOfflineEvent,
);

const attendanceRegisterScannerDevice = onRequest(
  createAttendanceQrHttpsOptions(),
  handleRegisterScannerDevice,
);

const attendanceApproveScannerDevice = onRequest(
  createAttendanceQrHttpsOptions(),
  handleApproveScannerDevice,
);

const attendanceSyncOfflineBatch = onRequest(
  // Sync revalida firmas member/scanner; no usa la signing key del servidor.
  // Evitar exigir el secret aquí permite Emulator HTTP sin secretos reales.
  createAttendanceQrHttpsOptions({
    timeoutSeconds: 120,
  }),
  handleSyncOfflineBatch,
);

module.exports = {
  attendanceEnrollMemberDevice,
  attendancePrepareOfflineCredential,
  attendancePrepareOfflineEvent,
  attendanceRegisterScannerDevice,
  attendanceApproveScannerDevice,
  attendanceSyncOfflineBatch,
  // test exports
  _test: {
    handleEnrollMemberDevice,
    handlePrepareOfflineCredential,
    handlePrepareOfflineEvent,
    handleRegisterScannerDevice,
    handleApproveScannerDevice,
    handleSyncOfflineBatch,
    syncOneReceipt,
    participantsHash,
    attendanceDocId,
    METODO_SECURE,
    shouldEnforceAttendanceAppCheck,
    assertAppCheck,
    assertBearerUid,
    assertAuthenticatedRequest,
    setVerifyAppCheckTokenForTests,
    resetVerifyAppCheckTokenForTests,
    HttpError,
    loadActiveAttendanceMemberDevices,
    loadMembersByIds,
    buildOfflineParticipants,
    collectOfflinePackageParticipants,
    assertOfflinePackageSize,
    DEVICE_PAGE_SIZE,
    MEMBER_GETALL_CHUNK,
    MAX_OFFLINE_PACKAGE_DEVICES,
    MAX_ACTIVE_DEVICE_SCAN,
    MAX_PARTICIPANTS_JSON_BYTES,
  },
};
