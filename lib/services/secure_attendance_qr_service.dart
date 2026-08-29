import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/security/attendance_qr/geofence_validator.dart';
import '../core/security/attendance_qr/secure_key_store.dart';
import '../core/security/attendance_qr/secure_qr_crypto.dart';
import '../core/security/attendance_qr/secure_qr_models.dart';
import '../core/security/attendance_qr/secure_qr_protocol.dart';
import '../core/security/attendance_qr/secure_qr_validator.dart';
import '../core/security/attendance_qr/trusted_offline_clock.dart';
import 'offline_attendance_store.dart';

/// Client façade for Secure Attendance QR V2 (enrollment, credential, package,
/// challenge/response, offline validate, sync).
class SecureAttendanceQrService {
  SecureAttendanceQrService({
    FirebaseAuth? auth,
    SecureAttendanceOfflineStore? store,
    SecureKeyStore? keyStore,
    SecureQrCrypto? crypto,
    http.Client? httpClient,
    String? apiBaseUrl,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _store = store ?? SecureAttendanceOfflineStore(),
       _keyStore = keyStore ?? SecureKeyStore(),
       _crypto = crypto ?? SecureQrCrypto(),
       _http = httpClient ?? http.Client(),
       _apiBase =
           apiBaseUrl ?? 'https://sistema-integrado-sindicato.web.app/api';

  final FirebaseAuth _auth;
  final SecureAttendanceOfflineStore _store;
  final SecureKeyStore _keyStore;
  final SecureQrCrypto _crypto;
  final http.Client _http;
  final String _apiBase;
  final _uuid = const Uuid();

  SecureAttendanceAssurance get assurance => _keyStore.detectAssurance();

  Future<String> _idToken() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('not-authenticated');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw StateError('missing-id-token');
    return token;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _idToken();
    final response = await _http.post(
      Uri.parse('$_apiBase$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('invalid-response');
    }
    if (response.statusCode >= 400 || decoded['ok'] != true) {
      throw StateError(
        decoded['code']?.toString() ?? 'http-${response.statusCode}',
      );
    }
    return decoded;
  }

  Future<String> ensureLocalDeviceId() async {
    final meta = await _store.loadDeviceMeta();
    final existing = meta?['deviceId']?.toString();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await _store.saveDeviceMeta({
      'deviceId': id,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  /// Enrolls device public key with backend and stores local meta.
  Future<void> enrollMemberDevice() async {
    final deviceId = await ensureLocalDeviceId();
    final pair = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    final publicKey = await _crypto.publicKeyBase64Url(pair);
    await _post('/attendance-enroll-member-device', {
      'deviceId': deviceId,
      'publicKey': publicKey,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  }

  /// Requests a server-signed offline credential (max 7 days).
  Future<Map<String, dynamic>> prepareOfflineCredential({
    int? preparedAtClient,
    bool? locationPermission,
    double? preparedLatitude,
    double? preparedLongitude,
    double? preparedAccuracyMeters,
  }) async {
    final deviceId = await ensureLocalDeviceId();
    // Ensure keys exist locally even if enroll was done earlier.
    await _keyStore.getOrCreateMemberKeyPair(deviceId);
    final result = await _post('/attendance-prepare-offline-credential', {
      'deviceId': deviceId,
      'preparedAtClient':
          preparedAtClient ?? DateTime.now().millisecondsSinceEpoch,
      'locationPermission': locationPermission,
      'preparedLatitude': preparedLatitude,
      'preparedLongitude': preparedLongitude,
      'preparedAccuracyMeters': preparedAccuracyMeters,
      'preparedLocationCapturedAt': preparedLatitude != null
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    });
    final credential = Map<String, dynamic>.from(result['credential'] as Map);
    await _store.saveCredential(credential);
    return credential;
  }

  Future<Map<String, dynamic>?> loadStoredCredential() =>
      _store.loadActiveCredential();

  Future<Map<String, dynamic>?> loadActiveOfflinePackage() =>
      _store.loadActivePackage();

  /// Operator: download signed offline package for an event + scanner.
  Future<Map<String, dynamic>> prepareOfflineEvent({
    required String eventId,
    required String scannerId,
  }) async {
    final result = await _post('/attendance-prepare-offline-event', {
      'eventId': eventId,
      'scannerId': scannerId,
    });
    final package = Map<String, dynamic>.from(result['package'] as Map);
    await _store.savePackage(package);
    return package;
  }

  AttendanceOfflinePackage? packageFromStored(Map<String, dynamic> raw) {
    try {
      final geofenceRaw = raw['geofence'] as Map<String, dynamic>? ?? {};
      final participants = (raw['participants'] as List? ?? [])
          .map(
            (e) => OfflineParticipantSnapshot.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      return AttendanceOfflinePackage(
        packageId: raw['packageId']?.toString() ?? '',
        eventId: raw['eventId']?.toString() ?? '',
        eventName: raw['eventName']?.toString() ?? '',
        startAt: (raw['startAt'] as num?)?.toInt() ?? 0,
        endAt: (raw['endAt'] as num?)?.toInt() ?? 0,
        issuedAtServer: (raw['issuedAtServer'] as num?)?.toInt() ?? 0,
        expiresAt: (raw['expiresAt'] as num?)?.toInt() ?? 0,
        serverTimeAtPreparation:
            (raw['serverTimeAtPreparation'] as num?)?.toInt() ?? 0,
        scannerId: raw['scannerId']?.toString() ?? '',
        scannerPublicKey: raw['scannerPublicKey']?.toString() ?? '',
        participants: participants,
        signature: raw['signature']?.toString() ?? '',
        keyVersion: raw['keyVersion']?.toString() ?? 'v1',
        geofence: GeofenceConfig(
          enabled: geofenceRaw['enabled'] == true,
          latitude: (geofenceRaw['latitude'] as num?)?.toDouble(),
          longitude: (geofenceRaw['longitude'] as num?)?.toDouble(),
          radiusMeters:
              (geofenceRaw['radiusMeters'] as num?)?.toDouble() ?? 150,
          requireScannerLocation: geofenceRaw['requireScannerLocation'] == true,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  TrustedOfflineClock clockForPackage(AttendanceOfflinePackage package) {
    final devicePrep = DateTime.now().millisecondsSinceEpoch;
    return TrustedOfflineClock(
      serverTimeAtPreparationMs: package.serverTimeAtPreparation,
      deviceTimeAtPreparationMs: devicePrep,
    );
  }

  Future<Satt2Challenge> createChallenge({
    required AttendanceOfflinePackage package,
    required TrustedOfflineClock clock,
  }) async {
    final scannerKeys = await _keyStore.getOrCreateScannerKeyPair(
      package.scannerId,
    );
    return Satt2Challenge.create(
      eventId: package.eventId,
      scannerId: package.scannerId,
      scannerKeyPair: scannerKeys,
      nowTrustedMs: clock.nowTrustedMs(),
    );
  }

  /// Member: scan SATT2C and produce SATT2R QR string.
  Future<Satt2Response> buildResponseForChallenge({
    required String challengeQr,
    String? memberLat,
    String? memberLng,
    String? memberAccuracy,
  }) async {
    if (Satt2WireCodec.isLegacyWorkerCodeQr(challengeQr) &&
        !challengeQr.trim().startsWith(kSatt2ChallengeType)) {
      throw StateError('legacy-qr');
    }
    final challenge = Satt2Challenge.tryParse(challengeQr);
    if (challenge == null) throw StateError('invalid-challenge');

    final credential = await _store.loadActiveCredential();
    if (credential == null) throw StateError('missing-credential');
    final expiresAt = int.tryParse('${credential['expiresAt']}') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      throw StateError('credential-expired');
    }

    final deviceId = await ensureLocalDeviceId();
    final keys = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    return Satt2Response.createFromChallenge(
      challenge: challenge,
      memberDeviceId: deviceId,
      credentialId: credential['credentialId']?.toString() ?? '',
      memberKeyPair: keys,
      issuedAtMs: DateTime.now().millisecondsSinceEpoch,
      memberLat: memberLat,
      memberLng: memberLng,
      memberAccuracy: memberAccuracy,
    );
  }

  Future<SecureScanValidationResult> validateAndStoreResponse({
    required String responseQr,
    required Satt2Challenge expectedChallenge,
    required AttendanceOfflinePackage package,
    required TrustedOfflineClock clock,
    double? scanLatitude,
    double? scanLongitude,
    double? scanAccuracyMeters,
  }) async {
    final validator = SecureQrValidator();
    final usedChallenges = await _store.usedChallengeIds();
    final usedNonces = await _store.usedResponseNonces();
    final members = await _store.memberIdsRegisteredForEvent(package.eventId);
    final scannerKeys = await _keyStore.getOrCreateScannerKeyPair(
      package.scannerId,
    );

    final result = await validator.validateResponse(
      rawQr: responseQr,
      expectedChallenge: expectedChallenge,
      package: package,
      nowTrustedMs: clock.nowTrustedMs(),
      usedChallengeIds: usedChallenges,
      usedResponseNonces: usedNonces,
      existingMemberIdsForEvent: members,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      scanAccuracyMeters: scanAccuracyMeters,
      signReceipt: (fields) async {
        return _crypto.signReceipt(fields: fields, keyPair: scannerKeys);
      },
    );

    if (!result.rejected && result.receipt != null) {
      await _store.saveReceipt(result.receipt!);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> syncPendingBatch({
    required String scannerId,
  }) async {
    final pending = await _store.pendingReceipts();
    if (pending.isEmpty) return [];
    final batch = pending.take(50).toList();
    for (final r in batch) {
      await _store.markReceiptSynced(
        r.localReceiptId,
        status: OfflineReceiptSyncStatus.syncing,
      );
    }

    final payload = batch.map((r) {
      final map = r.toMap();
      // Include credentialId for server response verification when available.
      return map;
    }).toList();

    try {
      final result = await _post('/attendance-sync-offline-batch', {
        'scannerId': scannerId,
        'receipts': payload,
      });
      final results = (result['results'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final row in results) {
        final id = row['localReceiptId']?.toString() ?? '';
        final status = row['status']?.toString() ?? 'rejected';
        final mapped = switch (status) {
          'synced' || 'already_synced' => OfflineReceiptSyncStatus.synced,
          'review' => OfflineReceiptSyncStatus.review,
          _ => OfflineReceiptSyncStatus.rejected,
        };
        await _store.markReceiptSynced(
          id,
          status: mapped,
          rejectReason: row['code']?.toString(),
        );
      }
      return results;
    } catch (e) {
      for (final r in batch) {
        await _store.markReceiptSynced(
          r.localReceiptId,
          status: OfflineReceiptSyncStatus.pending,
          rejectReason: 'sync-failed',
        );
      }
      rethrow;
    }
  }
}
