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
const PARTICIPANT_HASH_KEYS = [
  "memberId",
  "memberDeviceId",
  "memberPublicKey",
  "credentialId",
  "status",
  "displayName",
  "memberNumber",
  "workerCode",
];

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

/**
 * Confirmed non-negative integer asistenciaCount (never coerce missing → 0).
 * @param {*} value
 * @return {boolean}
 */
function isConfirmedAsistenciaCount(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

const ENROLL_LIMIT = {maximum: 10, windowMs: 60 * 60 * 1000};
const PREP_LIMIT = {maximum: 30, windowMs: 60 * 60 * 1000};
const SYNC_LIMIT = {maximum: 60, windowMs: 60 * 60 * 1000};
const SCANNER_REGISTER_LIMIT = {maximum: 30, windowMs: 60 * 60 * 1000};
const SCANNER_APPROVE_LIMIT = {maximum: 60, windowMs: 60 * 60 * 1000};
const DELETE_EVENT_LIMIT = {maximum: 20, windowMs: 60 * 60 * 1000};

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

async function enforceNamedRateLimit(bucket, key, limit, firestore = db) {
  const ref = firestore.collection(RATE_LIMIT_COLLECTION).doc(`${bucket}-${hash(key)}`);
  const nowMs = Date.now();
  await firestore.runTransaction(async (tx) => {
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

async function loadActiveUser(uid, firestore = db) {
  const snap = await firestore.collection("users").doc(uid).get();
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

function isSuperAdminRole(role) {
  return role === "SUPERADMIN";
}

function assertScannerAssignment(scanner, uid, role) {
  if (!isAdminRole(role) && scanner.assignedUserId !== uid) {
    throw new HttpError(403, "scanner-not-assigned");
  }
}

function scannerIdFromInput(value) {
  if (typeof value !== "string" || value.length === 0 || value.length > 128 ||
      /[^A-Za-z0-9_-]/.test(value)) {
    throw new HttpError(400, "invalid-scannerId");
  }
  return value;
}

function assertScannerRequestBody(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError(400, "invalid-scanner-request");
  }
  if (Buffer.byteLength(JSON.stringify(body), "utf8") > 4096) {
    throw new HttpError(413, "scanner-request-too-large");
  }
}

function scannerMetadataString(value, maximum, fallback, code) {
  if (value === undefined) return fallback;
  if (typeof value !== "string" || value.length > maximum ||
      /[\u0000-\u001f\u007f]/.test(value)) {
    throw new HttpError(400, code);
  }
  return value.trim();
}

function parseScannerRegistration(body, uid) {
  assertScannerRequestBody(body);
  const scannerId = scannerIdFromInput(body.scannerId);
  const publicKey = assertCanonicalPublicKey(body.publicKey, 400, "invalid-publicKey");
  if (body.approve !== undefined && typeof body.approve !== "boolean") {
    throw new HttpError(400, "invalid-approve");
  }
  const assignmentExplicit = Object.prototype.hasOwnProperty.call(body, "assignedUserId");
  const assignedUserId = assignmentExplicit ? body.assignedUserId : uid;
  if (typeof assignedUserId !== "string" || assignedUserId.length === 0 ||
      assignedUserId.length > 128 || assignedUserId !== assignedUserId.trim() ||
      /[\/\u0000-\u001f\u007f]/.test(assignedUserId)) {
    throw new HttpError(400, "invalid-assignedUserId");
  }
  return {
    scannerId,
    publicKey,
    platform: scannerMetadataString(body.platform, 32, "unknown", "invalid-platform"),
    deviceLabel: scannerMetadataString(body.deviceLabel, 128, "", "invalid-deviceLabel"),
    assignedUserId,
    assignmentExplicit,
    approve: body.approve === true,
  };
}

function parseScannerApproval(body) {
  assertScannerRequestBody(body);
  return {scannerId: scannerIdFromInput(body.scannerId)};
}

function activeMemberIdForUser(user) {
  const memberId = String(user?.memberId || "").trim();
  if (!memberId) throw new HttpError(403, "missing-memberId");
  return memberId;
}

async function loadRequiredActiveMember(firestore, memberId) {
  const memberSnap = await firestore.collection("members").doc(memberId).get();
  if (!memberSnap.exists) throw new HttpError(404, "member-missing");
  if (!memberIsActive(memberSnap.data())) {
    throw new HttpError(403, "member-inactive");
  }
  return memberSnap.data() || {};
}

function eventAllowsMemberQr(event, memberId) {
  if (event.archivado === true) return false;
  if (event.activo !== true) return false;
  const estado = String(event.estado || "").trim().toLowerCase();
  if (estado === "finalizado" || estado === "cancelado") return false;

  const convocados = Array.isArray(event.miembrosConvocados)
    ? event.miembrosConvocados.map((id) => String(id))
    : [];
  return convocados.length === 0 || convocados.includes(memberId);
}

function sanitizeMemberQrEvent(id, event) {
  const sanitized = {
    id,
    nombre: String(event.nombre || ""),
    fecha: Number(event.fecha || 0) || 0,
    lugar: String(event.lugar || ""),
    tipo: String(event.tipo || "reunion"),
    activo: event.activo === true,
    estado: String(event.estado || "programado"),
    secureQrMode: String(event.secureQrMode || "dynamic_member_qr"),
  };
  if (event.fechaFin != null) {
    sanitized.fechaFin = Number(event.fechaFin || 0) || 0;
  }
  return sanitized;
}

function sortMemberQrEventsDesc(a, b) {
  return Number(b.fecha || 0) - Number(a.fecha || 0);
}

function serverKeyPairFromSecretValue(seed) {
  if (seed == null || seed === "") {
    throw new HttpError(
      503,
      "signing-key-missing",
      "Attendance signing key is not configured",
    );
  }
  try {
    return cryptoHelpers.keyFromSeedBase64Url(seed);
  } catch (_) {
    throw new HttpError(
      503,
      "signing-key-invalid",
      "Attendance signing key configuration is invalid",
    );
  }
}

function emulatorTestSigningSeed(env = process.env) {
  const isEmulator =
    String(env.FUNCTIONS_EMULATOR || "") === "true" ||
    Boolean(env.FIRESTORE_EMULATOR_HOST) ||
    Boolean(env.FIREBASE_AUTH_EMULATOR_HOST);
  return isEmulator ? env.ATTENDANCE_QR_TEST_SEED : undefined;
}

function resolveServerKeyPair() {
  // Test seed injection is accepted only in an explicitly emulated process.
  const seed = emulatorTestSigningSeed() ||
    (typeof attendanceQrSigningKey.value === "function"
      ? (() => {
        try {
          return attendanceQrSigningKey.value();
        } catch (_) {
          return undefined;
        }
      })()
      : undefined);
  return serverKeyPairFromSecretValue(seed);
}

function assertCanonicalPublicKey(value, status, code) {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpError(status, code);
  }
  try {
    cryptoHelpers.publicKeyFromBase64Url(value);
  } catch (_) {
    throw new HttpError(status, code);
  }
  return value;
}

function participantsHash(participants) {
  const normalized = participants
    .map((participant) => PARTICIPANT_HASH_KEYS.map((key) => {
      const value = String(participant?.[key] ?? "");
      return `${Buffer.byteLength(value, "utf8")}:${value}`;
    }).join("|"))
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
    const publicKey = req.body?.publicKey;
    const platform = String(req.body?.platform || "unknown").trim();
    if (!deviceId || deviceId.length > 128) {
      throw new HttpError(400, "invalid-deviceId");
    }
    assertCanonicalPublicKey(publicKey, 400, "invalid-publicKey");

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

    const memberPublicKey = assertCanonicalPublicKey(
      device.publicKey,
      409,
      "device-key-invalid",
    );
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
      memberPublicKey,
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
 * POST /api/attendance-list-member-qr-events
 * Body: {}
 *
 * Member endpoint. Reads attendance_events with Admin SDK and returns only the
 * minimal metadata required to generate/select a member QR. The client-supplied
 * body is intentionally ignored for member scoping.
 */
async function handleListMemberQrEvents(req, res, deps = {}) {
  const firestore = deps.firestore || db;
  const authenticate = deps.authenticate || assertAuthenticatedRequest;
  const rateLimit = deps.enforceRateLimit || enforceNamedRateLimit;

  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await authenticate(req);
    await rateLimit("att-list-events", uid, PREP_LIMIT, firestore);

    const user = await loadActiveUser(uid, firestore);
    const memberId = activeMemberIdForUser(user);
    await loadRequiredActiveMember(firestore, memberId);

    const snap = await firestore
      .collection("attendance_events")
      .where("activo", "==", true)
      .get();

    const events = snap.docs
      .filter((doc) => eventAllowsMemberQr(doc.data() || {}, memberId))
      .map((doc) => sanitizeMemberQrEvent(doc.id, doc.data() || {}))
      .sort(sortMemberQrEventsDesc);

    jsonOk(res, {events});
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
    assertScannerAssignment(scanner, uid, user.role);

    const scannerPublicKey = assertCanonicalPublicKey(
      scanner.publicKey,
      409,
      "scanner-key-invalid",
    );

    const eventSnap = await db.collection("attendance_events").doc(eventId).get();
    if (!eventSnap.exists) throw new HttpError(404, "event-missing");
    const event = eventSnap.data() || {};
    if (event.archivado === true) {
      throw new HttpError(403, "event-archived");
    }

    const participants = await collectOfflinePackageParticipants(event, db);
    for (const participant of participants) {
      assertCanonicalPublicKey(
        participant.memberPublicKey,
        409,
        "participant-key-invalid",
      );
    }

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
      eventName: String(event.nombre || "").trim(),
      startAt: String(startAt),
      endAt: String(endAt),
      issuedAtServer: String(nowMs),
      expiresAt: String(expiresAt),
      serverTimeAtPreparation: String(nowMs),
      scannerId,
      scannerPublicKey,
      geofenceEnabled: event.geofenceEnabled === true ? "1" : "0",
      latitude: event.latitude != null ? String(event.latitude) : "",
      longitude: event.longitude != null ? String(event.longitude) : "",
      geofenceRadiusMeters: String(event.geofenceRadiusMeters || 150),
      requireScannerLocation: event.requireScannerLocation === true ? "1" : "0",
      participantsHash: pHash,
      keyVersion: KEY_VERSION,
    };
    const canonical = cryptoHelpers.canonicalPackagePayload(fields);
    const signature = cryptoHelpers.signUtf8(canonical, serverKey.privateKey);

    jsonOk(res, {
      package: {
        v: fields.v,
        type: fields.type,
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
async function registerScannerDeviceRecord({
  firestore,
  actorUid,
  actorRole,
  scannerId,
  publicKey,
  platform,
  deviceLabel,
  assignedUserId,
  assignmentExplicit,
  approve,
  timestampFactory = () => FieldValue.serverTimestamp(),
}) {
  if (!isOperatorRole(actorRole)) throw new HttpError(403, "forbidden");
  if (approve && !isAdminRole(actorRole)) {
    throw new HttpError(403, "only-admin-can-approve-scanner");
  }

  const targetUserId = String(assignedUserId || actorUid).trim();
  if (!targetUserId) throw new HttpError(400, "invalid-assignedUserId");
  if (!isAdminRole(actorRole) && targetUserId !== actorUid) {
    throw new HttpError(403, "scanner-assignment-forbidden");
  }

  const ref = firestore.collection(SCANNER_DEVICES).doc(scannerId);
  return firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const existing = snap.data() || {};
      if (existing.status === "revoked") {
        throw new HttpError(403, "scanner-revoked");
      }
      if (existing.publicKey !== publicKey) {
        throw new HttpError(409, "scanner-key-mismatch");
      }

      const existingAssignment = String(existing.assignedUserId || "").trim();
      if (!isAdminRole(actorRole) && existingAssignment !== actorUid) {
        throw new HttpError(403, "scanner-assignment-forbidden");
      }
      if (assignmentExplicit && existingAssignment !== targetUserId) {
        throw new HttpError(403, "scanner-assignment-forbidden");
      }
      if (!["pending", "active"].includes(existing.status)) {
        throw new HttpError(409, "scanner-status-invalid");
      }

      // Identity, assignment, approval and status are immutable on repeat
      // registration. Approval/revocation use their dedicated flows.
      return {scannerId, status: existing.status};
    }

    const status = approve && isAdminRole(actorRole) ? "active" : "pending";
    const now = timestampFactory();
    const payload = {
      scannerId,
      publicKey,
      algorithm: "Ed25519",
      status,
      assignedUserId: targetUserId,
      deviceLabel,
      platform,
      createdAt: now,
      revokedAt: null,
      approvedAt: status === "active" ? now : null,
      approvedBy: status === "active" ? actorUid : null,
    };
    tx.set(ref, payload);
    return {scannerId, status};
  });
}

async function handleRegisterScannerDevice(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    const user = await loadActiveUser(uid);

    if (!isOperatorRole(user.role)) throw new HttpError(403, "forbidden");
    const fields = parseScannerRegistration(req.body, uid);
    await enforceNamedRateLimit("att-scanner-register", uid, SCANNER_REGISTER_LIMIT);
    const result = await registerScannerDeviceRecord({
      firestore: db,
      actorUid: uid,
      actorRole: user.role,
      ...fields,
    });
    jsonOk(res, result);
  } catch (error) {
    jsonErr(res, error);
  }
}

/**
 * POST /api/attendance-approve-scanner-device
 * Body: { scannerId }
 * Solo ADMIN/SUPERADMIN.
 */
async function approveScannerDeviceRecord({
  firestore,
  actorUid,
  actorRole,
  scannerId,
  timestampFactory = () => FieldValue.serverTimestamp(),
}) {
  if (!isAdminRole(actorRole)) {
    throw new HttpError(403, "only-admin-can-approve-scanner");
  }

  const ref = firestore.collection(SCANNER_DEVICES).doc(scannerId);
  return firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpError(404, "scanner-missing");
    const existing = snap.data() || {};
    if (existing.status === "revoked") {
      throw new HttpError(403, "scanner-revoked");
    }
    if (existing.status === "active") {
      return {scannerId, status: "active"};
    }
    if (existing.status !== "pending") {
      throw new HttpError(409, "scanner-status-invalid");
    }

    tx.update(ref, {
      status: "active",
      approvedAt: timestampFactory(),
      approvedBy: actorUid,
    });
    return {scannerId, status: "active"};
  });
}

async function handleApproveScannerDevice(req, res) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const uid = await assertAuthenticatedRequest(req);
    const user = await loadActiveUser(uid);

    if (!isAdminRole(user.role)) {
      throw new HttpError(403, "only-admin-can-approve-scanner");
    }
    const {scannerId} = parseScannerApproval(req.body);
    await enforceNamedRateLimit("att-scanner-approve", uid, SCANNER_APPROVE_LIMIT);
    const result = await approveScannerDeviceRecord({
      firestore: db,
      actorUid: uid,
      actorRole: user.role,
      scannerId,
    });
    jsonOk(res, result);
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
    assertScannerAssignment(scannerSnap.data(), uid, user.role);
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

    // Archive policy applies only after cryptographic validation succeeds.
    const eventSnap = await db.collection("attendance_events").doc(eventId).get();
    if (!eventSnap.exists) {
      return {localReceiptId, status: "rejected", code: "event-missing"};
    }
    if (eventSnap.data()?.archivado === true) {
      return {localReceiptId, status: "review", code: "event-archived"};
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
      const eventRef = db.collection("attendance_events").doc(eventId);
      const eventLive = await tx.get(eventRef);
      if (!eventLive.exists) {
        return {status: "rejected", code: "event-missing"};
      }
      const liveData = eventLive.data() || {};
      if (liveData.archivado === true) {
        return {status: "review", code: "event-archived"};
      }
      // Fail-closed: Admin SDK bypasses Rules; never invent count for legacy.
      if (!isConfirmedAsistenciaCount(liveData.asistenciaCount)) {
        return {status: "rejected", code: "legacy-count-missing"};
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
      tx.update(eventRef, {
        asistenciaCount: FieldValue.increment(1),
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

/**
 * POST /api/attendance-delete-event
 * Body: { eventId }
 *
 * SUPERADMIN only. Hard delete is backend-only (Rules deny client delete).
 * Uses asistenciaCount + post-delete orphan recovery to close TOCTOU.
 */
async function handleDeleteEvent(req, res, deps = {}) {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method-not-allowed");
    const authenticate = deps.authenticate || assertAuthenticatedRequest;
    const rateLimit = deps.enforceRateLimit || enforceNamedRateLimit;
    const firestore = deps.firestore || db;

    const uid = await authenticate(req);
    await rateLimit("att-delete-event", uid, DELETE_EVENT_LIMIT, firestore);
    const user = await loadActiveUser(uid, firestore);
    if (!isSuperAdminRole(user.role)) throw new HttpError(403, "forbidden");

    const rawId = req.body?.eventId;
    if (typeof rawId !== "string") throw new HttpError(400, "missing-fields");
    const eventId = rawId.trim();
    if (
      !eventId ||
      eventId.length > 128 ||
      /[\/\\.]/.test(eventId) ||
      /[\u0000-\u001f\u007f]/.test(eventId)
    ) {
      throw new HttpError(400, "invalid-eventId");
    }

    const eventRef = firestore.collection("attendance_events").doc(eventId);

    // Cheap pre-check (UX); authoritative empty check happens in the transaction.
    const preAttendance = await eventRef.collection("asistencias").limit(1).get();
    if (!preAttendance.empty) {
      throw new HttpError(409, "event-has-attendance");
    }

    let deletedSnapshot = null;
    await firestore.runTransaction(async (tx) => {
      const eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) throw new HttpError(404, "event-missing");
      const rawCount = eventSnap.data()?.asistenciaCount;
      // Count is advisory; subcollection pre/post checks are authoritative.
      // Reject when confirmed count > 0; missing count alone does not block
      // if the subcollection is empty (verified outside this transaction).
      if (isConfirmedAsistenciaCount(rawCount) && rawCount > 0) {
        throw new HttpError(409, "event-has-attendance");
      }
      deletedSnapshot = {id: eventSnap.id, data: eventSnap.data() || {}};
      tx.delete(eventRef);
    });

    // Orphan recovery if a concurrent write created asistencias during delete.
    const postAttendance = await eventRef.collection("asistencias").limit(5).get();
    if (!postAttendance.empty && deletedSnapshot) {
      await eventRef.set({
        ...deletedSnapshot.data,
        asistenciaCount: postAttendance.size,
        orphanRecovery: true,
        orphanRecoveryAt: Date.now(),
      }, {merge: false});
      throw new HttpError(409, "event-has-attendance");
    }

    jsonOk(res, {deleted: true, eventId});
  } catch (error) {
    jsonErr(res, error);
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

const attendanceListMemberQrEvents = onRequest(
  createAttendanceQrHttpsOptions(),
  handleListMemberQrEvents,
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

const attendanceDeleteEvent = onRequest(
  createAttendanceQrHttpsOptions(),
  handleDeleteEvent,
);

module.exports = {
  attendanceEnrollMemberDevice,
  attendancePrepareOfflineCredential,
  attendanceListMemberQrEvents,
  attendancePrepareOfflineEvent,
  attendanceRegisterScannerDevice,
  attendanceApproveScannerDevice,
  attendanceSyncOfflineBatch,
  attendanceDeleteEvent,
  // test exports
  _test: {
    handleEnrollMemberDevice,
    handlePrepareOfflineCredential,
    handleListMemberQrEvents,
    handlePrepareOfflineEvent,
    handleRegisterScannerDevice,
    handleApproveScannerDevice,
    handleSyncOfflineBatch,
    handleDeleteEvent,
    syncOneReceipt,
    participantsHash,
    attendanceDocId,
    isConfirmedAsistenciaCount,
    METODO_SECURE,
    shouldEnforceAttendanceAppCheck,
    assertAppCheck,
    assertBearerUid,
    assertAuthenticatedRequest,
    setVerifyAppCheckTokenForTests,
    resetVerifyAppCheckTokenForTests,
    HttpError,
    activeMemberIdForUser,
    loadRequiredActiveMember,
    eventAllowsMemberQr,
    sanitizeMemberQrEvent,
    sortMemberQrEventsDesc,
    loadActiveAttendanceMemberDevices,
    loadMembersByIds,
    buildOfflineParticipants,
    collectOfflinePackageParticipants,
    serverKeyPairFromSecretValue,
    emulatorTestSigningSeed,
    resolveServerKeyPair,
    assertCanonicalPublicKey,
    assertOfflinePackageSize,
    registerScannerDeviceRecord,
    approveScannerDeviceRecord,
    parseScannerRegistration,
    parseScannerApproval,
    assertScannerAssignment,
    isSuperAdminRole,
    DEVICE_PAGE_SIZE,
    MEMBER_GETALL_CHUNK,
    MAX_OFFLINE_PACKAGE_DEVICES,
    MAX_ACTIVE_DEVICE_SCAN,
    MAX_PARTICIPANTS_JSON_BYTES,
  },
};
