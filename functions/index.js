"use strict";

const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, Timestamp, getFirestore} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");

const {
  buildBackendResetUrl,
  buildPasswordResetEmail,
  buildWelcomeUserEmail,
  PUBLIC_APP_URL,
} = require("./email-template");
const {
  resolveAuthActiveChange,
  roleChanged,
} = require("./user-auth-sync");
const {
  parseInvitePayload,
  parseAdminResetPayload,
  memberIsActive,
  createTemporaryPassword,
} = require("./admin-user");
const {
  parseSearchPayload,
  parseMemberLookupPayload,
  searchUsers,
  searchMembers,
  lookupMemberForCaller,
} = require("./admin-search");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

// Admin must initialize before modules that call getFirestore() at load time.
initializeApp();

const {
  attendanceEnrollMemberDevice,
  attendancePrepareOfflineCredential,
  attendancePrepareOfflineEvent,
  attendanceRegisterScannerDevice,
  attendanceApproveScannerDevice,
  attendanceSyncOfflineBatch,
} = require("./attendance-qr");

const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");
const db = getFirestore();

const RATE_LIMIT_COLLECTION = "_systemRateLimits";
const RESET_TOKEN_COLLECTION = "_passwordResetTokens";
const EMAIL_LIMIT = {maximum: 3, windowMs: 60 * 60 * 1000};
const IP_LIMIT = {maximum: 20, windowMs: 60 * 60 * 1000};
const RESET_TOKEN_LIFETIME_MS = 30 * 60 * 1000;
const GENERIC_MESSAGE =
  "Si la cuenta está registrada, recibirás un correo con un enlace seguro.";

class RateLimitError extends Error {}
class InvalidResetTokenError extends Error {}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
}

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function createResetToken() {
  return crypto.randomBytes(32).toString("base64url");
}

function requestIp(req) {
  const forwarded = req.get("x-forwarded-for");
  return forwarded ? forwarded.split(",")[0].trim() : req.ip || "unknown";
}

function nextRateLimitState(snapshot, limit, nowMs) {
  const current = snapshot.exists ? snapshot.data() : null;
  const windowStart = current?.windowStart?.toMillis?.() || 0;
  const isCurrentWindow = nowMs - windowStart < limit.windowMs;
  const count = isCurrentWindow ? Number(current?.count || 0) : 0;

  if (count >= limit.maximum) throw new RateLimitError();

  return {
    count: count + 1,
    windowStart: Timestamp.fromMillis(isCurrentWindow ? windowStart : nowMs),
    expiresAt: Timestamp.fromMillis(nowMs + limit.windowMs * 2),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function enforceRateLimits(email, ip) {
  const emailRef = db.collection(RATE_LIMIT_COLLECTION).doc(`reset-email-${hash(email)}`);
  const ipRef = db.collection(RATE_LIMIT_COLLECTION).doc(`reset-ip-${hash(ip)}`);
  const nowMs = Date.now();

  await db.runTransaction(async (transaction) => {
    const [emailSnapshot, ipSnapshot] = await Promise.all([
      transaction.get(emailRef),
      transaction.get(ipRef),
    ]);

    transaction.set(emailRef, nextRateLimitState(emailSnapshot, EMAIL_LIMIT, nowMs));
    transaction.set(ipRef, nextRateLimitState(ipSnapshot, IP_LIMIT, nowMs));
  });
}

function createTransport() {
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      user: smtpUser.value().trim(),
      pass: smtpPassword.value().replace(/\s+/g, ""),
    },
  });
}

async function findMemberByEmployeeNumber(employeeNumber) {
  const value = String(employeeNumber || "").trim();
  if (!value) return null;

  const byWorkerCode = await db
    .collection("members")
    .where("workerCode", "==", value)
    .limit(1)
    .get();
  if (!byWorkerCode.empty) return byWorkerCode.docs[0];

  const byMemberNumber = await db
    .collection("members")
    .where("memberNumber", "==", value)
    .limit(1)
    .get();
  if (!byMemberNumber.empty) return byMemberNumber.docs[0];

  return null;
}

