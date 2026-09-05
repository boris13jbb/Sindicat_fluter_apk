import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/security/attendance_qr/secure_key_store.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    values[key] = value!;
  }
}

void main() {
  test(
    'concurrent scanner creation across stores preserves one identity',
    () async {
      final storage = _MemoryStorage();
      final first = SecureKeyStore(storage: storage);
      final second = SecureKeyStore(storage: storage);
      final crypto = SecureQrCrypto();
      final keys = await Future.wait([
        first.getOrCreateScannerKeyPair('scanner-concurrent'),
        second.getOrCreateScannerKeyPair('scanner-concurrent'),
      ]);
      final publicKeys = await Future.wait(keys.map(crypto.publicKeyBase64Url));
      expect(publicKeys.toSet().length, 1);
      expect(storage.writes, 1);
      final reloaded = await first.getOrCreateScannerKeyPair(
        'scanner-concurrent',
      );
      expect(await crypto.publicKeyBase64Url(reloaded), publicKeys.first);
    },
  );

  test(
    'member and scanner identities have separate persistent namespaces',
    () async {
      final storage = _MemoryStorage();
      final store = SecureKeyStore(storage: storage);
      final crypto = SecureQrCrypto();
      final member = await store.getOrCreateMemberKeyPair('shared-device-id');
      final scanner = await store.getOrCreateScannerKeyPair('shared-device-id');
      expect(
        await crypto.publicKeyBase64Url(member),
        isNot(await crypto.publicKeyBase64Url(scanner)),
      );
      expect(
        storage.values.keys,
        unorderedEquals([
          'satt2_member_seed_shared-device-id',
          'satt2_scanner_seed_shared-device-id',
        ]),
      );
    },
  );

  test(
    'malformed existing scanner identity is rejected without regeneration',
    () async {
      final storage = _MemoryStorage();
      storage.values['satt2_scanner_seed_broken'] = 'invalid';
      final store = SecureKeyStore(storage: storage);
      await expectLater(
        store.getOrCreateScannerKeyPair('broken'),
        throwsFormatException,
      );
      expect(storage.writes, 0);
    },
  );
}
