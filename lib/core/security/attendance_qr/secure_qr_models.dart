import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_qr_crypto.dart';
import 'secure_qr_protocol.dart';

/// Cryptographically secure nonce (Base64URL, no padding).
String generateSecureNonce([int byteLength = 24]) {
  final random = Random.secure();
  final bytes = Uint8List(byteLength);
  for (var i = 0; i < byteLength; i++) {
    bytes[i] = random.nextInt(256);
  }
  return SecureQrCrypto.bytesToBase64Url(bytes);
}

/// Compact QR wire format: `TYPE.<jsonBase64Url>` where JSON has no PII.
class Satt2WireCodec {
  static String encode(String type, Map<String, dynamic> body) {
    final json = jsonEncode(body);
    final b64 = SecureQrCrypto.bytesToBase64Url(utf8.encode(json));
    return '$type.$b64';
  }

  static Map<String, dynamic>? decode(String raw) {
    final trimmed = raw.trim();
    final dot = trimmed.indexOf('.');
    if (dot <= 0 || dot >= trimmed.length - 1) return null;
    final type = trimmed.substring(0, dot);
    if (type != kSatt2ChallengeType && type != kSatt2ResponseType) {
      return null;
    }
    try {
      final bytes = SecureQrCrypto.base64UrlToBytes(trimmed.substring(dot + 1));
      final map = jsonDecode(utf8.decode(bytes));
      if (map is! Map) return null;
      final out = Map<String, dynamic>.from(map);
      out['_wireType'] = type;
      return out;
    } catch (_) {
      return null;
    }
  }

  static bool isLegacyWorkerCodeQr(String raw) {
    final t = raw.trim();
    if (t.startsWith('{')) {
      try {
        final map = jsonDecode(t);
        if (map is Map && map.containsKey('identificador')) return true;
      } catch (_) {}
    }
    // Plain workerCode / CSV-like legacy
    if (!t.contains('.') && !t.startsWith('SATT2')) return true;
    return false;
  }
}

/// Challenge (SATT2C) produced by an authorized scanner.
class Satt2Challenge {
  const Satt2Challenge({
    required this.eventId,
    required this.scannerId,
    required this.challengeId,
    required this.challengeNonce,
    required this.issuedAtTrusted,
    required this.expiresAtTrusted,
    required this.signature,
    this.protocolVersion = kSatt2ProtocolVersion,
  });

  final String eventId;
  final String scannerId;
  final String challengeId;
  final String challengeNonce;
  final int issuedAtTrusted;
  final int expiresAtTrusted;
  final String signature;
  final int protocolVersion;

  Map<String, String> toCanonicalFields() => {
    'v': '2',
    'type': kSatt2ChallengeType,
    'eventId': eventId,
    'scannerId': scannerId,
    'challengeId': challengeId,
    'challengeNonce': challengeNonce,
    'issuedAtTrusted': '$issuedAtTrusted',
    'expiresAtTrusted': '$expiresAtTrusted',
    'protocolVersion': '$protocolVersion',
  };

  Map<String, dynamic> toWireBody() => {
    'v': 2,
    'eventId': eventId,
    'scannerId': scannerId,
    'challengeId': challengeId,
    'challengeNonce': challengeNonce,
    'issuedAtTrusted': issuedAtTrusted,
    'expiresAtTrusted': expiresAtTrusted,
    'protocolVersion': protocolVersion,
    'sig': signature,
  };

  String toQrString() =>
      Satt2WireCodec.encode(kSatt2ChallengeType, toWireBody());

