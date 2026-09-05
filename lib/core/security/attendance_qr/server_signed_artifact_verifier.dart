import 'dart:convert';

import 'secure_qr_crypto.dart';
import 'trusted_server_keyring.dart';

/// Verifies server-signed SATT2 credentials and offline event packages against
/// build-pinned public keys. A key returned beside an artifact is diagnostic
/// metadata only and can never establish trust.
class ServerSignedArtifactVerifier {
  ServerSignedArtifactVerifier({
    required TrustedServerPublicKeyring keyring,
    SecureQrCrypto? crypto,
  }) : _keyring = keyring,
       _crypto = crypto ?? SecureQrCrypto();

  static const _participantHashKeys = [
    'memberId',
    'memberDeviceId',
    'memberPublicKey',
    'credentialId',
    'status',
    'displayName',
    'memberNumber',
    'workerCode',
  ];

  final TrustedServerPublicKeyring _keyring;
  final SecureQrCrypto _crypto;

  static const int _credentialMaxValidityMs = 7 * 24 * 60 * 60 * 1000;
  static const int _packagePostEventMarginMs = 2 * 60 * 60 * 1000;
  static const int _serverClockSkewMs = 5 * 60 * 1000;
  static const int _maxTimestampMs = 253402300799999; // 9999-12-31 UTC.

  Future<void> verifyCredential(
    Map<String, dynamic> credential, {
    required int nowMs,
    String? expectedUid,
    String? expectedMemberId,
    String? expectedMemberDeviceId,
    String? expectedMemberPublicKey,
  }) async {
    const invalid = 'invalid-server-credential-signature';
    final fields = credentialCanonicalFields(credential, errorCode: invalid);
    final keyVersion = fields['keyVersion']!;
    final pinnedKey = _keyring.publicKeyFor(keyVersion);
    _verifyDiagnosticResponseKey(credential, pinnedKey, invalid);

    final memberPublicKey = fields['memberPublicKey']!;
    _validatePublicKey(memberPublicKey, invalid);
    final issuedAt = _timestamp(fields['issuedAtServer']!, invalid);
    final expiresAt = _timestamp(fields['expiresAt']!, invalid);
    _validateNow(nowMs, invalid);
    if (issuedAt > nowMs + _serverClockSkewMs ||
        expiresAt <= issuedAt ||
        expiresAt - issuedAt > _credentialMaxValidityMs ||
        nowMs >= expiresAt) {
      _fail(invalid);
    }
    if (expectedUid != null && fields['uid'] != expectedUid) {
      _fail(invalid);
    }
    if (expectedMemberId != null && fields['memberId'] != expectedMemberId) {
      _fail(invalid);
    }
    if (expectedMemberDeviceId != null &&
        fields['memberDeviceId'] != expectedMemberDeviceId) {
      _fail(invalid);
    }
    if (expectedMemberPublicKey != null &&
        memberPublicKey != expectedMemberPublicKey) {
      _fail(invalid);
    }

    final signature = _requiredCanonicalString(
      credential,
      'signature',
      invalid,
    );
    final valid = await _crypto.verifyCredential(
      fields: fields,
      signatureBase64Url: signature,
      publicKeyBase64Url: pinnedKey,
    );
    if (!valid) _fail(invalid);
  }

  Future<void> verifyPackage(
    Map<String, dynamic> package, {
    required int nowMs,
    String? expectedEventId,
    String? expectedScannerId,
    String? expectedScannerPublicKey,
  }) async {
    const invalid = 'invalid-server-package-signature';
    final fields = await packageCanonicalFields(package, errorCode: invalid);
    final keyVersion = fields['keyVersion']!;
    final pinnedKey = _keyring.publicKeyFor(keyVersion);
    _verifyDiagnosticResponseKey(package, pinnedKey, invalid);

    final startAt = _timestamp(fields['startAt']!, invalid);
    final endAt = _timestamp(fields['endAt']!, invalid);
    final issuedAt = _timestamp(fields['issuedAtServer']!, invalid);
    final expiresAt = _timestamp(fields['expiresAt']!, invalid);
    final serverTimeAtPreparation = _timestamp(
      fields['serverTimeAtPreparation']!,
      invalid,
    );
    _validateNow(nowMs, invalid);
    final maximumExpiry =
        (endAt > issuedAt ? endAt : issuedAt) + _packagePostEventMarginMs;
    if (endAt < startAt ||
        issuedAt > nowMs + _serverClockSkewMs ||
        serverTimeAtPreparation != issuedAt ||
        expiresAt <= issuedAt ||
        expiresAt > maximumExpiry ||
        nowMs >= expiresAt) {
      _fail(invalid);
    }
    if (expectedEventId != null && fields['eventId'] != expectedEventId) {
      _fail(invalid);
    }
    if (expectedScannerId != null && fields['scannerId'] != expectedScannerId) {
      _fail(invalid);
    }
    if (expectedScannerPublicKey != null &&
        fields['scannerPublicKey'] != expectedScannerPublicKey) {
      _fail(invalid);
    }

    final signature = _requiredCanonicalString(package, 'signature', invalid);
    final valid = await _crypto.verifyPackage(
      fields: fields,
      signatureBase64Url: signature,
      publicKeyBase64Url: pinnedKey,
    );
    if (!valid) _fail(invalid);
  }

