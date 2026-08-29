/// Secure Attendance QR V2 — protocol constants and canonical serialization.
///
/// CRITICAL: Dart and Node MUST produce identical UTF-8 bytes for the same
/// logical fields. Golden vectors live in `test/attendance_qr/` and
/// `functions/attendance-qr.test.js`.
library;

/// Protocol version embedded in every SATT2 payload.
const int kSatt2ProtocolVersion = 2;

/// Challenge QR type tag.
const String kSatt2ChallengeType = 'SATT2C';

/// Response QR type tag.
const String kSatt2ResponseType = 'SATT2R';

/// Challenge rotation interval (seconds).
const int kChallengeRotationSeconds = 15;

/// Maximum response validity (seconds).
const int kResponseMaxValiditySeconds = 20;

/// Default offline credential lifetime (days).
const int kCredentialMaxDays = 7;

/// MetodoRegistro value written only by Cloud Functions / Admin SDK.
const String kMetodoSecureQrV2 = 'SECURE_QR_V2';

/// Manual exceptional registration (audited, not secure QR).
const String kMetodoManualOverride = 'MANUAL_OVERRIDE';

/// Device assurance levels for private-key storage.
enum SecureAttendanceAssurance {
  /// Hardware-backed / OS secure storage available.
  highAssurance,

  /// Soft storage only (e.g. limited Web).
  limitedAssurance,

  /// Offline signing not permitted; online-only flows.
  onlineOnly,
}

/// Builds a deterministic UTF-8 string for signing/verification.
///
/// Rules:
/// - Keys appear in [orderedKeys] order only.
/// - Missing keys are omitted (must not appear).
/// - Values are trimmed strings; empty values are omitted.
/// - Encoding: `key=value` lines joined by `\n` (no trailing newline).
/// - No JSON, no map iteration order dependency.
String canonicalKeyValuePayload({
  required List<String> orderedKeys,
  required Map<String, String> fields,
}) {
  final lines = <String>[];
  for (final key in orderedKeys) {
    final raw = fields[key];
    if (raw == null) continue;
    final value = raw.trim();
    if (value.isEmpty) continue;
    if (key.contains('=') || key.contains('\n') || value.contains('\n')) {
      throw ArgumentError('Invalid key/value for canonical payload: $key');
    }
    lines.add('$key=$value');
  }
  return lines.join('\n');
}

/// Ordered keys for SATT2C challenge signing.
const List<String> kChallengeCanonicalKeys = [
  'v',
  'type',
  'eventId',
  'scannerId',
  'challengeId',
  'challengeNonce',
  'issuedAtTrusted',
  'expiresAtTrusted',
  'protocolVersion',
];

/// Ordered keys for SATT2R response signing.
const List<String> kResponseCanonicalKeys = [
  'v',
  'type',
  'eventId',
  'scannerId',
  'challengeId',
  'challengeNonce',
  'memberDeviceId',
  'credentialId',
  'responseNonce',
  'issuedAt',
  'protocolVersion',
  'memberLat',
  'memberLng',
  'memberAccuracy',
];

/// Ordered keys for offline package signing (server).
const List<String> kPackageCanonicalKeys = [
  'v',
  'type',
  'packageId',
  'eventId',
  'eventName',
  'startAt',
  'endAt',
  'issuedAtServer',
  'expiresAt',
  'serverTimeAtPreparation',
  'scannerId',
  'scannerPublicKey',
  'geofenceEnabled',
  'latitude',
  'longitude',
  'geofenceRadiusMeters',
  'participantsHash',
  'keyVersion',
];

/// Ordered keys for offline receipt signing (scanner).
const List<String> kReceiptCanonicalKeys = [
  'v',
  'type',
  'localReceiptId',
  'eventId',
  'memberId',
  'memberDeviceId',
  'scannerId',
  'challengeId',
  'challengeNonce',
  'responseNonce',
  'memberSignature',
  'packageId',
  'scannedAtTrusted',
  'scannedAtDevice',
  'scanLatitude',
  'scanLongitude',
  'scanAccuracy',
  'locationStatus',
];

/// Ordered keys for device credential signing (server).
const List<String> kCredentialCanonicalKeys = [
  'v',
  'type',
  'credentialId',
  'uid',
  'memberId',
  'memberDeviceId',
  'memberPublicKey',
  'issuedAtServer',
  'expiresAt',
  'keyVersion',
];

String canonicalChallengePayload(Map<String, String> fields) =>
    canonicalKeyValuePayload(
      orderedKeys: kChallengeCanonicalKeys,
      fields: fields,
    );

String canonicalResponsePayload(Map<String, String> fields) =>
    canonicalKeyValuePayload(
      orderedKeys: kResponseCanonicalKeys,
      fields: fields,
    );

String canonicalPackagePayload(Map<String, String> fields) =>
    canonicalKeyValuePayload(
      orderedKeys: kPackageCanonicalKeys,
      fields: fields,
    );

String canonicalReceiptPayload(Map<String, String> fields) =>
    canonicalKeyValuePayload(
      orderedKeys: kReceiptCanonicalKeys,
      fields: fields,
    );

String canonicalCredentialPayload(Map<String, String> fields) =>
    canonicalKeyValuePayload(
      orderedKeys: kCredentialCanonicalKeys,
      fields: fields,
    );