  static Satt2Challenge? tryParse(String raw) {
    final map = Satt2WireCodec.decode(raw);
    if (map == null || map['_wireType'] != kSatt2ChallengeType) return null;
    try {
      return Satt2Challenge(
        eventId: map['eventId']?.toString() ?? '',
        scannerId: map['scannerId']?.toString() ?? '',
        challengeId: map['challengeId']?.toString() ?? '',
        challengeNonce: map['challengeNonce']?.toString() ?? '',
        issuedAtTrusted: (map['issuedAtTrusted'] as num?)?.toInt() ?? 0,
        expiresAtTrusted: (map['expiresAtTrusted'] as num?)?.toInt() ?? 0,
        signature: map['sig']?.toString() ?? '',
        protocolVersion: (map['protocolVersion'] as num?)?.toInt() ?? 2,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> verify(String scannerPublicKey) {
    return SecureQrCrypto().verifyChallenge(
      fields: toCanonicalFields(),
      signatureBase64Url: signature,
      publicKeyBase64Url: scannerPublicKey,
    );
  }

  static Future<Satt2Challenge> create({
    required String eventId,
    required String scannerId,
    required SimpleKeyPair scannerKeyPair,
    required int nowTrustedMs,
    int rotationSeconds = kChallengeRotationSeconds,
  }) async {
    final challengeId = generateSecureNonce(16);
    final challengeNonce = generateSecureNonce(24);
    final expires = nowTrustedMs + rotationSeconds * 1000;
    final draft = Satt2Challenge(
      eventId: eventId,
      scannerId: scannerId,
      challengeId: challengeId,
      challengeNonce: challengeNonce,
      issuedAtTrusted: nowTrustedMs,
      expiresAtTrusted: expires,
      signature: '',
    );
    final sig = await SecureQrCrypto().signChallenge(
      fields: draft.toCanonicalFields(),
      keyPair: scannerKeyPair,
    );
    return Satt2Challenge(
      eventId: eventId,
      scannerId: scannerId,
      challengeId: challengeId,
      challengeNonce: challengeNonce,
      issuedAtTrusted: nowTrustedMs,
      expiresAtTrusted: expires,
      signature: sig,
    );
  }
}

/// Response (SATT2R) produced by the member device. No PII fields.
class Satt2Response {
  const Satt2Response({
    required this.eventId,
    required this.scannerId,
    required this.challengeId,
    required this.challengeNonce,
    required this.memberDeviceId,
    required this.credentialId,
    required this.responseNonce,
    required this.issuedAt,
    required this.signature,
    this.protocolVersion = kSatt2ProtocolVersion,
    this.memberLat,
    this.memberLng,
    this.memberAccuracy,
  });

  final String eventId;
  final String scannerId;
  final String challengeId;
  final String challengeNonce;
  final String memberDeviceId;
  final String credentialId;
  final String responseNonce;
  final int issuedAt;
  final String signature;
  final int protocolVersion;
  final String? memberLat;
  final String? memberLng;
  final String? memberAccuracy;

  Map<String, String> toCanonicalFields() {
    final fields = <String, String>{
      'v': '2',
      'type': kSatt2ResponseType,
      'eventId': eventId,
      'scannerId': scannerId,
      'challengeId': challengeId,
      'challengeNonce': challengeNonce,
      'memberDeviceId': memberDeviceId,
      'credentialId': credentialId,
      'responseNonce': responseNonce,
      'issuedAt': '$issuedAt',
      'protocolVersion': '$protocolVersion',
    };
    if (memberLat != null) fields['memberLat'] = memberLat!;
    if (memberLng != null) fields['memberLng'] = memberLng!;
    if (memberAccuracy != null) fields['memberAccuracy'] = memberAccuracy!;
    return fields;
  }

  Map<String, dynamic> toWireBody() => {
    'v': 2,
    'eventId': eventId,
    'scannerId': scannerId,
    'challengeId': challengeId,
    'challengeNonce': challengeNonce,
    'memberDeviceId': memberDeviceId,
    'credentialId': credentialId,
    'responseNonce': responseNonce,
    'issuedAt': issuedAt,
    'protocolVersion': protocolVersion,
    if (memberLat != null) 'memberLat': memberLat,
    if (memberLng != null) 'memberLng': memberLng,
    if (memberAccuracy != null) 'memberAccuracy': memberAccuracy,
    'sig': signature,
  };

  String toQrString() =>
      Satt2WireCodec.encode(kSatt2ResponseType, toWireBody());

  static Satt2Response? tryParse(String raw) {
    final map = Satt2WireCodec.decode(raw);
    if (map == null || map['_wireType'] != kSatt2ResponseType) return null;
    try {
      return Satt2Response(
        eventId: map['eventId']?.toString() ?? '',
        scannerId: map['scannerId']?.toString() ?? '',
        challengeId: map['challengeId']?.toString() ?? '',
        challengeNonce: map['challengeNonce']?.toString() ?? '',
        memberDeviceId: map['memberDeviceId']?.toString() ?? '',
        credentialId: map['credentialId']?.toString() ?? '',
        responseNonce: map['responseNonce']?.toString() ?? '',
        issuedAt: (map['issuedAt'] as num?)?.toInt() ?? 0,
        signature: map['sig']?.toString() ?? '',
        protocolVersion: (map['protocolVersion'] as num?)?.toInt() ?? 2,
        memberLat: map['memberLat']?.toString(),
        memberLng: map['memberLng']?.toString(),
        memberAccuracy: map['memberAccuracy']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> verify(String memberPublicKey) {
    return SecureQrCrypto().verifyResponse(
      fields: toCanonicalFields(),
      signatureBase64Url: signature,
      publicKeyBase64Url: memberPublicKey,
    );
  }

  static Future<Satt2Response> createFromChallenge({
    required Satt2Challenge challenge,
    required String memberDeviceId,
    required String credentialId,
    required SimpleKeyPair memberKeyPair,
    required int issuedAtMs,
    String? memberLat,
    String? memberLng,
    String? memberAccuracy,
  }) async {
    final responseNonce = generateSecureNonce(24);
    final draft = Satt2Response(
      eventId: challenge.eventId,
      scannerId: challenge.scannerId,
      challengeId: challenge.challengeId,
      challengeNonce: challenge.challengeNonce,
      memberDeviceId: memberDeviceId,
      credentialId: credentialId,
      responseNonce: responseNonce,
      issuedAt: issuedAtMs,
      signature: '',
      memberLat: memberLat,
      memberLng: memberLng,
      memberAccuracy: memberAccuracy,
    );
    final sig = await SecureQrCrypto().signResponse(
      fields: draft.toCanonicalFields(),
      keyPair: memberKeyPair,
    );
    return Satt2Response(
      eventId: draft.eventId,
      scannerId: draft.scannerId,
      challengeId: draft.challengeId,
      challengeNonce: draft.challengeNonce,
      memberDeviceId: draft.memberDeviceId,
      credentialId: draft.credentialId,
      responseNonce: draft.responseNonce,
      issuedAt: draft.issuedAt,
      signature: sig,
      memberLat: memberLat,
      memberLng: memberLng,
      memberAccuracy: memberAccuracy,
    );
  }
}