async function assertSuperAdminRequest(req) {
  const authHeader = String(req.get("authorization") || "");
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const error = new Error("missing-auth");
    error.status = 401;
    throw error;
  }

  const decoded = await getAuth().verifyIdToken(match[1]);
  const callerDoc = await db.collection("users").doc(decoded.uid).get();
  const caller = callerDoc.exists ? callerDoc.data() : null;
  if (!caller || caller.role !== "SUPERADMIN" || caller.isActive === false) {
    const error = new Error("forbidden");
    error.status = 403;
    throw error;
  }

  return decoded.uid;
}

async function assertAuthenticatedRequest(req) {
  const authHeader = String(req.get("authorization") || "");
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const error = new Error("missing-auth");
    error.status = 401;
    throw error;
  }

  const decoded = await getAuth().verifyIdToken(match[1]);
  return decoded.uid;
}

async function sendResetEmail(email) {
  const user = await getAuth().getUserByEmail(email);
  const token = createResetToken();
  const tokenHash = hash(token);
  const nowMs = Date.now();

  await db.collection(RESET_TOKEN_COLLECTION).doc(tokenHash).set({
    uid: user.uid,
    email,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(nowMs + RESET_TOKEN_LIFETIME_MS),
    usedAt: null,
  });
  const resetUrl = buildBackendResetUrl(token);
  const message = buildPasswordResetEmail({email, resetUrl});

  try {
    await createTransport().sendMail({
      from: `"Sistema Integrado Sindicato" <${smtpUser.value().trim()}>`,
      to: email,
      subject: message.subject,
      text: message.text,
      html: message.html,
    });
  } catch (error) {
    await db.collection(RESET_TOKEN_COLLECTION).doc(tokenHash).delete();
    throw error;
  }
}

function resetTokenRef(token) {
  if (!/^[A-Za-z0-9_-]{40,80}$/.test(token)) {
    throw new InvalidResetTokenError();
  }
  return db.collection(RESET_TOKEN_COLLECTION).doc(hash(token));
}

function validResetTokenData(snapshot) {
  const data = snapshot.exists ? snapshot.data() : null;
  if (
    !data ||
    data.usedAt ||
    data.claimId ||
    !data.uid ||
    !data.email ||
    !data.expiresAt?.toMillis ||
    data.expiresAt.toMillis() <= Date.now()
  ) {
    throw new InvalidResetTokenError();
  }
  return data;
}

async function validateResetToken(token) {
  const snapshot = await resetTokenRef(token).get();
  const data = validResetTokenData(snapshot);
  return {email: data.email};
}

async function confirmResetToken(token, newPassword) {
  const ref = resetTokenRef(token);
  const claimId = crypto.randomUUID();
  let uid;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = validResetTokenData(snapshot);
    uid = data.uid;
    transaction.update(ref, {
      claimId,
      claimedAt: FieldValue.serverTimestamp(),
    });
  });

  try {
    await getAuth().updateUser(uid, {password: newPassword});
    await ref.update({
      usedAt: FieldValue.serverTimestamp(),
      claimId: FieldValue.delete(),
      claimedAt: FieldValue.delete(),
    });
  } catch (error) {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (snapshot.data()?.claimId === claimId) {
        transaction.update(ref, {
          claimId: FieldValue.delete(),
          claimedAt: FieldValue.delete(),
        });
      }
    });
    throw error;
  }
}

exports.requestPasswordReset = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpUser, smtpPassword],
    maxInstances: 5,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    const email = normalizeEmail(req.body?.email);
    if (!isValidEmail(email)) {
      res.status(400).json({ok: false, message: "Ingresa un correo válido."});
      return;
    }

    const emailReference = hash(email).slice(0, 12);

    try {
      await enforceRateLimits(email, requestIp(req));
      await sendResetEmail(email);
      logger.info("Password reset email sent", {emailReference});
    } catch (error) {
      if (error instanceof RateLimitError) {
        res.status(429).json({
          ok: false,
          message: "Has realizado varios intentos. Espera unos minutos e inténtalo nuevamente.",
        });
        return;
      }

      if (error?.code === "auth/user-not-found") {
        logger.info("Password reset requested for unknown account", {emailReference});
      } else {
        logger.error("Password reset email failed", {
          emailReference,
          code: error?.code || "unknown",
          detail: error?.message || "Unknown error",
        });
        res.status(503).json({
          ok: false,
          message: "El servicio de correo no está disponible temporalmente. Inténtalo nuevamente.",
        });
        return;
      }
    }

    res.status(200).json({ok: true, message: GENERIC_MESSAGE});
  },
);

