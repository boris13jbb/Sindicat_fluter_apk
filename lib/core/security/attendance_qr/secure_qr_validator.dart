import 'geofence_validator.dart';
import 'secure_qr_models.dart';
import 'secure_qr_protocol.dart';

enum SecureQrRejectReason {
  legacyQr,
  invalidWireFormat,
  invalidSignature,
  expired,
  replay,
  wrongEvent,
  wrongScanner,
  inactiveMember,
  revokedDevice,
  unknownDevice,
  geofenceOutside,
  geofenceMissing,
  geofenceLowAccuracy,
  duplicateLocal,
  packageExpired,
  packageInvalid,
  clockUntrusted,
}

class OfflineParticipantSnapshot {
  const OfflineParticipantSnapshot({
    required this.memberId,
    required this.memberDeviceId,
    required this.memberPublicKey,
    required this.credentialId,
    required this.status,
    this.displayName = '',
    this.memberNumber = '',
    this.workerCode = '',
  });

  final String memberId;
  final String memberDeviceId;
  final String memberPublicKey;
  final String credentialId;
  final String status; // active | inactive | revoked
  final String displayName;
  final String memberNumber;
  final String workerCode;

  factory OfflineParticipantSnapshot.fromMap(Map<String, dynamic> map) {
    return OfflineParticipantSnapshot(
      memberId: map['memberId']?.toString() ?? '',
      memberDeviceId: map['memberDeviceId']?.toString() ?? '',
      memberPublicKey: map['memberPublicKey']?.toString() ?? '',
      credentialId: map['credentialId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'inactive',
      displayName: map['displayName']?.toString() ?? '',
      memberNumber: map['memberNumber']?.toString() ?? '',
      workerCode: map['workerCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'memberDeviceId': memberDeviceId,
    'memberPublicKey': memberPublicKey,
    'credentialId': credentialId,
    'status': status,
    'displayName': displayName,
    'memberNumber': memberNumber,
    'workerCode': workerCode,
  };
}

class AttendanceOfflinePackage {
  const AttendanceOfflinePackage({
    required this.packageId,
    required this.eventId,
    required this.eventName,
    required this.startAt,
    required this.endAt,
    required this.issuedAtServer,
    required this.expiresAt,
    required this.serverTimeAtPreparation,
    required this.scannerId,
    required this.scannerPublicKey,
    required this.participants,
    required this.signature,
    required this.keyVersion,
    this.geofence = const GeofenceConfig(),
  });

  final String packageId;
  final String eventId;
  final String eventName;
  final int startAt;
  final int endAt;
  final int issuedAtServer;
  final int expiresAt;
  final int serverTimeAtPreparation;
  final String scannerId;
  final String scannerPublicKey;
  final List<OfflineParticipantSnapshot> participants;
  final String signature;
  final String keyVersion;
  final GeofenceConfig geofence;

  OfflineParticipantSnapshot? findByDeviceId(String deviceId) {
    for (final p in participants) {
      if (p.memberDeviceId == deviceId) return p;
    }
    return null;
  }

  Map<String, String> toCanonicalFields({required String participantsHash}) => {
    'v': '2',
    'type': 'SATT2PKG',
    'packageId': packageId,
    'eventId': eventId,
    'eventName': eventName,
    'startAt': '$startAt',
    'endAt': '$endAt',
    'issuedAtServer': '$issuedAtServer',
    'expiresAt': '$expiresAt',
    'serverTimeAtPreparation': '$serverTimeAtPreparation',
    'scannerId': scannerId,
    'scannerPublicKey': scannerPublicKey,
    'geofenceEnabled': geofence.enabled ? '1' : '0',
    if (geofence.latitude != null) 'latitude': '${geofence.latitude}',
    if (geofence.longitude != null) 'longitude': '${geofence.longitude}',
    'geofenceRadiusMeters': '${geofence.radiusMeters}',
    'participantsHash': participantsHash,
    'keyVersion': keyVersion,
  };
}

enum OfflineReceiptSyncStatus { pending, syncing, synced, rejected, review }

class OfflineAttendanceReceipt {
  const OfflineAttendanceReceipt({
    required this.localReceiptId,
    required this.eventId,
    required this.memberId,
    required this.memberDeviceId,
    required this.scannerId,
    required this.challengeId,
    required this.challengeNonce,
    required this.responseNonce,
    required this.memberSignature,
    required this.scannerSignature,
    required this.packageId,
    required this.scannedAtTrusted,
    required this.scannedAtDevice,
    required this.syncStatus,
    required this.createdAtLocal,
    this.scanLatitude,
    this.scanLongitude,
    this.scanAccuracy,
    this.locationStatus = 'unknown',
    this.rejectReason,
  });

  final String localReceiptId;
  final String eventId;
  final String memberId;
  final String memberDeviceId;
  final String scannerId;
  final String challengeId;
  final String challengeNonce;
  final String responseNonce;
  final String memberSignature;
  final String scannerSignature;
  final String packageId;
  final int scannedAtTrusted;
  final int scannedAtDevice;
  final OfflineReceiptSyncStatus syncStatus;
  final int createdAtLocal;
  final double? scanLatitude;
  final double? scanLongitude;
  final double? scanAccuracy;
  final String locationStatus;
  final String? rejectReason;

  Map<String, String> toCanonicalFields() => {
    'v': '2',
    'type': 'SATT2RCPT',
    'localReceiptId': localReceiptId,
    'eventId': eventId,
    'memberId': memberId,
    'memberDeviceId': memberDeviceId,
    'scannerId': scannerId,
    'challengeId': challengeId,
    'challengeNonce': challengeNonce,
    'responseNonce': responseNonce,
    'memberSignature': memberSignature,
    'packageId': packageId,
    'scannedAtTrusted': '$scannedAtTrusted',
    'scannedAtDevice': '$scannedAtDevice',
    if (scanLatitude != null) 'scanLatitude': '$scanLatitude',
    if (scanLongitude != null) 'scanLongitude': '$scanLongitude',
    if (scanAccuracy != null) 'scanAccuracy': '$scanAccuracy',
    'locationStatus': locationStatus,
  };

  Map<String, dynamic> toMap() => {
    'localReceiptId': localReceiptId,
    'eventId': eventId,
    'memberId': memberId,
    'memberDeviceId': memberDeviceId,
    'scannerId': scannerId,
    'challengeId': challengeId,
    'challengeNonce': challengeNonce,
    'responseNonce': responseNonce,
    'memberSignature': memberSignature,
    'scannerSignature': scannerSignature,
    'packageId': packageId,
    'scannedAtTrusted': scannedAtTrusted,
    'scannedAtDevice': scannedAtDevice,
    'syncStatus': syncStatus.name,
    'createdAtLocal': createdAtLocal,
    'scanLatitude': scanLatitude,
    'scanLongitude': scanLongitude,
    'scanAccuracy': scanAccuracy,
    'locationStatus': locationStatus,
    'rejectReason': rejectReason,
  };

  factory OfflineAttendanceReceipt.fromMap(Map<String, dynamic> map) {
    return OfflineAttendanceReceipt(
      localReceiptId: map['localReceiptId']?.toString() ?? '',
      eventId: map['eventId']?.toString() ?? '',
      memberId: map['memberId']?.toString() ?? '',
      memberDeviceId: map['memberDeviceId']?.toString() ?? '',
      scannerId: map['scannerId']?.toString() ?? '',
      challengeId: map['challengeId']?.toString() ?? '',
      challengeNonce: map['challengeNonce']?.toString() ?? '',
      responseNonce: map['responseNonce']?.toString() ?? '',
      memberSignature: map['memberSignature']?.toString() ?? '',
      scannerSignature: map['scannerSignature']?.toString() ?? '',
      packageId: map['packageId']?.toString() ?? '',
      scannedAtTrusted: (map['scannedAtTrusted'] as num?)?.toInt() ?? 0,
      scannedAtDevice: (map['scannedAtDevice'] as num?)?.toInt() ?? 0,
      syncStatus: OfflineReceiptSyncStatus.values.firstWhere(
        (e) => e.name == map['syncStatus'],
        orElse: () => OfflineReceiptSyncStatus.pending,
      ),
      createdAtLocal: (map['createdAtLocal'] as num?)?.toInt() ?? 0,
      scanLatitude: (map['scanLatitude'] as num?)?.toDouble(),
      scanLongitude: (map['scanLongitude'] as num?)?.toDouble(),
      scanAccuracy: (map['scanAccuracy'] as num?)?.toDouble(),
      locationStatus: map['locationStatus']?.toString() ?? 'unknown',
      rejectReason: map['rejectReason']?.toString(),
    );
  }
}

class SecureScanValidationResult {
  const SecureScanValidationResult.ok({
    required this.receipt,
    required this.participant,
  }) : rejected = false,
       reason = null;

  const SecureScanValidationResult.reject(this.reason)
    : rejected = true,
      receipt = null,
      participant = null;

  final bool rejected;
  final SecureQrRejectReason? reason;
  final OfflineAttendanceReceipt? receipt;
  final OfflineParticipantSnapshot? participant;
}

/// Pure offline validator for SATT2R against a prepared package + challenge.
class SecureQrValidator {
  /// [usedChallengeIds] / [usedResponseNonces] provide replay protection.
  /// [existingMemberIds] provides local duplicate detection for the event.
  Future<SecureScanValidationResult> validateResponse({
    required String rawQr,
    required Satt2Challenge expectedChallenge,
    required AttendanceOfflinePackage package,
    required int nowTrustedMs,
    required Set<String> usedChallengeIds,
    required Set<String> usedResponseNonces,
    required Set<String> existingMemberIdsForEvent,
    double? scanLatitude,
    double? scanLongitude,
    double? scanAccuracyMeters,
    required Future<String> Function(Map<String, String> receiptFields)
    signReceipt,
  }) async {
    if (Satt2WireCodec.isLegacyWorkerCodeQr(rawQr) &&
        !rawQr.trim().startsWith(kSatt2ResponseType)) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.legacyQr,
      );
    }

    final response = Satt2Response.tryParse(rawQr);
    if (response == null) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.invalidWireFormat,
      );
    }

