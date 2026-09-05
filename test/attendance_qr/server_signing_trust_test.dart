import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:fluter_apk/core/security/attendance_qr/secure_key_store.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/core/security/attendance_qr/server_signed_artifact_verifier.dart';
import 'package:fluter_apk/core/security/attendance_qr/trusted_server_keyring.dart';
import 'package:fluter_apk/core/security/attendance_qr/trusted_offline_clock.dart';
import 'package:fluter_apk/services/offline_attendance_store.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

// TEST KEYS - NEVER USE IN PRODUCTION.
const _serverSeedV1 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _serverSeedV2 = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE';
const _memberSeed = 'AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI';
const _scannerSeed = 'AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwM';
const _enrolledDeviceMeta = <String, dynamic>{
  'deviceId': 'device-1',
  'enrolledUid': 'user-1',
  'memberId': 'member-1',
};

class _FakeUser extends Fake implements User {
  _FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(String uid) : _user = _FakeUser(uid);

  final User _user;

  @override
  User? get currentUser => _user;
}

class _FixedSecureKeyStore extends SecureKeyStore {
  _FixedSecureKeyStore({required this.memberKeys, required this.scannerKeys});

  final SimpleKeyPair memberKeys;
  final SimpleKeyPair scannerKeys;

  @override
  Future<SimpleKeyPair> getOrCreateMemberKeyPair(String deviceId) async =>
      memberKeys;

  @override
  Future<SimpleKeyPair> getOrCreateScannerKeyPair(String scannerId) async =>
      scannerKeys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureQrCrypto crypto;
  late SimpleKeyPair serverV1;
  late SimpleKeyPair serverV2;
  late SimpleKeyPair memberKeys;
  late SimpleKeyPair scannerKeys;
  late String serverPublicV1;
  late String serverPublicV2;
  late String memberPublic;
  late String scannerPublic;
  late TrustedServerPublicKeyring keyring;
  late ServerSignedArtifactVerifier verifier;

  setUp(() async {
    crypto = SecureQrCrypto();
    serverV1 = await crypto.keyPairFromSeedBase64Url(_serverSeedV1);
    serverV2 = await crypto.keyPairFromSeedBase64Url(_serverSeedV2);
    memberKeys = await crypto.keyPairFromSeedBase64Url(_memberSeed);
    scannerKeys = await crypto.keyPairFromSeedBase64Url(_scannerSeed);
    serverPublicV1 = await crypto.publicKeyBase64Url(serverV1);
    serverPublicV2 = await crypto.publicKeyBase64Url(serverV2);
    memberPublic = await crypto.publicKeyBase64Url(memberKeys);
    scannerPublic = await crypto.publicKeyBase64Url(scannerKeys);
    keyring = TrustedServerPublicKeyring.parse(
      'v1:$serverPublicV1,v2:$serverPublicV2',
    );
    verifier = ServerSignedArtifactVerifier(keyring: keyring, crypto: crypto);
  });

