import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_qr_crypto.dart';
import 'secure_qr_protocol.dart';

/// Platform-aware private key storage.
///
/// Private keys NEVER go to Firestore, QR payloads, or common offline DB.
class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage, SecureQrCrypto? crypto})
    : _storage = storage ?? const FlutterSecureStorage(),
      _crypto = crypto ?? SecureQrCrypto();

  final FlutterSecureStorage _storage;
  final SecureQrCrypto _crypto;

  static const _memberPrefix = 'satt2_member_seed_';
  static const _scannerPrefix = 'satt2_scanner_seed_';

  SecureAttendanceAssurance detectAssurance() {
    if (kIsWeb) {
      // Web lacks reliable hardware-backed private key storage in this stack.
      return SecureAttendanceAssurance.limitedAssurance;
    }
    return SecureAttendanceAssurance.highAssurance;
  }

  Future<SimpleKeyPair> getOrCreateMemberKeyPair(String deviceId) async {
    final key = '$_memberPrefix$deviceId';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) {
      return _crypto.keyPairFromSeedBase64Url(existing);
    }
    final pair = await _crypto.generateKeyPair();
    final seed = await _crypto.privateKeySeedBase64Url(pair);
    await _storage.write(key: key, value: seed);
    return pair;
  }

  Future<SimpleKeyPair> getOrCreateScannerKeyPair(String scannerId) async {
    final key = '$_scannerPrefix$scannerId';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) {
      return _crypto.keyPairFromSeedBase64Url(existing);
    }
    final pair = await _crypto.generateKeyPair();
    final seed = await _crypto.privateKeySeedBase64Url(pair);
    await _storage.write(key: key, value: seed);
    return pair;
  }

  Future<void> deleteMemberKey(String deviceId) =>
      _storage.delete(key: '$_memberPrefix$deviceId');

  Future<void> deleteScannerKey(String scannerId) =>
      _storage.delete(key: '$_scannerPrefix$scannerId');
}