  Future<Map<String, String>> packageCanonicalFields(
    Map<String, dynamic> package, {
    String errorCode = 'invalid-server-package-signature',
  }) async {
    final version = _requiredCanonicalString(package, 'v', errorCode);
    final type = _requiredCanonicalString(package, 'type', errorCode);
    if (version != '2' || type != 'SATT2PKG') _fail(errorCode);

    final scannerPublicKey = _requiredCanonicalString(
      package,
      'scannerPublicKey',
      errorCode,
    );
    _validatePublicKey(scannerPublicKey, errorCode);

    final participantsValue = package['participants'];
    if (participantsValue is! List) _fail(errorCode);
    final computedParticipantsHash = await participantsHash(
      participantsValue,
      errorCode: errorCode,
    );
    final claimedParticipantsHash = _requiredCanonicalString(
      package,
      'participantsHash',
      errorCode,
    );
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(claimedParticipantsHash) ||
        computedParticipantsHash != claimedParticipantsHash) {
      _fail(errorCode);
    }

    final geofenceValue = package['geofence'];
    if (geofenceValue is! Map) _fail(errorCode);
    final geofence = Map<String, dynamic>.from(geofenceValue);
    final enabled = geofence['enabled'];
    final requireScannerLocation = geofence['requireScannerLocation'];
    if (enabled is! bool || requireScannerLocation is! bool) _fail(errorCode);
    final latitude = _optionalFiniteNumber(geofence, 'latitude', errorCode);
    final longitude = _optionalFiniteNumber(geofence, 'longitude', errorCode);
    final radius = _requiredFiniteNumber(geofence, 'radiusMeters', errorCode);
    if ((latitude == null) != (longitude == null) ||
        (enabled && latitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180)) ||
        radius <= 0) {
      _fail(errorCode);
    }

    return {
      'v': version,
      'type': type,
      'packageId': _requiredCanonicalString(package, 'packageId', errorCode),
      'eventId': _requiredCanonicalString(package, 'eventId', errorCode),
      'eventName': _requiredCanonicalString(
        package,
        'eventName',
        errorCode,
        allowEmpty: true,
      ),
      'startAt': _requiredCanonicalInteger(package, 'startAt', errorCode),
      'endAt': _requiredCanonicalInteger(package, 'endAt', errorCode),
      'issuedAtServer': _requiredCanonicalInteger(
        package,
        'issuedAtServer',
        errorCode,
      ),
      'expiresAt': _requiredCanonicalInteger(package, 'expiresAt', errorCode),
      'serverTimeAtPreparation': _requiredCanonicalInteger(
        package,
        'serverTimeAtPreparation',
        errorCode,
      ),
      'scannerId': _requiredCanonicalString(package, 'scannerId', errorCode),
      'scannerPublicKey': scannerPublicKey,
      'geofenceEnabled': enabled ? '1' : '0',
      if (latitude != null) 'latitude': _canonicalNumber(latitude),
      if (longitude != null) 'longitude': _canonicalNumber(longitude),
      'geofenceRadiusMeters': _canonicalNumber(radius),
      'requireScannerLocation': requireScannerLocation ? '1' : '0',
      'participantsHash': claimedParticipantsHash,
      'keyVersion': _requiredKeyVersion(package, errorCode),
    };
  }

  Map<String, String> credentialCanonicalFields(
    Map<String, dynamic> credential, {
    String errorCode = 'invalid-server-credential-signature',
  }) {
    final version = _requiredCanonicalString(credential, 'v', errorCode);
    final type = _requiredCanonicalString(credential, 'type', errorCode);
    if (version != '2' || type != 'SATT2CRED') _fail(errorCode);
    return {
      'v': version,
      'type': type,
      'credentialId': _requiredCanonicalString(
        credential,
        'credentialId',
        errorCode,
      ),
      'uid': _requiredCanonicalString(credential, 'uid', errorCode),
      'memberId': _requiredCanonicalString(credential, 'memberId', errorCode),
      'memberDeviceId': _requiredCanonicalString(
        credential,
        'memberDeviceId',
        errorCode,
      ),
      'memberPublicKey': _requiredCanonicalString(
        credential,
        'memberPublicKey',
        errorCode,
      ),
      'issuedAtServer': _requiredCanonicalInteger(
        credential,
        'issuedAtServer',
        errorCode,
      ),
      'expiresAt': _requiredCanonicalInteger(
        credential,
        'expiresAt',
        errorCode,
      ),
      'keyVersion': _requiredKeyVersion(credential, errorCode),
    };
  }

  Future<String> participantsHash(
    List<dynamic> participants, {
    String errorCode = 'invalid-server-package-signature',
  }) async {
    final records = <String>[];
    final memberDeviceIds = <String>{};
    for (final participantValue in participants) {
      if (participantValue is! Map) _fail(errorCode);
      final participant = Map<String, dynamic>.from(participantValue);
      final values = <String>[];
      for (final key in _participantHashKeys) {
        final allowEmpty =
            key == 'credentialId' ||
            key == 'displayName' ||
            key == 'memberNumber' ||
            key == 'workerCode';
        final value = _requiredString(
          participant,
          key,
          errorCode,
          allowEmpty: allowEmpty,
        );
        if (key == 'memberPublicKey') {
          _validatePublicKey(value, errorCode);
        }
        if (key == 'memberDeviceId' && !memberDeviceIds.add(value)) {
          _fail(errorCode);
        }
        if (key == 'status' &&
            const {'active', 'inactive', 'revoked'}.contains(value) == false) {
          _fail(errorCode);
        }
        values.add('${utf8.encode(value).length}:$value');
      }
      records.add(values.join('|'));
    }
    records.sort();
    return _crypto.hashSha256Hex(records.join('\n'));
  }

  String _requiredKeyVersion(Map<String, dynamic> map, String errorCode) {
    final version = _requiredCanonicalString(map, 'keyVersion', errorCode);
    if (!TrustedServerPublicKeyring.isValidKeyVersion(version)) {
      _fail(errorCode);
    }
    return version;
  }

  void _verifyDiagnosticResponseKey(
    Map<String, dynamic> artifact,
    String pinnedKey,
    String errorCode,
  ) {
    if (!artifact.containsKey('serverPublicKey')) return;
    final responseKey = artifact['serverPublicKey'];
    if (responseKey is! String || responseKey != pinnedKey) {
      _fail(errorCode);
    }
    _validatePublicKey(responseKey, errorCode);
  }

  void _validatePublicKey(String value, String errorCode) {
    try {
      SecureQrCrypto.canonicalBase64UrlToBytes(
        value,
        expectedLength: SecureQrCrypto.ed25519KeyBytes,
      );
    } on FormatException {
      _fail(errorCode);
    }
  }

  String _requiredCanonicalString(
    Map<String, dynamic> map,
    String key,
    String errorCode, {
    bool allowEmpty = false,
  }) {
    final value = _requiredString(map, key, errorCode, allowEmpty: allowEmpty);
    if (value.trim() != value || value.contains('\n') || value.contains('\r')) {
      _fail(errorCode);
    }
    return value;
  }

  String _requiredString(
    Map<String, dynamic> map,
    String key,
    String errorCode, {
    bool allowEmpty = false,
  }) {
    final value = map[key];
    if (value is! String || (!allowEmpty && value.isEmpty)) _fail(errorCode);
    return value;
  }

  String _requiredCanonicalInteger(
    Map<String, dynamic> map,
    String key,
    String errorCode,
  ) {
    final value = map[key];
    if (value is int && value >= 0) return '$value';
    if (value is String && RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
      return value;
    }
    _fail(errorCode);
  }

  num _requiredFiniteNumber(
    Map<String, dynamic> map,
    String key,
    String errorCode,
  ) {
    final value = map[key];
    if (value is! num || !value.isFinite) _fail(errorCode);
    return value;
  }

  num? _optionalFiniteNumber(
    Map<String, dynamic> map,
    String key,
    String errorCode,
  ) {
    final value = map[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite) _fail(errorCode);
    return value;
  }

  String _canonicalNumber(num value) {
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  int _timestamp(String value, String errorCode) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0 || parsed > _maxTimestampMs) {
      _fail(errorCode);
    }
    return parsed;
  }

  void _validateNow(int nowMs, String errorCode) {
    if (nowMs <= 0 || nowMs > _maxTimestampMs) _fail(errorCode);
  }

  Never _fail(String code) => throw AttendanceServerTrustException(code);
}