  String nonCanonicalEquivalent(String value) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final index = alphabet.indexOf(value[value.length - 1]);
    return '${value.substring(0, value.length - 1)}${alphabet[index + 1]}';
  }

  Future<Map<String, dynamic>> signedCredential({
    String keyVersion = 'v1',
    SimpleKeyPair? signingKey,
    String? responsePublicKey,
    int? nowMs,
    int? issuedAtMs,
    int? expiresAtMs,
    String uid = 'user-1',
    String memberId = 'member-1',
    String memberDeviceId = 'device-1',
    String? credentialMemberPublicKey,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final issuedAt = issuedAtMs ?? now - 1000;
    final expiresAt =
        expiresAtMs ?? issuedAt + const Duration(days: 7).inMilliseconds;
    final fields = <String, String>{
      'v': '2',
      'type': 'SATT2CRED',
      'credentialId': 'credential-1',
      'uid': uid,
      'memberId': memberId,
      'memberDeviceId': memberDeviceId,
      'memberPublicKey': credentialMemberPublicKey ?? memberPublic,
      'issuedAtServer': '$issuedAt',
      'expiresAt': '$expiresAt',
      'keyVersion': keyVersion,
    };
    final key = signingKey ?? (keyVersion == 'v2' ? serverV2 : serverV1);
    return {
      ...fields,
      'signature': await crypto.signUtf8(
        canonicalPayload: canonicalCredentialPayload(fields),
        keyPair: key,
      ),
      'serverPublicKey':
          responsePublicKey ?? await crypto.publicKeyBase64Url(key),
    };
  }

  Future<Map<String, dynamic>> signedPackage({
    String keyVersion = 'v1',
    SimpleKeyPair? signingKey,
    String? responsePublicKey,
    int? nowMs,
    int? startAtMs,
    int? endAtMs,
    int? issuedAtMs,
    int? expiresAtMs,
    int? serverTimeAtPreparationMs,
    String eventId = 'event-1',
    String scannerId = 'scanner-1',
    String? packageScannerPublicKey,
    List<Map<String, dynamic>>? packageParticipants,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final participants =
        packageParticipants ??
        <Map<String, dynamic>>[
          {
            'memberId': 'member-1',
            'memberDeviceId': 'device-1',
            'memberPublicKey': memberPublic,
            'credentialId': 'credential-1',
            'status': 'active',
            'displayName': 'Test Member',
            'memberNumber': '100',
            'workerCode': 'W100',
          },
        ];
    final participantHash = await verifier.participantsHash(participants);
    final issuedAt = issuedAtMs ?? now - 1000;
    final startAt = startAtMs ?? now - 3600000;
    final endAt = endAtMs ?? now + 3600000;
    final maximumExpiry =
        (endAt > issuedAt ? endAt : issuedAt) +
        const Duration(hours: 2).inMilliseconds;
    final fields = <String, String>{
      'v': '2',
      'type': 'SATT2PKG',
      'packageId': 'package-1',
      'eventId': eventId,
      'eventName': 'Assembly',
      'startAt': '$startAt',
      'endAt': '$endAt',
      'issuedAtServer': '$issuedAt',
      'expiresAt': '${expiresAtMs ?? maximumExpiry}',
      'serverTimeAtPreparation': '${serverTimeAtPreparationMs ?? issuedAt}',
      'scannerId': scannerId,
      'scannerPublicKey': packageScannerPublicKey ?? scannerPublic,
      'geofenceEnabled': '1',
      'latitude': '-0.1807',
      'longitude': '-78.4678',
      'geofenceRadiusMeters': '150',
      'requireScannerLocation': '1',
      'participantsHash': participantHash,
      'keyVersion': keyVersion,
    };
    final key = signingKey ?? (keyVersion == 'v2' ? serverV2 : serverV1);
    return {
      'v': fields['v'],
      'type': fields['type'],
      'packageId': fields['packageId'],
      'eventId': fields['eventId'],
      'eventName': fields['eventName'],
      'startAt': int.parse(fields['startAt']!),
      'endAt': int.parse(fields['endAt']!),
      'issuedAtServer': int.parse(fields['issuedAtServer']!),
      'expiresAt': int.parse(fields['expiresAt']!),
      'serverTimeAtPreparation': int.parse(fields['serverTimeAtPreparation']!),
      'scannerId': fields['scannerId'],
      'scannerPublicKey': fields['scannerPublicKey'],
      'geofence': {
        'enabled': true,
        'latitude': -0.1807,
        'longitude': -78.4678,
        'radiusMeters': 150,
        'requireScannerLocation': true,
      },
      'participants': participants,
      'participantsHash': participantHash,
      'keyVersion': keyVersion,
      'signature': await crypto.signUtf8(
        canonicalPayload: canonicalPackagePayload(fields),
        keyPair: key,
      ),
      'serverPublicKey':
          responsePublicKey ?? await crypto.publicKeyBase64Url(key),
    };
  }

  Map<String, dynamic> deepCopy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  Future<SecureAttendanceOfflineStore> memoryStore(String name) async {
    final db = await databaseFactoryMemory.openDatabase(
      '${name}_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    return SecureAttendanceOfflineStore.memoryForTests(db);
  }

  SecureAttendanceQrService serviceFor({
    required SecureAttendanceOfflineStore store,
    required Map<String, dynamic> response,
    TrustedServerPublicKeyring? trustedKeys,
    SimpleKeyPair? localScannerKeys,
  }) {
    return SecureAttendanceQrService(
      auth: _FakeAuth('user-1'),
      store: store,
      keyStore: _FixedSecureKeyStore(
        memberKeys: memberKeys,
        scannerKeys: localScannerKeys ?? scannerKeys,
      ),
      crypto: crypto,
      trustedServerKeyring: trustedKeys ?? keyring,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      apiBaseUrl: 'http://test.local/api',
      requireAppCheckHeader: false,
      appCheckTokenProvider: () async => null,
    );
  }

  group('strict canonical base64url', () {
    test(
      'private seeds and public keys require canonical 32-byte encoding',
      () {
        for (final valid in [_serverSeedV1, serverPublicV1]) {
          expect(
            () => SecureQrCrypto.canonicalBase64UrlToBytes(
              valid,
              expectedLength: SecureQrCrypto.ed25519KeyBytes,
            ),
            returnsNormally,
          );
          for (final invalid in [
            '$valid=',
            '+${valid.substring(1)}',
            '/${valid.substring(1)}',
            ' $valid',
            '\t$valid',
            '$valid\n',
            valid.substring(0, 42),
            '${valid}A',
            SecureQrCrypto.bytesToBase64Url(List<int>.filled(31, 0)),
            SecureQrCrypto.bytesToBase64Url(List<int>.filled(33, 0)),
            nonCanonicalEquivalent(valid),
          ]) {
            expect(
              () => SecureQrCrypto.canonicalBase64UrlToBytes(
                invalid,
                expectedLength: SecureQrCrypto.ed25519KeyBytes,
              ),
              throwsFormatException,
            );
          }
        }
      },
    );
  });

  group('versioned trusted server keyring', () {
    test('parses v1 and v2 and rejects duplicate or invalid entries', () {
      expect(keyring.publicKeyFor('v1'), serverPublicV1);
      expect(keyring.publicKeyFor('v2'), serverPublicV2);
      expect(
        () => TrustedServerPublicKeyring.parse(
          'v1:$serverPublicV1,v1:$serverPublicV2',
        ),
        throwsA(isA<AttendanceServerTrustException>()),
      );
      expect(
        () => TrustedServerPublicKeyring.parse('v1:$serverPublicV1='),
        throwsA(isA<AttendanceServerTrustException>()),
      );
      expect(
        () => TrustedServerPublicKeyring.parse(''),
        throwsA(
          isA<AttendanceServerTrustException>().having(
            (error) => error.code,
            'code',
            'attendance-server-trust-not-configured',
          ),
        ),
      );
      expect(
        () => keyring.publicKeyFor('v3'),
        throwsA(
          isA<AttendanceServerTrustException>().having(
            (error) => error.code,
            'code',
            'unknown-server-key-version',
          ),
        ),
      );

      for (final malformed in [
        'v1:',
        ':$serverPublicV1',
        'v1:$serverPublicV1,',
        ',v1:$serverPublicV1',
        'v1:$serverPublicV1,v2:',
        'v1:$serverPublicV1,garbage',
        ' v1:$serverPublicV1',
        'v1:$serverPublicV1 ',
        'v1\n:$serverPublicV1',
        'v1\r:$serverPublicV1',
      ]) {
        expect(
          () => TrustedServerPublicKeyring.parse(malformed),
          throwsA(isA<AttendanceServerTrustException>()),
          reason: malformed,
        );
      }
    });
  });

  group('server artifact verification and rotation', () {
    test('offline clock does not restart at package preparation time', () {
      final deviceNow = DateTime.now().millisecondsSinceEpoch;
      final clock = TrustedOfflineClock(
        serverTimeAtPreparationMs:
            deviceNow - const Duration(hours: 1).inMilliseconds,
        deviceTimeAtPreparationMs: deviceNow,
      );

      expect(clock.trustedTimeOffsetMs, 0);
      expect(
        clock.nowTrustedMs(),
        inInclusiveRange(deviceNow, deviceNow + 1000),
      );
      expect(
        clock.evaluate(
          deviceNowMs: deviceNow - const Duration(minutes: 11).inMilliseconds,
        ),
        ClockTrustState.clockUntrusted,
      );
    });

    test('v1 and v2 credentials and packages verify simultaneously', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await verifier.verifyCredential(
        await signedCredential(keyVersion: 'v1', nowMs: now),
        nowMs: now,
      );
      await verifier.verifyCredential(
        await signedCredential(keyVersion: 'v2', nowMs: now),
        nowMs: now,
      );
      await verifier.verifyPackage(
        await signedPackage(keyVersion: 'v1', nowMs: now),
        nowMs: now,
      );
      await verifier.verifyPackage(
        await signedPackage(keyVersion: 'v2', nowMs: now),
        nowMs: now,
      );
    });

    test('unknown v3 and wrong pinned key fail closed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final unknown = await signedCredential(
        keyVersion: 'v3',
        signingKey: serverV1,
        nowMs: now,
      );
      await expectLater(
        verifier.verifyCredential(unknown, nowMs: now),
        throwsA(
          isA<AttendanceServerTrustException>().having(
            (error) => error.code,
            'code',
            'unknown-server-key-version',
          ),
        ),
      );

      final wrongPin = ServerSignedArtifactVerifier(
        keyring: TrustedServerPublicKeyring.parse('v1:$serverPublicV2'),
        crypto: crypto,
      );
      await expectLater(
        wrongPin.verifyCredential(
          await signedCredential(nowMs: now),
          nowMs: now,
        ),
        throwsA(isA<AttendanceServerTrustException>()),
      );
    });

    test('response-provided key cannot override the build pin', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final forged = await signedCredential(
        signingKey: serverV2,
        responsePublicKey: serverPublicV2,
        nowMs: now,
      );
      await expectLater(
        verifier.verifyCredential(forged, nowMs: now),
        throwsA(isA<AttendanceServerTrustException>()),
      );

      final forgedPackage = await signedPackage(
        signingKey: serverV2,
        responsePublicKey: serverPublicV2,
        nowMs: now,
      );
      await expectLater(
        verifier.verifyPackage(forgedPackage, nowMs: now),
        throwsA(isA<AttendanceServerTrustException>()),
      );
    });

    test(
      'valid signatures remain bound to local credential identity',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final credential = await signedCredential(nowMs: now);
        for (final verify in <Future<void> Function()>[
          () => verifier.verifyCredential(
            credential,
            nowMs: now,
            expectedUid: 'another-user',
          ),
          () => verifier.verifyCredential(
            credential,
            nowMs: now,
            expectedMemberId: 'another-member',
          ),
          () => verifier.verifyCredential(
            credential,
            nowMs: now,
            expectedMemberDeviceId: 'another-device',
          ),
          () => verifier.verifyCredential(
            credential,
            nowMs: now,
            expectedMemberPublicKey: serverPublicV2,
          ),
        ]) {
          await expectLater(
            verify(),
            throwsA(isA<AttendanceServerTrustException>()),
          );
        }
      },
    );

    test('valid package remains bound to the local scanner key', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final package = await signedPackage(nowMs: now);
      await verifier.verifyPackage(
        package,
        nowMs: now,
        expectedScannerPublicKey: scannerPublic,
      );
      await expectLater(
        verifier.verifyPackage(
          package,
          nowMs: now,
          expectedScannerPublicKey: serverPublicV2,
        ),
        throwsA(isA<AttendanceServerTrustException>()),
      );
    });

    test('future and overlong signed validity windows fail closed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const skewMs = 5 * 60 * 1000;
      const credentialMaxMs = 7 * 24 * 60 * 60 * 1000;
      const packageMarginMs = 2 * 60 * 60 * 1000;

      final futureCredentialIssuedAt = now + skewMs + 1;
      final invalidCredentials = [
        await signedCredential(
          nowMs: now,
          issuedAtMs: futureCredentialIssuedAt,
          expiresAtMs: futureCredentialIssuedAt + credentialMaxMs,
        ),
        await signedCredential(
          nowMs: now,
          issuedAtMs: now - 1000,
          expiresAtMs: now - 1000 + credentialMaxMs + 1,
        ),
      ];
      for (final credential in invalidCredentials) {
        await expectLater(
          verifier.verifyCredential(credential, nowMs: now),
          throwsA(isA<AttendanceServerTrustException>()),
        );
      }

      final futurePackageIssuedAt = now + skewMs + 1;
      final futureEndAt = futurePackageIssuedAt + 60 * 60 * 1000;
      final invalidPackages = [
        await signedPackage(
          nowMs: now,
          issuedAtMs: futurePackageIssuedAt,
          serverTimeAtPreparationMs: futurePackageIssuedAt,
          startAtMs: futurePackageIssuedAt,
          endAtMs: futureEndAt,
          expiresAtMs: futureEndAt + packageMarginMs,
        ),
        await signedPackage(nowMs: now, serverTimeAtPreparationMs: now - 2000),
        await signedPackage(
          nowMs: now,
          expiresAtMs: now + 3 * 60 * 60 * 1000 + 1,
        ),
      ];
      for (final package in invalidPackages) {
        await expectLater(
          verifier.verifyPackage(package, nowMs: now),
          throwsA(isA<AttendanceServerTrustException>()),
        );
      }
    });

    test(
      'participant ordering is defined and duplicate devices reject',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final participants = <Map<String, dynamic>>[
          {
            'memberId': 'member-1',
            'memberDeviceId': 'device-1',
            'memberPublicKey': memberPublic,
            'credentialId': 'credential-1',
            'status': 'active',
            'displayName': 'First Member',
            'memberNumber': '100',
            'workerCode': 'W100',
          },
          {
            'memberId': 'member-2',
            'memberDeviceId': 'device-2',
            'memberPublicKey': memberPublic,
            'credentialId': 'credential-2',
            'status': 'active',
            'displayName': 'Second Member',
            'memberNumber': '200',
            'workerCode': 'W200',
          },
        ];
        final package = await signedPackage(
          nowMs: now,
          packageParticipants: participants,
        );
        package['participants'] = participants.reversed.toList();
        await verifier.verifyPackage(package, nowMs: now);

        final participantMutations = <List<Map<String, dynamic>>>[
          [Map<String, dynamic>.from(participants.first)],
          [
            ...participants,
            {...participants.first, 'memberDeviceId': 'device-3'},
          ],
          [
            {...participants.first, 'memberId': 'member-tampered'},
            participants.last,
          ],
          [
            {...participants.first, 'status': 'inactive'},
            participants.last,
          ],
        ];
        for (final mutatedParticipants in participantMutations) {
          final tampered = deepCopy(package);
          tampered['participants'] = mutatedParticipants;
          await expectLater(
            verifier.verifyPackage(tampered, nowMs: now),
            throwsA(isA<AttendanceServerTrustException>()),
          );
        }

        await expectLater(
          verifier.participantsHash([participants.first, participants.first]),
          throwsA(isA<AttendanceServerTrustException>()),
        );
      },
    );

    test('one-byte credential and package mutations fail', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final credential = await signedCredential(nowMs: now);
      credential['memberId'] = 'member-2';
      await expectLater(
        verifier.verifyCredential(credential, nowMs: now),
        throwsA(isA<AttendanceServerTrustException>()),
      );

      final package = await signedPackage(nowMs: now);
      package['eventId'] = 'event-2';
      await expectLater(
        verifier.verifyPackage(package, nowMs: now),
        throwsA(isA<AttendanceServerTrustException>()),
      );
    });

    test('participant metadata mutation breaks participantsHash', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final package = await signedPackage(nowMs: now);
      final participants = package['participants'] as List;
      final first = Map<String, dynamic>.from(participants.first as Map);
      first['displayName'] = 'Tampered Member';
      package['participants'] = [first];
      await expectLater(
        verifier.verifyPackage(package, nowMs: now),
        throwsA(isA<AttendanceServerTrustException>()),
      );
    });

    test(
      'expired signed artifacts and valid wrong scope fail closed',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiredCredential = await signedCredential(
          nowMs: now - const Duration(days: 8).inMilliseconds,
        );
        await expectLater(
          verifier.verifyCredential(expiredCredential, nowMs: now),
          throwsA(isA<AttendanceServerTrustException>()),
        );

        final expiredPackage = await signedPackage(
          nowMs: now - const Duration(hours: 3).inMilliseconds,
        );
        await expectLater(
          verifier.verifyPackage(expiredPackage, nowMs: now),
          throwsA(isA<AttendanceServerTrustException>()),
        );

        final credential = await signedCredential(nowMs: now);
        await expectLater(
          verifier.verifyCredential(
            credential,
            nowMs: now,
            expectedMemberDeviceId: 'another-device',
          ),
          throwsA(isA<AttendanceServerTrustException>()),
        );

        final package = await signedPackage(nowMs: now);
        await expectLater(
          verifier.verifyPackage(
            package,
            nowMs: now,
            expectedEventId: 'another-event',
          ),
          throwsA(isA<AttendanceServerTrustException>()),
        );
        await expectLater(
          verifier.verifyPackage(
            package,
            nowMs: now,
            expectedScannerId: 'another-scanner',
          ),
          throwsA(isA<AttendanceServerTrustException>()),
        );
      },
    );
  });

  group('fresh and stored artifacts', () {
    test('fresh credential is verified before storage', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('fresh_credential');
      await store.saveDeviceMeta(_enrolledDeviceMeta);
      final credential = await signedCredential(nowMs: now);
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'credential': credential},
      );

      await service.prepareOfflineCredential(preparedAtClient: now);
      expect(await store.loadActiveCredential(), credential);
    });

    test(
      'enrollment pins the authenticated member in local metadata',
      () async {
        final store = await memoryStore('enrollment_member_binding');
        await store.saveDeviceMeta({'deviceId': 'device-1'});
        final service = serviceFor(
          store: store,
          response: {
            'ok': true,
            'deviceId': 'device-1',
            'memberId': 'member-1',
            'status': 'active',
          },
        );

        await service.enrollMemberDevice();
        expect(await store.loadDeviceMeta(), _enrolledDeviceMeta);
      },
    );

    test('fresh credential for another member is never stored', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('wrong_member_credential');
      await store.saveDeviceMeta(_enrolledDeviceMeta);
      final credential = await signedCredential(
        nowMs: now,
        memberId: 'member-2',
      );
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'credential': credential},
      );

      await expectLater(
        service.prepareOfflineCredential(preparedAtClient: now),
        throwsA(isA<SecureAttendanceApiException>()),
      );
      expect(await store.loadActiveCredential(), isNull);
    });

    test('invalid fresh credential is never stored', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('bad_fresh_credential');
      await store.saveDeviceMeta(_enrolledDeviceMeta);
      final credential = await signedCredential(nowMs: now);
      credential['memberId'] = 'tampered';
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'credential': credential},
      );

      await expectLater(
        service.prepareOfflineCredential(preparedAtClient: now),
        throwsA(
          isA<SecureAttendanceApiException>().having(
            (error) => error.code,
            'code',
            'invalid-server-credential-signature',
          ),
        ),
      );
      expect(await store.loadActiveCredential(), isNull);
    });

    test('fresh package is verified before storage', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('fresh_package');
      final package = await signedPackage(nowMs: now);
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'package': package},
      );

      await service.prepareOfflineEvent(
        eventId: 'event-1',
        scannerId: 'scanner-1',
      );
      expect(await store.loadActivePackage(), package);
    });

    test('invalid fresh package is never stored', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('bad_fresh_package');
      final package = await signedPackage(nowMs: now);
      package['eventId'] = 'tampered';
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'package': package},
      );

      await expectLater(
        service.prepareOfflineEvent(eventId: 'event-1', scannerId: 'scanner-1'),
        throwsA(isA<SecureAttendanceApiException>()),
      );
      expect(await store.loadActivePackage(), isNull);
    });

    test('package for a different local scanner key is never stored', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final store = await memoryStore('wrong_local_scanner_key');
      final package = await signedPackage(nowMs: now);
      final service = serviceFor(
        store: store,
        response: {'ok': true, 'package': package},
        localScannerKeys: memberKeys,
      );

      await expectLater(
        service.prepareOfflineEvent(eventId: 'event-1', scannerId: 'scanner-1'),
        throwsA(isA<SecureAttendanceApiException>()),
      );
      expect(await store.loadActivePackage(), isNull);
    });

    test('stored credential tampering is rejected before reuse', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = await signedCredential(nowMs: now);
      final mutations = <void Function(Map<String, dynamic>)>[
        (map) => map['expiresAt'] = '${now + 1000}',
        (map) => map['memberId'] = 'member-2',
        (map) => map['memberPublicKey'] = serverPublicV2,
        (map) {
          final signature = map['signature'].toString();
          map['signature'] =
              '${signature.startsWith('A') ? 'B' : 'A'}${signature.substring(1)}';
        },
        (map) => map['keyVersion'] = 'v3',
      ];

      for (var index = 0; index < mutations.length; index++) {
        final store = await memoryStore('tampered_credential_$index');
        await store.saveDeviceMeta(_enrolledDeviceMeta);
        final tampered = deepCopy(original);
        mutations[index](tampered);
        await store.saveCredential(tampered);
        final service = serviceFor(store: store, response: const {});
        await expectLater(
          service.loadVerifiedStoredCredential(nowMs: now),
          throwsA(isA<SecureAttendanceApiException>()),
        );
      }
    });

    test('stored package tampering is rejected before scanner use', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = await signedPackage(nowMs: now);
      final mutations = <void Function(Map<String, dynamic>)>[
        (map) => map['expiresAt'] = now + 1000,
        (map) => map['eventId'] = 'event-2',
        (map) {
          final participants = map['participants'] as List;
          final participant = Map<String, dynamic>.from(
            participants.first as Map,
          );
          participant['memberId'] = 'member-2';
          map['participants'] = [participant];
        },
        (map) {
          final signature = map['signature'].toString();
          map['signature'] =
              '${signature.startsWith('A') ? 'B' : 'A'}${signature.substring(1)}';
        },
        (map) => map['keyVersion'] = 'v3',
      ];

      for (var index = 0; index < mutations.length; index++) {
        final store = await memoryStore('tampered_package_$index');
        final tampered = deepCopy(original);
        mutations[index](tampered);
        await store.savePackage(tampered);
        final service = serviceFor(store: store, response: const {});
        await expectLater(
          service.loadVerifiedStoredPackage(
            expectedEventId: 'event-1',
            expectedScannerId: 'scanner-1',
            nowMs: now,
          ),
          throwsA(isA<SecureAttendanceApiException>()),
        );
      }
    });

    test(
      'missing build keyring blocks only the secure attendance flow',
      () async {
        final store = await memoryStore('missing_keyring');
        final service = SecureAttendanceQrService(
          auth: _FakeAuth('user-1'),
          store: store,
          keyStore: _FixedSecureKeyStore(
            memberKeys: memberKeys,
            scannerKeys: scannerKeys,
          ),
          crypto: crypto,
          trustedServerKeysConfiguration: '',
          httpClient: MockClient((_) async => http.Response('{}', 200)),
          apiBaseUrl: 'http://test.local/api',
          requireAppCheckHeader: false,
        );
        await expectLater(
          service.loadVerifiedStoredCredential(),
          throwsA(
            isA<SecureAttendanceApiException>().having(
              (error) => error.code,
              'code',
              'attendance-server-trust-not-configured',
            ),
          ),
        );
      },
    );
  });

  test('shared Node-Dart golden credential and package vectors pass', () async {
    final fixture =
        jsonDecode(
              File(
                'test/attendance_qr/golden_server_signing_vectors.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(fixture['warning'], 'TEST KEY - NEVER USE IN PRODUCTION');
    final fixturePublic = fixture['publicKeyBase64Url'] as String;
    final fixtureKeyring = TrustedServerPublicKeyring.parse(
      'v1:$fixturePublic',
    );
    final fixtureVerifier = ServerSignedArtifactVerifier(
      keyring: fixtureKeyring,
      crypto: crypto,
    );

    final fixturePair = await crypto.keyPairFromSeedBase64Url(
      fixture['privateSeedBase64Url'] as String,
    );
    expect(await crypto.publicKeyBase64Url(fixturePair), fixturePublic);

    final credentialFixture = Map<String, dynamic>.from(
      fixture['credential'] as Map,
    );
    final credentialFields = Map<String, String>.from(
      credentialFixture['fields'] as Map,
    );
    expect(
      canonicalCredentialPayload(credentialFields),
      credentialFixture['canonical'],
    );
    final credential = <String, dynamic>{
      ...credentialFields,
      'signature': credentialFixture['signature'],
      'serverPublicKey': fixturePublic,
    };
    await fixtureVerifier.verifyCredential(credential, nowMs: 1700000001000);

    final packageFixture = Map<String, dynamic>.from(fixture['package'] as Map);
    final packageFields = Map<String, String>.from(
      packageFixture['fields'] as Map,
    );
    expect(canonicalPackagePayload(packageFields), packageFixture['canonical']);
    final package = <String, dynamic>{
      'v': packageFields['v'],
      'type': packageFields['type'],
      'packageId': packageFields['packageId'],
      'eventId': packageFields['eventId'],
      'eventName': packageFields['eventName'],
      'startAt': packageFields['startAt'],
      'endAt': packageFields['endAt'],
      'issuedAtServer': packageFields['issuedAtServer'],
      'expiresAt': packageFields['expiresAt'],
      'serverTimeAtPreparation': packageFields['serverTimeAtPreparation'],
      'scannerId': packageFields['scannerId'],
      'scannerPublicKey': packageFields['scannerPublicKey'],
      'geofence': {
        'enabled': true,
        'latitude': -0.1807,
        'longitude': -78.4678,
        'radiusMeters': 150,
        'requireScannerLocation': true,
      },
      'participants': packageFixture['participants'],
      'participantsHash': packageFields['participantsHash'],
      'keyVersion': packageFields['keyVersion'],
      'signature': packageFixture['signature'],
      'serverPublicKey': fixturePublic,
    };
    expect(
      await fixtureVerifier.participantsHash(package['participants'] as List),
      packageFields['participantsHash'],
    );
    await fixtureVerifier.verifyPackage(package, nowMs: 1700000001000);

    package['eventId'] = 'golden-evenu';
    await expectLater(
      fixtureVerifier.verifyPackage(package, nowMs: 1700000001000),
      throwsA(isA<AttendanceServerTrustException>()),
    );
  });
}