    if (nowTrustedMs > package.expiresAt) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.packageExpired,
      );
    }

    if (response.eventId != expectedChallenge.eventId ||
        response.eventId != package.eventId) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.wrongEvent,
      );
    }

    if (response.scannerId != expectedChallenge.scannerId ||
        response.scannerId != package.scannerId) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.wrongScanner,
      );
    }

    if (response.challengeId != expectedChallenge.challengeId ||
        response.challengeNonce != expectedChallenge.challengeNonce) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.invalidSignature,
      );
    }

    if (nowTrustedMs > expectedChallenge.expiresAtTrusted) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.expired,
      );
    }

    if (usedChallengeIds.contains(response.challengeId) ||
        usedResponseNonces.contains(response.responseNonce)) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.replay,
      );
    }

    final participant = package.findByDeviceId(response.memberDeviceId);
    if (participant == null) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.unknownDevice,
      );
    }

    if (participant.status == 'revoked') {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.revokedDevice,
      );
    }

    if (participant.status != 'active' && participant.status != 'activo') {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.inactiveMember,
      );
    }

    if (participant.credentialId != response.credentialId) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.invalidSignature,
      );
    }

    final sigOk = await response.verify(participant.memberPublicKey);
    if (!sigOk) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.invalidSignature,
      );
    }

    if (existingMemberIdsForEvent.contains(participant.memberId)) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.duplicateLocal,
      );
    }

    final geo = evaluateGeofence(
      config: package.geofence,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      scanAccuracyMeters: scanAccuracyMeters,
    );

    String locationStatus = 'ok';
    if (geo.evaluation == GeofenceEvaluation.outside) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.geofenceOutside,
      );
    }
    if (geo.evaluation == GeofenceEvaluation.missingRequired) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.geofenceMissing,
      );
    }
    if (geo.evaluation == GeofenceEvaluation.lowAccuracy) {
      locationStatus = 'location_low_accuracy';
    }

    final localReceiptId =
        '${response.eventId}_${participant.memberId}_${response.responseNonce}';
    final draftFields = OfflineAttendanceReceipt(
      localReceiptId: localReceiptId,
      eventId: response.eventId,
      memberId: participant.memberId,
      memberDeviceId: response.memberDeviceId,
      scannerId: response.scannerId,
      challengeId: response.challengeId,
      challengeNonce: response.challengeNonce,
      responseNonce: response.responseNonce,
      memberSignature: response.signature,
      scannerSignature: '',
      packageId: package.packageId,
      scannedAtTrusted: nowTrustedMs,
      scannedAtDevice: DateTime.now().millisecondsSinceEpoch,
      syncStatus: OfflineReceiptSyncStatus.pending,
      createdAtLocal: DateTime.now().millisecondsSinceEpoch,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      scanAccuracy: scanAccuracyMeters,
      locationStatus: locationStatus,
    ).toCanonicalFields();

    final scannerSig = await signReceipt(draftFields);
    final receipt = OfflineAttendanceReceipt(
      localReceiptId: localReceiptId,
      eventId: response.eventId,
      memberId: participant.memberId,
      memberDeviceId: response.memberDeviceId,
      scannerId: response.scannerId,
      challengeId: response.challengeId,
      challengeNonce: response.challengeNonce,
      responseNonce: response.responseNonce,
      memberSignature: response.signature,
      scannerSignature: scannerSig,
      packageId: package.packageId,
      scannedAtTrusted: nowTrustedMs,
      scannedAtDevice: DateTime.now().millisecondsSinceEpoch,
      syncStatus: OfflineReceiptSyncStatus.pending,
      createdAtLocal: DateTime.now().millisecondsSinceEpoch,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      scanAccuracy: scanAccuracyMeters,
      locationStatus: locationStatus,
    );

    return SecureScanValidationResult.ok(
      receipt: receipt,
      participant: participant,
    );
  }
}
