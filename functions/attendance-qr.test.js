/**
 * SATT2 crypto golden + canonical tests (Node).
 * Uses TEST keys only — never production secrets.
 */

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const cryptoHelpers = require("./attendance-qr-crypto");

// 32 zero bytes — TEST ONLY
const TEST_SEED = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

describe("attendance-qr-crypto canonical", () => {
  it("orders challenge keys deterministically", () => {
    const payload = cryptoHelpers.canonicalChallengePayload({
      protocolVersion: "2",
      v: "2",
      type: "SATT2C",
      eventId: "evt1",
      scannerId: "scn1",
      challengeId: "cid1",
      challengeNonce: "nonce1",
      issuedAtTrusted: "1000",
      expiresAtTrusted: "16000",
    });
    assert.equal(
      payload,
      "v=2\n" +
        "type=SATT2C\n" +
        "eventId=evt1\n" +
        "scannerId=scn1\n" +
        "challengeId=cid1\n" +
        "challengeNonce=nonce1\n" +
        "issuedAtTrusted=1000\n" +
        "expiresAtTrusted=16000\n" +
        "protocolVersion=2",
    );
  });

  it("matches shared golden_challenge_canonical.txt with Dart", () => {
    const fs = require("node:fs");
    const path = require("node:path");
    const file = path.join(
      __dirname,
      "..",
      "test",
      "attendance_qr",
      "golden_challenge_canonical.txt",
    );
    const expected = fs.readFileSync(file, "utf8").trim().replace(/\r\n/g, "\n");
    const fields = {
      v: "2",
      type: "SATT2C",
      eventId: "golden-event",
      scannerId: "golden-scanner",
      challengeId: "golden-challenge",
      challengeNonce: "golden-nonce",
      issuedAtTrusted: "1700000000000",
      expiresAtTrusted: "1700000015000",
      protocolVersion: "2",
    };
    const canonical = cryptoHelpers.canonicalChallengePayload(fields);
    assert.equal(canonical, expected);
    const kp = cryptoHelpers.keyFromSeedBase64Url(TEST_SEED);
    const sig = cryptoHelpers.signUtf8(canonical, kp.privateKey);
    assert.equal(
      cryptoHelpers.verifyUtf8(canonical, sig, kp.publicKeyBase64Url),
      true,
    );
    assert.equal(
      cryptoHelpers.verifyUtf8(canonical + "\nx", sig, kp.publicKeyBase64Url),
      false,
    );
  });

  it("golden: sign/verify with fixed seed; tamper fails", () => {
    const kp = cryptoHelpers.keyFromSeedBase64Url(TEST_SEED);
    const fields = {
      v: "2",
      type: "SATT2C",
      eventId: "golden-event",
      scannerId: "golden-scanner",
      challengeId: "golden-challenge",
      challengeNonce: "golden-nonce",
      issuedAtTrusted: "1700000000000",
      expiresAtTrusted: "1700000015000",
      protocolVersion: "2",
    };
    const canonical = cryptoHelpers.canonicalChallengePayload(fields);
    const sig = cryptoHelpers.signUtf8(canonical, kp.privateKey);
    assert.ok(sig.length > 0);
    assert.equal(
      cryptoHelpers.verifyUtf8(canonical, sig, kp.publicKeyBase64Url),
      true,
    );
    assert.equal(
      cryptoHelpers.verifyUtf8(canonical + "x", sig, kp.publicKeyBase64Url),
      false,
    );
  });

  it("Dart/Node public key from same seed matches length 43 base64url", () => {
    const kp = cryptoHelpers.keyFromSeedBase64Url(TEST_SEED);
    assert.equal(kp.publicKeyBase64Url.length, 43);
  });
});