exports.confirmPasswordReset = onRequest(
  {
    region: "us-central1",
    cors: true,
    maxInstances: 5,
    timeoutSeconds: 30,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    const action = String(req.body?.action || "");
    const token = String(req.body?.token || "");

    try {
      if (action === "validate") {
        const result = await validateResetToken(token);
        res.status(200).json({ok: true, email: result.email});
        return;
      }

      if (action === "confirm") {
        const newPassword = String(req.body?.newPassword || "");
        if (newPassword.length < 8 || newPassword.length > 128) {
          res.status(400).json({
            ok: false,
            message: "La contraseña debe tener entre 8 y 128 caracteres.",
          });
          return;
        }

        await confirmResetToken(token, newPassword);
        res.status(200).json({ok: true});
        return;
      }

      res.status(400).json({ok: false, message: "Solicitud no válida."});
    } catch (error) {
      if (error instanceof InvalidResetTokenError) {
        res.status(400).json({
          ok: false,
          message: "El enlace no es válido, venció o ya fue utilizado.",
        });
        return;
      }

      logger.error("Password reset confirmation failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo completar el cambio. Inténtalo nuevamente.",
      });
    }
  },
);

exports.adminInviteUser = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpUser, smtpPassword],
    maxInstances: 5,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    try {
      const actorUid = await assertSuperAdminRequest(req);
      const parsed = parseInvitePayload(req.body);
      if (parsed.error) {
        res.status(400).json({ok: false, message: parsed.error});
        return;
      }

      const {email, role, displayName, employeeNumber} = parsed.payload;
      let memberId = null;
      let workerCode = employeeNumber;

      if (employeeNumber) {
        const memberDoc = await findMemberByEmployeeNumber(employeeNumber);
        if (!memberDoc) {
          res.status(400).json({
            ok: false,
            message: "Número de trabajador no registrado en el padrón.",
          });
          return;
        }
        if (!memberIsActive(memberDoc.data())) {
          res.status(400).json({
            ok: false,
            message: "El socio asociado no se encuentra activo.",
          });
          return;
        }
        memberId = memberDoc.id;
        workerCode = memberDoc.data().workerCode || employeeNumber;
      }

      const temporaryPassword = createTemporaryPassword();
      let userRecord;
      try {
        userRecord = await getAuth().createUser({
          email,
          password: temporaryPassword,
          displayName: displayName || undefined,
          disabled: false,
        });
      } catch (error) {
        if (error?.code === "auth/email-already-exists") {
          res.status(409).json({
            ok: false,
            message: "Ya existe una cuenta con ese correo.",
          });
          return;
        }
        throw error;
      }

      const now = Date.now();
      try {
        await db.collection("users").doc(userRecord.uid).set({
          email,
          displayName,
          role,
          employeeNumber: workerCode,
          memberId,
          createdAt: now,
          updatedAt: now,
          isActive: true,
        });
      } catch (error) {
        await getAuth().deleteUser(userRecord.uid);
        throw error;
      }

      let emailSent = false;
      try {
        const message = buildWelcomeUserEmail({
          email,
          displayName,
          temporaryPassword,
          appUrl: PUBLIC_APP_URL,
        });
        await createTransport().sendMail({
          from: `"Sistema Integrado Sindicato" <${smtpUser.value().trim()}>`,
          to: email,
          subject: message.subject,
          text: message.text,
          html: message.html,
        });
        emailSent = true;
      } catch (error) {
        logger.warn("Welcome email failed after user invite", {
          actorUid,
          invitedUid: userRecord.uid,
          detail: error?.message || "Unknown error",
        });
      }

      await db.collection("audit_logs").add({
        action: "create",
        entityType: "user",
        entityId: userRecord.uid,
        userId: actorUid,
        timestamp: now,
        description: `Invitación de usuario ${email} con rol ${role}`,
        changes: {
          email,
          role,
          memberId,
          emailSent,
        },
      });

      res.status(200).json({
        ok: true,
        uid: userRecord.uid,
        email,
        role,
        emailSent,
        temporaryPassword: emailSent ? null : temporaryPassword,
      });
    } catch (error) {
      if (error?.status === 401) {
        res.status(401).json({ok: false, message: "Sesión no válida."});
        return;
      }
      if (error?.status === 403) {
        res.status(403).json({
          ok: false,
          message: "Solo un superadministrador puede invitar usuarios.",
        });
        return;
      }

      logger.error("adminInviteUser failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo crear la cuenta. Inténtalo nuevamente.",
      });
    }
  },
);

