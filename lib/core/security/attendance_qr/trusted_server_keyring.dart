import 'secure_qr_crypto.dart';

/// Controlled failure for Secure Attendance server trust validation.
class AttendanceServerTrustException implements Exception {
  const AttendanceServerTrustException(this.code);

  final String code;

  @override
  String toString() => 'AttendanceServerTrustException($code)';
}

/// Build-pinned Ed25519 public keys accepted for server-signed SATT2 artifacts.
///
/// Configure with:
/// `--dart-define=ATTENDANCE_QR_TRUSTED_SERVER_KEYS=v1:<key>,v2:<key>`.
/// Public keys are trust anchors; response-provided keys never populate this
/// keyring.
class TrustedServerPublicKeyring {
  TrustedServerPublicKeyring._(Map<String, String> keys)
    : _keys = Map.unmodifiable(keys);

  static const String buildDefineName = 'ATTENDANCE_QR_TRUSTED_SERVER_KEYS';
  static final RegExp _versionPattern = RegExp(r'^v[1-9][0-9]*$');

  final Map<String, String> _keys;

  factory TrustedServerPublicKeyring.fromBuildEnvironment({
    String configuration = const String.fromEnvironment(
      'ATTENDANCE_QR_TRUSTED_SERVER_KEYS',
    ),
  }) {
    return TrustedServerPublicKeyring.parse(configuration);
  }

  factory TrustedServerPublicKeyring.parse(String configuration) {
    if (configuration.isEmpty || configuration.trim() != configuration) {
      throw const AttendanceServerTrustException(
        'attendance-server-trust-not-configured',
      );
    }

    final keys = <String, String>{};
    for (final entry in configuration.split(',')) {
      final separator = entry.indexOf(':');
      if (entry.isEmpty ||
          separator <= 0 ||
          separator != entry.lastIndexOf(':')) {
        throw const AttendanceServerTrustException(
          'attendance-server-trust-not-configured',
        );
      }

      final version = entry.substring(0, separator);
      final publicKey = entry.substring(separator + 1);
      if (!_versionPattern.hasMatch(version) || keys.containsKey(version)) {
        throw const AttendanceServerTrustException(
          'attendance-server-trust-not-configured',
        );
      }

      try {
        SecureQrCrypto.canonicalBase64UrlToBytes(
          publicKey,
          expectedLength: SecureQrCrypto.ed25519KeyBytes,
        );
      } on FormatException {
        throw const AttendanceServerTrustException(
          'attendance-server-trust-not-configured',
        );
      }
      keys[version] = publicKey;
    }

    if (keys.isEmpty) {
      throw const AttendanceServerTrustException(
        'attendance-server-trust-not-configured',
      );
    }
    return TrustedServerPublicKeyring._(keys);
  }

  static bool isValidKeyVersion(String version) {
    final match = _versionPattern.firstMatch(version);
    return match != null && match.start == 0 && match.end == version.length;
  }

  Map<String, String> get keys => _keys;

  String publicKeyFor(String version) {
    if (!isValidKeyVersion(version)) {
      throw const AttendanceServerTrustException('unknown-server-key-version');
    }
    final key = _keys[version];
    if (key == null) {
      throw const AttendanceServerTrustException('unknown-server-key-version');
    }
    return key;
  }
}
