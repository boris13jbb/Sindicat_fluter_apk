/**
 * SATT2 crypto golden + canonical tests (Node).
 * Uses TEST keys only — never production secrets.
 */

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const cryptoHelpers = require("./attendance-qr-crypto");
const attendanceQr = require("./attendance-qr");

// 32 zero bytes — TEST ONLY
const TEST_SEED = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

function nonCanonicalEquivalent(value) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  const last = alphabet.indexOf(value.at(-1));
  assert.notEqual(last, -1);
  return value.slice(0, -1) + alphabet[last + 1];
}

function assertInvalidKeyInput(parse, value) {
  assert.throws(() => parse(value));
}

describe("strict canonical base64url", () => {
  it("accepts only a canonical 32-byte private seed", () => {
    assert.doesNotThrow(() => cryptoHelpers.keyFromSeedBase64Url(TEST_SEED));
    for (const value of [
      TEST_SEED + "=",
      "+" + TEST_SEED.slice(1),
      "/" + TEST_SEED.slice(1),
      " " + TEST_SEED,
      "\t" + TEST_SEED,
      TEST_SEED + "\n",
      TEST_SEED.slice(0, 42),
      TEST_SEED + "A",
      Buffer.alloc(31).toString("base64url"),
      Buffer.alloc(33).toString("base64url"),
      nonCanonicalEquivalent(TEST_SEED),
    ]) {
      assertInvalidKeyInput(cryptoHelpers.keyFromSeedBase64Url, value);
    }
  });

  it("accepts only a canonical 32-byte public key", () => {
    const publicKey = cryptoHelpers.keyFromSeedBase64Url(TEST_SEED)
      .publicKeyBase64Url;
    assert.doesNotThrow(() => cryptoHelpers.publicKeyFromBase64Url(publicKey));
    for (const value of [
      publicKey + "=",
      "+" + publicKey.slice(1),
      "/" + publicKey.slice(1),
      " " + publicKey,
      "\t" + publicKey,
      publicKey + "\n",
      publicKey.slice(0, 42),
      publicKey + "A",
      Buffer.alloc(31).toString("base64url"),
      Buffer.alloc(33).toString("base64url"),
      nonCanonicalEquivalent(publicKey),
    ]) {
      assertInvalidKeyInput(cryptoHelpers.publicKeyFromBase64Url, value);
    }
  });

  it("maps missing and invalid signing secrets to controlled 503 errors", () => {
    const parse = attendanceQr._test.serverKeyPairFromSecretValue;
    for (const missing of [undefined, null, ""]) {
      assert.throws(
        () => parse(missing),
        (error) => error.status === 503 && error.code === "signing-key-missing",
      );
    }
    for (const invalid of [" ", TEST_SEED + "=", TEST_SEED.slice(0, 42)]) {
      assert.throws(
        () => parse(invalid),
        (error) => error.status === 503 && error.code === "signing-key-invalid",
      );
    }
  });

  it("accepts test seed injection only in explicit emulator environments", () => {
    const resolveTestSeed = attendanceQr._test.emulatorTestSigningSeed;
    assert.equal(resolveTestSeed({ATTENDANCE_QR_TEST_SEED: TEST_SEED}), undefined);
    assert.equal(
      resolveTestSeed({
        FUNCTIONS_EMULATOR: "true",
        ATTENDANCE_QR_TEST_SEED: TEST_SEED,
      }),
      TEST_SEED,
    );
    assert.equal(
      resolveTestSeed({
        FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
        ATTENDANCE_QR_TEST_SEED: TEST_SEED,
      }),
      TEST_SEED,
    );
    assert.equal(
      resolveTestSeed({
        FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
        ATTENDANCE_QR_TEST_SEED: TEST_SEED,
      }),
      TEST_SEED,
    );
  });
});

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

  it("matches shared credential and package signing vectors with Dart", () => {
    const fs = require("node:fs");
    const path = require("node:path");
    const fixture = JSON.parse(fs.readFileSync(path.join(
      __dirname,
      "..",
      "test",
      "attendance_qr",
      "golden_server_signing_vectors.json",
    ), "utf8"));
    assert.equal(fixture.warning, "TEST KEY - NEVER USE IN PRODUCTION");

    const keyPair = cryptoHelpers.keyFromSeedBase64Url(
      fixture.privateSeedBase64Url,
    );
    assert.equal(keyPair.publicKeyBase64Url, fixture.publicKeyBase64Url);

    const credentialCanonical = cryptoHelpers.canonicalCredentialPayload(
      fixture.credential.fields,
    );
    assert.equal(credentialCanonical, fixture.credential.canonical);
    assert.equal(
      cryptoHelpers.verifyUtf8(
        credentialCanonical,
        fixture.credential.signature,
        fixture.publicKeyBase64Url,
      ),
      true,
    );

    const packageCanonical = cryptoHelpers.canonicalPackagePayload(
      fixture.package.fields,
    );
    assert.equal(packageCanonical, fixture.package.canonical);
    assert.equal(
      attendanceQr._test.participantsHash(fixture.package.participants),
      fixture.package.fields.participantsHash,
    );
    assert.equal(
      cryptoHelpers.verifyUtf8(
        packageCanonical,
        fixture.package.signature,
        fixture.publicKeyBase64Url,
      ),
      true,
    );
    assert.equal(
      cryptoHelpers.verifyUtf8(
        packageCanonical.replace("golden-event", "golden-evenu"),
        fixture.package.signature,
        fixture.publicKeyBase64Url,
      ),
      false,
    );
  });
});
