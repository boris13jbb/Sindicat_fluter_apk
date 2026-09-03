import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_models.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_validator.dart';
import 'package:fluter_apk/core/security/attendance_qr/trusted_offline_clock.dart';
import 'package:fluter_apk/services/offline_attendance_store.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

/// Fixed TEST seed — NEVER production.
const _testSeedB64 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _FakeUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

/// Exercises the same entry point SecureScannerScreen uses:
/// [SecureAttendanceQrService.validateAndStoreScannedQr].
void main() {
  late SecureQrCrypto crypto;
  late SimpleKeyPair memberKeys;
  late String memberPub;
  late SecureAttendanceOfflineStore store;
  late SecureAttendanceQrService service;
  late AttendanceOfflinePackage package;
  late TrustedOfflineClock clock;

  setUp(() async {
    crypto = SecureQrCrypto();
    memberKeys = await crypto.keyPairFromSeedBase64Url(_testSeedB64);
    memberPub = await crypto.publicKeyBase64Url(memberKeys);

    final db = await databaseFactoryMemory.openDatabase(
      'satt2_scanner_entry_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    store = SecureAttendanceOfflineStore.memoryForTests(db);
    await store.saveDeviceMeta({
      'deviceId': 'dev1',
      'platform': 'test',
      'createdAt': 1,
    });

    service = _ScannerEntryService(store: store, crypto: crypto);

    final now = DateTime.now().millisecondsSinceEpoch;
    package = AttendanceOfflinePackage(
      packageId: 'pkg1',
      eventId: 'evt-a',
      eventName: 'Asamblea',
      startAt: 0,
      endAt: now + 86_400_000,
      issuedAtServer: now,
      expiresAt: now + 86_400_000,
      serverTimeAtPreparation: now,
      scannerId: 'scn1',
      scannerPublicKey: 'unused',
      participants: [
        OfflineParticipantSnapshot(
          memberId: 'mem1',
          memberDeviceId: 'dev1',
          memberPublicKey: memberPub,
          credentialId: 'cred1',
          status: 'active',
          displayName: 'Socio',
          memberNumber: '1',
        ),
      ],
      signature: 'sig',
      keyVersion: 'v1',
    );
    clock = TrustedOfflineClock(
      serverTimeAtPreparationMs: now,
      deviceTimeAtPreparationMs: now,
    );
  });

  Future<Satt2MemberQr> makeQr({String eventId = 'evt-a', int? issuedAt}) {
    return Satt2MemberQr.create(
      eventId: eventId,
      memberDeviceId: 'dev1',
      credentialId: 'cred1',
      memberKeyPair: memberKeys,
      issuedAtMs: issuedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  test('scanner entry: SATT2M válido → VALID', () async {
    final qr = await makeQr();
    final result = await service.validateAndStoreScannedQr(
      rawQr: qr.toQrString(),
      package: package,
      clock: clock,
    );
    expect(result.rejected, isFalse, reason: 'rejected=${result.reason}');
    expect(result.receipt?.qrMode, kSatt2MemberType);
    expect(result.participant?.memberId, 'mem1');
  });

  test('scanner entry: SATT2M expirado → EXPIRED', () async {
    final issued = DateTime.now().millisecondsSinceEpoch - 60_000;
    final qr = await makeQr(issuedAt: issued);
    final result = await service.validateAndStoreScannedQr(
      rawQr: qr.toQrString(),
      package: package,
      clock: clock,
    );
    expect(result.reason, SecureQrRejectReason.expired);
  });

  test('scanner entry: SATT2M wrong event → WRONG_EVENT', () async {
    final qr = await makeQr(eventId: 'evt-other');
    final result = await service.validateAndStoreScannedQr(
      rawQr: qr.toQrString(),
      package: package,
      clock: clock,
    );
    expect(result.reason, SecureQrRejectReason.wrongEvent);
  });

  test('scanner entry: legacy workerCode → REJECTED', () async {
    final result = await service.validateAndStoreScannedQr(
      rawQr: '{"identificador":"WC-99","tipo":"miembro"}',
      package: package,
      clock: clock,
    );
    expect(result.reason, SecureQrRejectReason.legacyQr);
  });
}

/// Service that signs receipts without FlutterSecureStorage.
class _ScannerEntryService extends SecureAttendanceQrService {
  _ScannerEntryService({
    required SecureAttendanceOfflineStore store,
    required SecureQrCrypto crypto,
  }) : _crypto = crypto,
       _store = store,
       super(
         auth: _FakeAuth(),
         store: store,
         crypto: crypto,
         httpClient: MockClient(
           (_) async => http.Response(
             '{}',
             200,
             headers: {'content-type': 'application/json'},
           ),
         ),
         apiBaseUrl: 'http://test.local/api',
         requireAppCheckHeader: false,
         appCheckTokenProvider: () async => null,
       );

  final SecureQrCrypto _crypto;
  final SecureAttendanceOfflineStore _store;
  SimpleKeyPair? _scannerKeys;

  Future<SimpleKeyPair> _scanner() async {
    // Valid 32-byte TEST seed (all 0x01) — NEVER production.
    return _scannerKeys ??= await _crypto.keyPairFromSeedBase64Url(
      'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE',
    );
  }

  @override
  Future<SecureScanValidationResult> validateAndStoreMemberQr({
    required String memberQr,
    required AttendanceOfflinePackage package,
    required TrustedOfflineClock clock,
    double? scanLatitude,
    double? scanLongitude,
    double? scanAccuracyMeters,
  }) async {
    final validator = SecureQrValidator();
    final usedNonces = await _store.usedResponseNonces();
    final usedSigs = await _store.usedSignatureHashes();
    final members = await _store.memberIdsRegisteredForEvent(package.eventId);
    final scannerKeys = await _scanner();

    final result = await validator.validateMemberQr(
      rawQr: memberQr,
      package: package,
      nowTrustedMs: clock.nowTrustedMs(),
      usedResponseNonces: usedNonces,
      usedSignatureHashes: usedSigs,
      existingMemberIdsForEvent: members,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      scanAccuracyMeters: scanAccuracyMeters,
      signReceipt: (fields) =>
          _crypto.signReceipt(fields: fields, keyPair: scannerKeys),
    );

    if (!result.rejected && result.receipt != null) {
      await _store.saveReceipt(result.receipt!);
    }
    return result;
  }
}