exports.adminSendPasswordReset = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpUser, smtpPassword],
    maxInstances: 5,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    try {
      const actorUid = await assertSuperAdminRequest(req);
      const parsed = parseAdminResetPayload(req.body);
      if (parsed.error) {
        res.status(400).json({ok: false, message: parsed.error});
        return;
      }

      const {targetUserId} = parsed.payload;
      const targetDoc = await db.collection("users").doc(targetUserId).get();
      if (!targetDoc.exists) {
        res.status(404).json({ok: false, message: "Usuario no encontrado."});
        return;
      }

      const target = targetDoc.data() || {};
      if (target.isActive === false) {
        res.status(400).json({
          ok: false,
          message: "No se puede restablecer la contraseña de un usuario inactivo.",
        });
        return;
      }

      const email = normalizeEmail(target.email);
      if (!isValidEmail(email)) {
        res.status(400).json({ok: false, message: "El usuario no tiene un correo válido."});
        return;
      }

      await sendResetEmail(email);

      const now = Date.now();
      await db.collection("audit_logs").add({
        action: "update",
        entityType: "user",
        entityId: targetUserId,
        userId: actorUid,
        timestamp: now,
        description: `Recuperación de contraseña enviada a ${email}`,
        changes: {email, initiatedBy: "admin"},
      });

      res.status(200).json({
        ok: true,
        email,
        message: "Se envió un enlace seguro de recuperación al correo del usuario.",
      });
    } catch (error) {
      if (error?.status === 401) {
        res.status(401).json({ok: false, message: "Sesión no válida."});
        return;
      }
      if (error?.status === 403) {
        res.status(403).json({
          ok: false,
          message: "Solo un superadministrador puede restablecer contraseñas.",
        });
        return;
      }
      if (error?.code === "auth/user-not-found") {
        res.status(404).json({
          ok: false,
          message: "La cuenta no existe en Firebase Auth.",
        });
        return;
      }

      logger.error("adminSendPasswordReset failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo enviar el correo de recuperación.",
      });
    }
  },
);

exports.adminSearchUsers = onRequest(
  {
    region: "us-central1",
    cors: true,
    maxInstances: 5,
    timeoutSeconds: 30,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    try {
      await assertSuperAdminRequest(req);
      const parsed = parseSearchPayload(req.body);
      if (parsed.error) {
        res.status(400).json({ok: false, message: parsed.error});
        return;
      }

      const {query, limit} = parsed.payload;
      const users = await searchUsers(db, query, limit);
      res.status(200).json({ok: true, users});
    } catch (error) {
      if (error?.status === 401) {
        res.status(401).json({ok: false, message: "Sesión no válida."});
        return;
      }
      if (error?.status === 403) {
        res.status(403).json({
          ok: false,
          message: "Solo un superadministrador puede buscar usuarios.",
        });
        return;
      }

      logger.error("adminSearchUsers failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo completar la búsqueda de usuarios.",
      });
    }
  },
);

