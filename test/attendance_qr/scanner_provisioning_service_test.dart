import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fluter_apk/core/security/attendance_qr/secure_key_store.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

// TEST KEY - NEVER USE IN PRODUCTION.
const _testScannerSeed = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'operator-1';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'test-id-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeKeyStore extends Fake implements SecureKeyStore {
  _FakeKeyStore(this.keyPair);

  final SimpleKeyPair keyPair;
  final requestedScannerIds = <String>[];

  @override
  Future<SimpleKeyPair> getOrCreateScannerKeyPair(String scannerId) async {
    requestedScannerIds.add(scannerId);
    return keyPair;
  }
}

void main() {
  late SecureQrCrypto crypto;
  late SimpleKeyPair scannerKeyPair;
  late String scannerPublicKey;
  late _FakeKeyStore keyStore;

  setUp(() async {
    crypto = SecureQrCrypto();
    scannerKeyPair = await crypto.keyPairFromSeedBase64Url(_testScannerSeed);
    scannerPublicKey = await crypto.publicKeyBase64Url(scannerKeyPair);
    keyStore = _FakeKeyStore(scannerKeyPair);
  });

  test(
    'registerScannerDevice sends canonical public identity with Auth and App Check',
    () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'scannerId': 'scanner-1',
            'status': 'pending',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        keyStore: keyStore,
        crypto: crypto,
        httpClient: client,
        apiBaseUrl: 'https://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async => 'test-app-check-token',
      );

      final result = await service.registerScannerDevice(
        scannerId: 'scanner-1',
        deviceLabel: 'Mesa principal',
      );

      expect(result.status, ScannerProvisioningStatus.pending);
      expect(keyStore.requestedScannerIds, ['scanner-1']);
      expect(seen!.url.path, '/api/attendance-register-scanner-device');
      expect(seen!.headers['authorization'], 'Bearer test-id-token');
      expect(seen!.headers['x-firebase-appcheck'], 'test-app-check-token');
      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      expect(body['scannerId'], 'scanner-1');
      expect(body['publicKey'], scannerPublicKey);
      expect(body['platform'], kIsWeb ? 'web' : defaultTargetPlatform.name);
      expect(body['deviceLabel'], 'Mesa principal');
      expect(body['approve'], isFalse);
      expect(body.containsKey('privateKey'), isFalse);
      expect(body.containsKey('seed'), isFalse);
      expect(seen!.body.contains(_testScannerSeed), isFalse);
    },
  );

  test('admin self-registration requests approve=true', () async {
    Map<String, dynamic>? body;
    final service = SecureAttendanceQrService(
      auth: _FakeAuth(),
      keyStore: keyStore,
      crypto: crypto,
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'scannerId': 'scanner-admin',
            'status': 'active',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      apiBaseUrl: 'https://test.local/api',
      requireAppCheckHeader: true,
      appCheckTokenProvider: () async => 'test-app-check-token',
    );

    final result = await service.registerScannerDevice(
      scannerId: 'scanner-admin',
      approve: true,
    );

    expect(result.status, ScannerProvisioningStatus.active);
    expect(body!['approve'], isTrue);
    expect(body!.containsKey('privateKey'), isFalse);
  });

  test('approveScannerDevice uses the existing protected endpoint', () async {
    http.Request? seen;
    final service = SecureAttendanceQrService(
      auth: _FakeAuth(),
      keyStore: keyStore,
      crypto: crypto,
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'scannerId': 'scanner-1',
            'status': 'active',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      apiBaseUrl: 'https://test.local/api',
      requireAppCheckHeader: true,
      appCheckTokenProvider: () async => 'test-app-check-token',
    );

    final result = await service.approveScannerDevice(scannerId: ' scanner-1 ');

    expect(result.isActive, isTrue);
    expect(seen!.url.path, '/api/attendance-approve-scanner-device');
    expect(seen!.headers['authorization'], 'Bearer test-id-token');
    expect(seen!.headers['x-firebase-appcheck'], 'test-app-check-token');
    expect(jsonDecode(seen!.body), {'scannerId': 'scanner-1'});
  });

  test('scanner API errors map to non-sensitive user messages', () {
    expect(
      SecureAttendanceQrService.userFacingActivationError(
        SecureAttendanceApiException('scanner-revoked'),
      ),
      'Este dispositivo ya no está autorizado como escáner.',
    );
    expect(
      SecureAttendanceQrService.userFacingActivationError(
        SecureAttendanceApiException('scanner-key-mismatch'),
      ),
      contains('identidad segura'),
    );
    expect(
      SecureAttendanceQrService.userFacingActivationError(
        SecureAttendanceApiException('only-admin-can-approve-scanner'),
      ),
      contains('administrador'),
    );
  });
}
