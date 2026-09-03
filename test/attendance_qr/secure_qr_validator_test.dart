import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/security/attendance_qr/geofence_validator.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_models.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_validator.dart';

/// Fixed TEST seed (32 zero bytes) — NEVER production.
const _testSeedB64 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  final crypto = SecureQrCrypto();

  group('canonical serialization', () {
    test('challenge payload is order-stable', () {
      final fields = <String, String>{
        'protocolVersion': '2',
        'v': '2',
        'type': 'SATT2C',
        'eventId': 'evt1',
        'scannerId': 'scn1',
        'challengeId': 'cid1',
        'challengeNonce': 'nonce1',
        'issuedAtTrusted': '1000',
        'expiresAtTrusted': '16000',
      };
      expect(
        canonicalChallengePayload(fields),
        'v=2\n'
        'type=SATT2C\n'
        'eventId=evt1\n'
        'scannerId=scn1\n'
        'challengeId=cid1\n'
        'challengeNonce=nonce1\n'
        'issuedAtTrusted=1000\n'
        'expiresAtTrusted=16000\n'
        'protocolVersion=2',
      );
    });

    test('golden vector matches shared canonical file Dart↔Node', () async {
      final file = File('test/attendance_qr/golden_challenge_canonical.txt');
      expect(file.existsSync(), isTrue);
      final expected = file.readAsStringSync().trim().replaceAll('\r\n', '\n');
      final fields = <String, String>{
        'v': '2',
        'type': 'SATT2C',
        'eventId': 'golden-event',
        'scannerId': 'golden-scanner',
        'challengeId': 'golden-challenge',
        'challengeNonce': 'golden-nonce',
        'issuedAtTrusted': '1700000000000',
        'expiresAtTrusted': '1700000015000',
        'protocolVersion': '2',
      };
      expect(canonicalChallengePayload(fields), expected);
      final pair = await crypto.keyPairFromSeedBase64Url(_testSeedB64);
      final sig = await crypto.signUtf8(
        canonicalPayload: expected,
        keyPair: pair,
      );
      final pub = await crypto.publicKeyBase64Url(pair);
      expect(
        await crypto.verifyUtf8(
          canonicalPayload: expected,
          signatureBase64Url: sig,
          publicKeyBase64Url: pub,
        ),
        isTrue,
      );
      expect(
        await crypto.verifyUtf8(
          canonicalPayload: '$expected\nx',
          signatureBase64Url: sig,
          publicKeyBase64Url: pub,
        ),
        isFalse,
      );
    });

    test('golden vector: known seed signs known challenge payload', () async {
      final pair = await crypto.keyPairFromSeedBase64Url(_testSeedB64);
      final pub = await crypto.publicKeyBase64Url(pair);
      final fields = <String, String>{
        'v': '2',
        'type': 'SATT2C',
        'eventId': 'golden-event',
        'scannerId': 'golden-scanner',
        'challengeId': 'golden-challenge',
        'challengeNonce': 'golden-nonce',
        'issuedAtTrusted': '1700000000000',
        'expiresAtTrusted': '1700000015000',
        'protocolVersion': '2',
      };
      final canonical = canonicalChallengePayload(fields);
      final sig = await crypto.signUtf8(
        canonicalPayload: canonical,
        keyPair: pair,
      );
      expect(sig.isNotEmpty, isTrue);
      expect(
        await crypto.verifyUtf8(
          canonicalPayload: canonical,
          signatureBase64Url: sig,
          publicKeyBase64Url: pub,
        ),
        isTrue,
      );
      // Tamper one byte of payload → fail
      expect(
        await crypto.verifyUtf8(
          canonicalPayload: '${canonical}x',
          signatureBase64Url: sig,
          publicKeyBase64Url: pub,
        ),
        isFalse,
      );
      // Persist golden for Node cross-check (printed only in verbose)
      // ignore: avoid_print
      print('GOLDEN_PUB=$pub');
      // ignore: avoid_print
      print('GOLDEN_CANONICAL=$canonical');
      // ignore: avoid_print
      print('GOLDEN_SIG=$sig');
    });
  });

  group('SecureQrValidator', () {
    late SimpleKeyPair memberKeys;
    late SimpleKeyPair scannerKeys;
    late String memberPub;
    late String scannerPub;
    late AttendanceOfflinePackage package;
    late Satt2Challenge challenge;
    late Satt2Response response;
    const now = 1_700_000_010_000;

    setUp(() async {
      memberKeys = await crypto.generateKeyPair();
      scannerKeys = await crypto.generateKeyPair();
      memberPub = await crypto.publicKeyBase64Url(memberKeys);
      scannerPub = await crypto.publicKeyBase64Url(scannerKeys);

      package = AttendanceOfflinePackage(
        packageId: 'pkg1',
        eventId: 'event-a',
        eventName: 'Asamblea',
        startAt: now - 3600000,
        endAt: now + 3600000,
        issuedAtServer: now - 60000,
        expiresAt: now + 7200000,
        serverTimeAtPreparation: now - 60000,
        scannerId: 'scanner-a',
        scannerPublicKey: scannerPub,
        participants: [
          OfflineParticipantSnapshot(
            memberId: 'member-1',
            memberDeviceId: 'device-1',
            memberPublicKey: memberPub,
            credentialId: 'cred-1',
            status: 'active',
            displayName: 'Socio Uno',
            memberNumber: '10',
            workerCode: 'W10',
          ),
        ],
        signature: 'pkg-sig',
        keyVersion: 'v1',
      );

      challenge = await Satt2Challenge.create(
        eventId: 'event-a',
        scannerId: 'scanner-a',
        scannerKeyPair: scannerKeys,
        nowTrustedMs: now,
      );

      response = await Satt2Response.createFromChallenge(
        challenge: challenge,
        memberDeviceId: 'device-1',
        credentialId: 'cred-1',
        memberKeyPair: memberKeys,
        issuedAtMs: now + 1000,
      );
    });

    Future<SecureScanValidationResult> validate({
      String? raw,
      Satt2Challenge? ch,
      AttendanceOfflinePackage? pkg,
      int? trustedNow,
      Set<String>? usedChallenges,
      Set<String>? usedNonces,
      Set<String>? existingMembers,
      double? lat,
      double? lng,
      double? accuracy,
    }) {
      return SecureQrValidator().validateResponse(
        rawQr: raw ?? response.toQrString(),
        expectedChallenge: ch ?? challenge,
        package: pkg ?? package,
        nowTrustedMs: trustedNow ?? now + 2000,
        usedChallengeIds: usedChallenges ?? {},
        usedResponseNonces: usedNonces ?? {},
        existingMemberIdsForEvent: existingMembers ?? {},
        scanLatitude: lat,
        scanLongitude: lng,
        scanAccuracyMeters: accuracy,
        signReceipt: (fields) async =>
            crypto.signReceipt(fields: fields, keyPair: scannerKeys),
      );
    }

    test('valid response passes', () async {
      final r = await validate();
      expect(r.rejected, isFalse);
      expect(r.receipt, isNotNull);
      expect(r.participant?.memberId, 'member-1');
    });

    test('legacy QR rejected', () async {
      final r = await validate(raw: '{"identificador":"W10","nombres":"X"}');
      expect(r.reason, SecureQrRejectReason.legacyQr);
    });

    test('invalid signature rejected', () async {
      final forged = Satt2Response(
        eventId: response.eventId,
        scannerId: response.scannerId,
        challengeId: response.challengeId,
        challengeNonce: response.challengeNonce,
        memberDeviceId: response.memberDeviceId,
        credentialId: response.credentialId,
        responseNonce: response.responseNonce,
        issuedAt: response.issuedAt,
        signature: 'not-a-valid-signature',
      );
      final r = await validate(raw: forged.toQrString());
      expect(r.reason, SecureQrRejectReason.invalidSignature);
    });

    test('expired challenge rejected', () async {
      final r = await validate(trustedNow: challenge.expiresAtTrusted + 1);
      expect(r.reason, SecureQrRejectReason.expired);
    });

    test('replay rejected', () async {
      final first = await validate();
      expect(first.rejected, isFalse);
      final second = await validate(
        usedChallenges: {challenge.challengeId},
        usedNonces: {response.responseNonce},
      );
      expect(second.reason, SecureQrRejectReason.replay);
    });

    test('wrong event rejected', () async {
      final wrongPkg = AttendanceOfflinePackage(
        packageId: package.packageId,
        eventId: 'event-b',
        eventName: package.eventName,
        startAt: package.startAt,
        endAt: package.endAt,
        issuedAtServer: package.issuedAtServer,
        expiresAt: package.expiresAt,
        serverTimeAtPreparation: package.serverTimeAtPreparation,
        scannerId: package.scannerId,
        scannerPublicKey: package.scannerPublicKey,
        participants: package.participants,
        signature: package.signature,
        keyVersion: package.keyVersion,
      );
      final r = await validate(pkg: wrongPkg);
      expect(r.reason, SecureQrRejectReason.wrongEvent);
    });

    test('wrong scanner rejected', () async {
      final wrongChallenge = await Satt2Challenge.create(
        eventId: 'event-a',
        scannerId: 'scanner-b',
        scannerKeyPair: scannerKeys,
        nowTrustedMs: now,
      );
      final r = await validate(ch: wrongChallenge);
      expect(r.reason, SecureQrRejectReason.wrongScanner);
    });

    test('inactive member rejected', () async {
      final inactive = AttendanceOfflinePackage(
        packageId: package.packageId,
        eventId: package.eventId,
        eventName: package.eventName,
        startAt: package.startAt,
        endAt: package.endAt,
        issuedAtServer: package.issuedAtServer,
        expiresAt: package.expiresAt,
        serverTimeAtPreparation: package.serverTimeAtPreparation,
        scannerId: package.scannerId,
        scannerPublicKey: package.scannerPublicKey,
        participants: [
          OfflineParticipantSnapshot(
            memberId: 'member-1',
            memberDeviceId: 'device-1',
            memberPublicKey: memberPub,
            credentialId: 'cred-1',
            status: 'inactive',
          ),
        ],
        signature: package.signature,
        keyVersion: package.keyVersion,
      );
      final r = await validate(pkg: inactive);
      expect(r.reason, SecureQrRejectReason.inactiveMember);
    });

    test('revoked device rejected', () async {
      final revoked = AttendanceOfflinePackage(
        packageId: package.packageId,
        eventId: package.eventId,
        eventName: package.eventName,
        startAt: package.startAt,
        endAt: package.endAt,
        issuedAtServer: package.issuedAtServer,
        expiresAt: package.expiresAt,
        serverTimeAtPreparation: package.serverTimeAtPreparation,
        scannerId: package.scannerId,
        scannerPublicKey: package.scannerPublicKey,
        participants: [
          OfflineParticipantSnapshot(
            memberId: 'member-1',
            memberDeviceId: 'device-1',
            memberPublicKey: memberPub,
            credentialId: 'cred-1',
            status: 'revoked',
          ),
        ],
        signature: package.signature,
        keyVersion: package.keyVersion,
      );
      final r = await validate(pkg: revoked);
      expect(r.reason, SecureQrRejectReason.revokedDevice);
    });

    test('duplicate local rejected', () async {
      final r = await validate(existingMembers: {'member-1'});
      expect(r.reason, SecureQrRejectReason.duplicateLocal);
    });

    test('geofence outside rejected', () async {
      final geoPkg = AttendanceOfflinePackage(
        packageId: package.packageId,
        eventId: package.eventId,
        eventName: package.eventName,
        startAt: package.startAt,
        endAt: package.endAt,
        issuedAtServer: package.issuedAtServer,
        expiresAt: package.expiresAt,
        serverTimeAtPreparation: package.serverTimeAtPreparation,
        scannerId: package.scannerId,
        scannerPublicKey: package.scannerPublicKey,
        participants: package.participants,
        signature: package.signature,
        keyVersion: package.keyVersion,
        geofence: const GeofenceConfig(
          enabled: true,
          latitude: 0,
          longitude: 0,
          radiusMeters: 50,
          requireScannerLocation: true,
        ),
      );
      final r = await validate(pkg: geoPkg, lat: 1, lng: 1, accuracy: 10);
      expect(r.reason, SecureQrRejectReason.geofenceOutside);
    });

    test('geofence missing required blocked', () async {
      final geoPkg = AttendanceOfflinePackage(
        packageId: package.packageId,
        eventId: package.eventId,
        eventName: package.eventName,
        startAt: package.startAt,
        endAt: package.endAt,
        issuedAtServer: package.issuedAtServer,
        expiresAt: package.expiresAt,
        serverTimeAtPreparation: package.serverTimeAtPreparation,
        scannerId: package.scannerId,
        scannerPublicKey: package.scannerPublicKey,
        participants: package.participants,
        signature: package.signature,
        keyVersion: package.keyVersion,
        geofence: const GeofenceConfig(
          enabled: true,
          latitude: 0,
          longitude: 0,
          radiusMeters: 50,
          requireScannerLocation: true,
        ),
      );
      final r = await validate(pkg: geoPkg);
      expect(r.reason, SecureQrRejectReason.geofenceMissing);
    });
  });

  group('geofence distance', () {
    test('same point is ~0', () {
      final d = calculateDistanceMeters(
        lat1: -0.1807,
        lon1: -78.4678,
        lat2: -0.1807,
        lon2: -78.4678,
      );
      expect(d, lessThan(1));
    });
  });
}
