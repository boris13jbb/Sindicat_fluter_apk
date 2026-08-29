import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_models.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_validator.dart';
import 'package:fluter_apk/services/attendance_service.dart';

/// Fixed TEST seed (32 zero bytes) — NEVER production.
const _testSeedB64 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

AttendanceOfflinePackage _pkg({
  required String eventId,
  required OfflineParticipantSnapshot participant,
  int expiresAt = 9_999_999_999_999,
}) {
  return AttendanceOfflinePackage(
    packageId: 'pkg1',
    eventId: eventId,
    eventName: 'Test',
    startAt: 0,
    endAt: expiresAt,
    issuedAtServer: 1,
    expiresAt: expiresAt,
    serverTimeAtPreparation: 1_700_000_000_000,
    scannerId: 'scn1',
    scannerPublicKey: 'unused',
    participants: [participant],
    signature: 'sig',
    keyVersion: 'v1',
  );
}

void main() {
  final crypto = SecureQrCrypto();

  group('SATT2M member dynamic QR', () {
    late SimpleKeyPair memberKeys;
    late String memberPub;
    late OfflineParticipantSnapshot participant;

    setUp(() async {
      memberKeys = await crypto.keyPairFromSeedBase64Url(_testSeedB64);
      memberPub = await crypto.publicKeyBase64Url(memberKeys);
      participant = OfflineParticipantSnapshot(
        memberId: 'mem1',
        memberDeviceId: 'dev1',
        memberPublicKey: memberPub,
        credentialId: 'cred1',
        status: 'active',
        displayName: 'Socio Test',
        memberNumber: '001',
      );
    });

    test('1. active member + credential + event generates SATT2M', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      expect(qr.toQrString().startsWith('SATT2M.'), isTrue);
      expect(qr.eventId, 'evt-a');
      expect(await qr.verify(memberPub), isTrue);
    });

    test('2. QR changes after new timeWindow / nonce', () async {
      final a = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final b = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000 + kQrRotationSeconds * 1000,
      );
      expect(a.responseNonce == b.responseNonce, isFalse);
      expect(a.signature == b.signature, isFalse);
      expect(a.timeWindow == b.timeWindow, isFalse);
    });

    test('3. valid signature PASS', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.rejected, isFalse);
      expect(result.receipt?.qrMode, kSatt2MemberType);
    });

    test('4. false signature INVALID_SIGNATURE', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final tampered = Satt2MemberQr(
        eventId: qr.eventId,
        memberDeviceId: qr.memberDeviceId,
        credentialId: qr.credentialId,
        timeWindow: qr.timeWindow,
        issuedAt: qr.issuedAt,
        expiresAt: qr.expiresAt,
        responseNonce: qr.responseNonce,
        signature: 'AAAA${qr.signature.substring(4)}',
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: tampered.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.invalidSignature);
    });

    test('5. expired EXPIRED', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: qr.expiresAt + 1,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.expired);
    });

    test('6. wrong event WRONG_EVENT', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-b', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.wrongEvent);
    });

    test('7. used nonce REJECTED_REPLAY', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {qr.responseNonce},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.replay);
    });

    test('8. legacy workerCode REJECTED', () async {
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: '{"identificador":"WC-1","tipo":"miembro"}',
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.legacyQr);
    });

    test('9. inactive member REJECTED', () async {
      final inactive = OfflineParticipantSnapshot(
        memberId: 'mem1',
        memberDeviceId: 'dev1',
        memberPublicKey: memberPub,
        credentialId: 'cred1',
        status: 'inactive',
      );
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: inactive),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.inactiveMember);
    });

    test('10. revoked device REJECTED', () async {
      final revoked = OfflineParticipantSnapshot(
        memberId: 'mem1',
        memberDeviceId: 'dev1',
        memberPublicKey: memberPub,
        credentialId: 'cred1',
        status: 'revoked',
      );
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: revoked),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.revokedDevice);
    });

    test('11. duplicate attendance REJECTED', () async {
      final qr = await Satt2MemberQr.create(
        eventId: 'evt-a',
        memberDeviceId: 'dev1',
        credentialId: 'cred1',
        memberKeyPair: memberKeys,
        issuedAtMs: 1_700_000_000_000,
      );
      final result = await SecureQrValidator().validateMemberQr(
        rawQr: qr.toQrString(),
        package: _pkg(eventId: 'evt-a', participant: participant),
        nowTrustedMs: 1_700_000_000_500,
        usedResponseNonces: {},
        usedSignatureHashes: {},
        existingMemberIdsForEvent: {'mem1'},
        signReceipt: (_) async => 'scanner-sig',
      );
      expect(result.reason, SecureQrRejectReason.duplicateLocal);
    });

    test(
      '12/13. Web/offline: usable credential generates QR without network',
      () async {
        // Generation is local crypto only — no HTTP.
        final qr = await Satt2MemberQr.create(
          eventId: 'evt-web',
          memberDeviceId: 'dev1',
          credentialId: 'cred1',
          memberKeyPair: memberKeys,
          issuedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        expect(qr.toQrString().startsWith(kSatt2MemberType), isTrue);
        expect(qr.expiresAt - qr.issuedAt, kQrMaxValiditySeconds * 1000);
      },
    );

    test('canonical member payload is order-stable', () {
      expect(
        canonicalMemberQrPayload({
          'protocolVersion': '2',
          'v': '2',
          'type': 'SATT2M',
          'eventId': 'e1',
          'memberDeviceId': 'd1',
          'credentialId': 'c1',
          'timeWindow': '10',
          'issuedAt': '100',
          'expiresAt': '200',
          'responseNonce': 'n1',
        }),
        'v=2\n'
        'type=SATT2M\n'
        'eventId=e1\n'
        'memberDeviceId=d1\n'
        'credentialId=c1\n'
        'timeWindow=10\n'
        'issuedAt=100\n'
        'expiresAt=200\n'
        'responseNonce=n1\n'
        'protocolVersion=2',
      );
    });
  });

  group('event selector helpers', () {
    AttendanceEvent ev({
      required String id,
      required String nombre,
      required int fecha,
      String estado = 'programado',
      bool activo = true,
    }) {
      return AttendanceEvent(
        id: id,
        nombre: nombre,
        descripcion: '',
        fecha: fecha,
        lugar: '',
        tipo: 'reunion',
        activo: activo,
        miembrosConvocados: const [],
        creadoPor: 'u',
        createdAt: fecha,
        estado: estado,
      );
    }

    test('17/18. single event auto-select via pick helper', () {
      final only = [ev(id: 'e1', nombre: 'Asamblea', fecha: 100)];
      expect(AttendanceService.pickHighlightedOperationalEventId(only), 'e1');
    });

    test('multiple events prefer en_curso', () {
      final list = [
        ev(id: 'old', nombre: 'Old', fecha: 50),
        ev(id: 'live', nombre: 'Live', fecha: 40, estado: 'en_curso'),
      ];
      expect(AttendanceService.pickHighlightedOperationalEventId(list), 'live');
    });

    test('secureQrMode defaults to dynamic_member_qr', () {
      final e = AttendanceEvent.fromMap({
        'nombre': 'X',
        'descripcion': '',
        'fecha': 1,
        'lugar': '',
        'tipo': 'reunion',
        'activo': true,
        'miembrosConvocados': [],
        'creadoPor': 'u',
        'createdAt': 1,
      }, 'id1');
      expect(e.secureQrMode, kSecureQrModeDynamicMember);
    });
  });
}
