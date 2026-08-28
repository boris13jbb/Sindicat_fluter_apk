"use strict";

const {memberIsActive} = require("./admin-user");

const MAX_SEARCH_RESULTS = 50;
const DEFAULT_SEARCH_RESULTS = 30;
const MEMBER_SCAN_CAP = 250;

function clampLimit(value) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_SEARCH_RESULTS;
  }
  return Math.min(parsed, MAX_SEARCH_RESULTS);
}

function parseSearchPayload(body) {
  const query = String(body?.query ?? "").trim();
  if (!query) {
    return {error: "Ingresa un término de búsqueda."};
  }
  if (query.length > 120) {
    return {error: "El término de búsqueda es demasiado largo."};
  }
  return {
    payload: {
      query,
      limit: clampLimit(body?.limit),
    },
  };
}

function parseMemberLookupPayload(body) {
  const employeeNumber = String(body?.employeeNumber ?? "").trim();
  if (!employeeNumber) {
    return {error: "El número de trabajador es obligatorio."};
  }
  if (employeeNumber.length > 64) {
    return {error: "Número de trabajador no válido."};
  }
  return {payload: {employeeNumber}};
}

function sanitizeUserSummary(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    email: data.email || "",
    displayName: data.displayName || null,
    role: data.role || "USER",
    employeeNumber: data.employeeNumber || null,
    memberId: data.memberId || null,
    isActive: data.isActive !== false,
    gender: data.gender || null,
    avatarUrl: data.avatarUrl || null,
    avatarMode: data.avatarMode || null,
    phoneNumber: data.phoneNumber || null,
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
  };
}

function sanitizeMemberSummary(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    memberNumber: data.memberNumber || "",
    firstName: data.firstName || "",
    lastName: data.lastName || "",
    fullName: data.fullName || "",
    workerCode: data.workerCode || null,
    documentId: data.documentId || null,
    email: data.email || null,
    phone: data.phone || null,
    modalidad: data.modalidad || null,
    status: data.status || "active",
  };
}

function memberToClientMap(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    memberNumber: data.memberNumber || "",
    firstName: data.firstName || "",
    lastName: data.lastName || "",
    fullName: data.fullName || "",
    workerCode: data.workerCode || null,
    documentId: data.documentId || null,
    email: data.email || null,
    phone: data.phone || null,
    modalidad: data.modalidad || null,
    status: data.status || "active",
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
    createdBy: data.createdBy || null,
    additionalData: data.additionalData || null,
  };
}

async function searchUsers(db, query, limit) {
  const results = [];
  const seen = new Set();

  const addDoc = (doc) => {
    if (seen.has(doc.id) || results.length >= limit) return;
    seen.add(doc.id);
    results.push(sanitizeUserSummary(doc));
  };

  if (query.includes("@")) {
    const normalized = query.toLowerCase();
    const snap = await db
      .collection("users")
      .orderBy("email")
      .startAt(normalized)
      .endAt(`${normalized}\uf8ff`)
      .limit(limit)
      .get();
    snap.docs.forEach(addDoc);
    return results;
  }

  const byEmployee = await db
    .collection("users")
    .where("employeeNumber", "==", query)
    .limit(limit)
    .get();
  byEmployee.docs.forEach(addDoc);
  if (results.length >= limit) return results;

  const normalized = query.toLowerCase();
  const emailSnap = await db
    .collection("users")
    .orderBy("email")
    .startAt(normalized)
    .endAt(`${normalized}\uf8ff`)
    .limit(limit)
    .get();
  emailSnap.docs.forEach(addDoc);
  if (results.length >= limit) return results;

  const scanSnap = await db
    .collection("users")
    .orderBy("email")
    .limit(MEMBER_SCAN_CAP)
    .get();
  for (const doc of scanSnap.docs) {
    if (results.length >= limit) break;
    const data = doc.data() || {};
    const haystack = [
      data.email,
      data.displayName,
      data.employeeNumber,
      data.memberId,
      doc.id,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    if (haystack.includes(normalized)) {
      addDoc(doc);
    }
  }

  return results;
}

async function searchMembers(db, query, limit) {
  const results = [];
  const seen = new Set();
  const normalized = query.toLowerCase();

  const addDoc = (doc) => {
    if (seen.has(doc.id) || results.length >= limit) return;
    seen.add(doc.id);
    results.push(sanitizeMemberSummary(doc));
  };

  const byWorker = await db
    .collection("members")
    .where("workerCode", "==", query)
    .limit(limit)
    .get();
  byWorker.docs.forEach(addDoc);
  if (results.length >= limit) return results;

  const byMemberNumber = await db
    .collection("members")
    .where("memberNumber", "==", query)
    .limit(limit)
    .get();
  byMemberNumber.docs.forEach(addDoc);
  if (results.length >= limit) return results;

  const scanSnap = await db
    .collection("members")
    .orderBy("memberNumber")
    .limit(MEMBER_SCAN_CAP)
    .get();
  for (const doc of scanSnap.docs) {
    if (results.length >= limit) break;
    const data = doc.data() || {};
    const haystack = [
      data.fullName,
      data.firstName,
      data.lastName,
      data.memberNumber,
      data.workerCode,
      data.documentId,
      data.email,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    if (haystack.includes(normalized)) {
      addDoc(doc);
    }
  }

  return results;
}

async function lookupMemberForCaller(db, findMemberByEmployeeNumber, uid, employeeNumber) {
  const userRef = db.collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (userDoc.exists) {
    const user = userDoc.data() || {};
    const userEmployee = String(user.employeeNumber || "").trim();
    if (userEmployee && userEmployee !== employeeNumber) {
      const error = new Error("forbidden");
      error.status = 403;
      throw error;
    }

    if (user.memberId) {
      const linkedDoc = await db.collection("members").doc(user.memberId).get();
      if (linkedDoc.exists) {
        return {
          memberId: linkedDoc.id,
          member: memberToClientMap(linkedDoc),
        };
      }
    }
  }

  const memberDoc = await findMemberByEmployeeNumber(employeeNumber);
  if (!memberDoc) {
    const error = new Error("not-found");
    error.status = 404;
    throw error;
  }
  if (!memberIsActive(memberDoc.data())) {
    const error = new Error("inactive");
    error.status = 400;
    throw error;
  }

  return {
    memberId: memberDoc.id,
    member: memberToClientMap(memberDoc),
  };
}

module.exports = {
  MAX_SEARCH_RESULTS,
  parseSearchPayload,
  parseMemberLookupPayload,
  sanitizeUserSummary,
  sanitizeMemberSummary,
  searchUsers,
  searchMembers,
  lookupMemberForCaller,
  memberToClientMap,
};