exports.adminSearchMembers = onRequest(
  {
    region: "us-central1",
    cors: true,
    maxInstances: 5,
    timeoutSeconds: 30,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    try {
      await assertSuperAdminRequest(req);
      const parsed = parseSearchPayload(req.body);
      if (parsed.error) {
        res.status(400).json({ok: false, message: parsed.error});
        return;
      }

      const {query, limit} = parsed.payload;
      const members = await searchMembers(db, query, limit);
      res.status(200).json({ok: true, members});
    } catch (error) {
      if (error?.status === 401) {
        res.status(401).json({ok: false, message: "Sesión no válida."});
        return;
      }
      if (error?.status === 403) {
        res.status(403).json({
          ok: false,
          message: "Solo un superadministrador puede buscar socios.",
        });
        return;
      }

      logger.error("adminSearchMembers failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo completar la búsqueda de socios.",
      });
    }
  },
);

exports.lookupMemberByEmployee = onRequest(
  {
    region: "us-central1",
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 20,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.status(405).json({ok: false, message: "Método no permitido."});
      return;
    }

    try {
      const uid = await assertAuthenticatedRequest(req);
      const parsed = parseMemberLookupPayload(req.body);
      if (parsed.error) {
        res.status(400).json({ok: false, message: parsed.error});
        return;
      }

      const {employeeNumber} = parsed.payload;
      const result = await lookupMemberForCaller(
        db,
        findMemberByEmployeeNumber,
        uid,
        employeeNumber,
      );

      res.status(200).json({
        ok: true,
        memberId: result.memberId,
        member: result.member,
      });
    } catch (error) {
      if (error?.status === 401) {
        res.status(401).json({ok: false, message: "Sesión no válida."});
        return;
      }
      if (error?.status === 403) {
        res.status(403).json({
          ok: false,
          message: "No tienes permisos para consultar ese socio.",
        });
        return;
      }
      if (error?.status === 404 || error?.message === "not-found") {
        res.status(404).json({
          ok: false,
          message: "Número de trabajador no registrado en el padrón de socios.",
        });
        return;
      }
      if (error?.status === 400 || error?.message === "inactive") {
        res.status(400).json({
          ok: false,
          message: "El socio asociado no se encuentra activo.",
        });
        return;
      }

      logger.error("lookupMemberByEmployee failed", {
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      res.status(503).json({
        ok: false,
        message: "No se pudo validar el número de trabajador.",
      });
    }
  },
);

exports.attendanceEnrollMemberDevice = attendanceEnrollMemberDevice;
exports.attendancePrepareOfflineCredential = attendancePrepareOfflineCredential;
exports.attendancePrepareOfflineEvent = attendancePrepareOfflineEvent;
exports.attendanceRegisterScannerDevice = attendanceRegisterScannerDevice;
exports.attendanceApproveScannerDevice = attendanceApproveScannerDevice;
exports.attendanceSyncOfflineBatch = attendanceSyncOfflineBatch;

exports.syncUserAuthAccess = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
    maxInstances: 10,
  },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const uid = event.params.userId;

    const activeChange = resolveAuthActiveChange(before, after);
    const hasRoleChange = roleChanged(before, after);

    if (activeChange === null && !hasRoleChange) return;

    try {
      if (activeChange !== null) {
        await getAuth().updateUser(uid, {disabled: activeChange.disabled});
        if (activeChange.revokeTokens) {
          await getAuth().revokeRefreshTokens(uid);
        }
        logger.info("Synced Firebase Auth access from Firestore profile", {
          uid,
          disabled: activeChange.disabled,
        });
        return;
      }

      if (hasRoleChange) {
        await getAuth().revokeRefreshTokens(uid);
        logger.info("Revoked refresh tokens after role change", {
          uid,
          previousRole: before.role || null,
          nextRole: after.role,
        });
      }
    } catch (error) {
      if (error?.code === "auth/user-not-found") {
        logger.warn("Firestore user profile without Firebase Auth account", {uid});
        return;
      }
      logger.error("Failed to sync Firebase Auth access", {
        uid,
        code: error?.code || "unknown",
        detail: error?.message || "Unknown error",
      });
      throw error;
    }
  },
);
