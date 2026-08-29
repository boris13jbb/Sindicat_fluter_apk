import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_qr_protocol.dart';

/// Ed25519 helpers for SATT2 (Flutter / Dart).
///
/// Private keys never leave [SecureKeyStore]. Signatures and public keys are
/// Base64URL without padding.
class SecureQrCrypto {
  SecureQrCrypto({Ed25519? algorithm}) : _ed25519 = algorithm ?? Ed25519();

  final Ed25519 _ed25519;

  static String bytesToBase64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List base64UrlToBytes(String value) {
    var normalized = value.trim();
    final pad = (4 - normalized.length % 4) % 4;
    normalized = normalized + ('=' * pad);
    return Uint8List.fromList(base64Url.decode(normalized));
  }

  Future<SimpleKeyPair> generateKeyPair() => _ed25519.newKeyPair();

  Future<String> publicKeyBase64Url(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return bytesToBase64Url(pub.bytes);
  }

  Future<String> privateKeySeedBase64Url(SimpleKeyPair keyPair) async {
    final seed = await keyPair.extractPrivateKeyBytes();
    return bytesToBase64Url(seed);
  }

  Future<SimpleKeyPair> keyPairFromSeedBase64Url(String seedB64) async {
    final seed = base64UrlToBytes(seedB64);
    return _ed25519.newKeyPairFromSeed(seed);
  }

  Future<SimplePublicKey> publicKeyFromBase64Url(String publicB64) async {
    final bytes = base64UrlToBytes(publicB64);
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }

  Future<String> signUtf8({
    required String canonicalPayload,
    required SimpleKeyPair keyPair,
  }) async {
    final data = utf8.encode(canonicalPayload);
    final signature = await _ed25519.sign(data, keyPair: keyPair);
    return bytesToBase64Url(signature.bytes);
  }

  Future<bool> verifyUtf8({
    required String canonicalPayload,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) async {
    try {
      final data = utf8.encode(canonicalPayload);
      final publicKey = await publicKeyFromBase64Url(publicKeyBase64Url);
      final signature = Signature(
        base64UrlToBytes(signatureBase64Url),
        publicKey: publicKey,
      );
      return await _ed25519.verify(data, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// Signs a challenge map using protocol canonicalization.
  Future<String> signChallenge({
    required Map<String, String> fields,
    required SimpleKeyPair keyPair,
  }) {
    return signUtf8(
      canonicalPayload: canonicalChallengePayload(fields),
      keyPair: keyPair,
    );
  }

  Future<bool> verifyChallenge({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalChallengePayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }

  Future<String> signResponse({
    required Map<String, String> fields,
    required SimpleKeyPair keyPair,
  }) {
    return signUtf8(
      canonicalPayload: canonicalResponsePayload(fields),
      keyPair: keyPair,
    );
  }

  Future<bool> verifyResponse({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalResponsePayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }

  Future<String> signMemberQr({
    required Map<String, String> fields,
    required SimpleKeyPair keyPair,
  }) {
    return signUtf8(
      canonicalPayload: canonicalMemberQrPayload(fields),
      keyPair: keyPair,
    );
  }

  Future<bool> verifyMemberQr({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalMemberQrPayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }

  Future<String> signReceipt({
    required Map<String, String> fields,
    required SimpleKeyPair keyPair,
  }) {
    return signUtf8(
      canonicalPayload: canonicalReceiptPayload(fields),
      keyPair: keyPair,
    );
  }

  Future<bool> verifyReceipt({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalReceiptPayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }

  Future<bool> verifyPackage({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalPackagePayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }

  Future<bool> verifyCredential({
    required Map<String, String> fields,
    required String signatureBase64Url,
    required String publicKeyBase64Url,
  }) {
    return verifyUtf8(
      canonicalPayload: canonicalCredentialPayload(fields),
      signatureBase64Url: signatureBase64Url,
      publicKeyBase64Url: publicKeyBase64Url,
    );
  }
}
