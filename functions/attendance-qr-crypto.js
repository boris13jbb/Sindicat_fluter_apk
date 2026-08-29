"use strict";

/**
 * SATT2 canonical serialization + Ed25519 helpers (Node).
 * MUST match Dart `secure_qr_protocol.dart` / `secure_qr_crypto.dart`.
 */

const crypto = require("node:crypto");

const CHALLENGE_KEYS = [
  "v", "type", "eventId", "scannerId", "challengeId", "challengeNonce",
  "issuedAtTrusted", "expiresAtTrusted", "protocolVersion",
];

const RESPONSE_KEYS = [
  "v", "type", "eventId", "scannerId", "challengeId", "challengeNonce",
  "memberDeviceId", "credentialId", "responseNonce", "issuedAt",
  "protocolVersion", "memberLat", "memberLng", "memberAccuracy",
];

const PACKAGE_KEYS = [
  "v", "type", "packageId", "eventId", "eventName", "startAt", "endAt",
  "issuedAtServer", "expiresAt", "serverTimeAtPreparation", "scannerId",
  "scannerPublicKey", "geofenceEnabled", "latitude", "longitude",
  "geofenceRadiusMeters", "participantsHash", "keyVersion",
];

const RECEIPT_KEYS = [
  "v", "type", "localReceiptId", "eventId", "memberId", "memberDeviceId",
  "scannerId", "challengeId", "challengeNonce", "responseNonce",
  "memberSignature", "packageId", "scannedAtTrusted", "scannedAtDevice",
  "scanLatitude", "scanLongitude", "scanAccuracy", "locationStatus",
];

const CREDENTIAL_KEYS = [
  "v", "type", "credentialId", "uid", "memberId", "memberDeviceId",
  "memberPublicKey", "issuedAtServer", "expiresAt", "keyVersion",
];

function canonicalKeyValuePayload(orderedKeys, fields) {
  const lines = [];
  for (const key of orderedKeys) {
    if (!(key in fields) || fields[key] == null) continue;
    const value = String(fields[key]).trim();
    if (!value) continue;
    if (key.includes("=") || key.includes("\n") || value.includes("\n")) {
      throw new Error(`Invalid key/value for canonical payload: ${key}`);
    }
    lines.push(`${key}=${value}`);
  }
  return lines.join("\n");
}

function bytesToBase64Url(buf) {
  return Buffer.from(buf).toString("base64url");
}

function base64UrlToBuffer(value) {
  return Buffer.from(String(value), "base64url");
}

function generateEd25519KeyPair() {
  const {publicKey, privateKey} = crypto.generateKeyPairSync("ed25519");
  const pubDer = publicKey.export({type: "spki", format: "der"});
  // SPKI for Ed25519: last 32 bytes are raw public key
  const rawPub = pubDer.subarray(pubDer.length - 32);
  const privDer = privateKey.export({type: "pkcs8", format: "der"});
  // PKCS8 for Ed25519: last 32 bytes are seed
  const rawSeed = privDer.subarray(privDer.length - 32);
  return {
    publicKeyBase64Url: bytesToBase64Url(rawPub),
    privateKeySeedBase64Url: bytesToBase64Url(rawSeed),
    publicKey,
    privateKey,
  };
}

function keyFromSeedBase64Url(seedB64) {
  const seed = base64UrlToBuffer(seedB64);
  const privateKey = crypto.createPrivateKey({
    key: Buffer.concat([
      Buffer.from("302e020100300506032b657004220420", "hex"),
      seed,
    ]),
    format: "der",
    type: "pkcs8",
  });
  const publicKey = crypto.createPublicKey(privateKey);
  const pubDer = publicKey.export({type: "spki", format: "der"});
  const rawPub = pubDer.subarray(pubDer.length - 32);
  return {
    privateKey,
    publicKey,
    publicKeyBase64Url: bytesToBase64Url(rawPub),
  };
}

function publicKeyFromBase64Url(pubB64) {
  const raw = base64UrlToBuffer(pubB64);
  // SPKI prefix for Ed25519 public key
  const spki = Buffer.concat([
    Buffer.from("302a300506032b6570032100", "hex"),
    raw,
  ]);
  return crypto.createPublicKey({key: spki, format: "der", type: "spki"});
}

function signUtf8(canonicalPayload, privateKey) {
  const sig = crypto.sign(null, Buffer.from(canonicalPayload, "utf8"), privateKey);
  return bytesToBase64Url(sig);
}

function verifyUtf8(canonicalPayload, signatureB64, publicKeyOrB64) {
  try {
    const publicKey = typeof publicKeyOrB64 === "string"
      ? publicKeyFromBase64Url(publicKeyOrB64)
      : publicKeyOrB64;
    return crypto.verify(
      null,
      Buffer.from(canonicalPayload, "utf8"),
      publicKey,
      base64UrlToBuffer(signatureB64),
    );
  } catch (_) {
    return false;
  }
}

function hashSha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function secureNonce(byteLength = 24) {
  return bytesToBase64Url(crypto.randomBytes(byteLength));
}

module.exports = {
  CHALLENGE_KEYS,
  RESPONSE_KEYS,
  PACKAGE_KEYS,
  RECEIPT_KEYS,
  CREDENTIAL_KEYS,
  canonicalKeyValuePayload,
  canonicalChallengePayload: (f) => canonicalKeyValuePayload(CHALLENGE_KEYS, f),
  canonicalResponsePayload: (f) => canonicalKeyValuePayload(RESPONSE_KEYS, f),
  canonicalPackagePayload: (f) => canonicalKeyValuePayload(PACKAGE_KEYS, f),
  canonicalReceiptPayload: (f) => canonicalKeyValuePayload(RECEIPT_KEYS, f),
  canonicalCredentialPayload: (f) => canonicalKeyValuePayload(CREDENTIAL_KEYS, f),
  bytesToBase64Url,
  base64UrlToBuffer,
  generateEd25519KeyPair,
  keyFromSeedBase64Url,
  publicKeyFromBase64Url,
  signUtf8,
  verifyUtf8,
  hashSha256Hex,
  secureNonce,
};
