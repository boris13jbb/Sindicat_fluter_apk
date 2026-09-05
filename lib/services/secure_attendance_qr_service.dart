import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/security/attendance_qr/geofence_validator.dart';
import '../core/security/attendance_qr/server_signed_artifact_verifier.dart';
import '../core/security/attendance_qr/secure_key_store.dart';
import '../core/security/attendance_qr/secure_qr_crypto.dart';
import '../core/security/attendance_qr/secure_qr_models.dart';
import '../core/security/attendance_qr/secure_qr_protocol.dart';
import '../core/security/attendance_qr/secure_qr_validator.dart';
import '../core/security/attendance_qr/trusted_server_keyring.dart';
import '../core/security/attendance_qr/trusted_offline_clock.dart';
import 'offline_attendance_store.dart';

/// Controlled API / enrollment failures (safe for UI — no HTML dumps).
class SecureAttendanceApiException implements Exception {
  SecureAttendanceApiException(
    this.code, {
    this.statusCode,
    this.contentType,
    this.endpoint,
  });

  final String code;
  final int? statusCode;
  final String? contentType;
  final String? endpoint;

  @override
  String toString() => 'SecureAttendanceApiException($code)';
}

/// Client façade for Secure Attendance QR V2 (enrollment, credential, package,
/// SATT2M / SATT2C-R, offline validate, sync).
class SecureAttendanceQrService {
  SecureAttendanceQrService({
    FirebaseAuth? auth,
    SecureAttendanceOfflineStore? store,
    SecureKeyStore? keyStore,
    SecureQrCrypto? crypto,
    http.Client? httpClient,
    String? apiBaseUrl,
    Future<String?> Function()? appCheckTokenProvider,
    bool? requireAppCheckHeader,
    TrustedServerPublicKeyring? trustedServerKeyring,
    String trustedServerKeysConfiguration = const String.fromEnvironment(
      'ATTENDANCE_QR_TRUSTED_SERVER_KEYS',
    ),
  }) : _auth = auth ?? FirebaseAuth.instance,
       _store = store ?? SecureAttendanceOfflineStore(),
       _keyStore = keyStore ?? SecureKeyStore(),
       _crypto = crypto ?? SecureQrCrypto(),
       _http = httpClient ?? http.Client(),
       _apiBase = apiBaseUrl ?? resolveApiBaseUrl(),
       _appCheckTokenProvider =
           appCheckTokenProvider ?? _defaultAppCheckTokenProvider,
       _requireAppCheckHeader =
           requireAppCheckHeader ?? !_talkingToFunctionsEmulator(),
       _trustedServerKeyring = trustedServerKeyring,
       _trustedServerKeysConfiguration = trustedServerKeysConfiguration;

  final FirebaseAuth _auth;
  final SecureAttendanceOfflineStore _store;
  final SecureKeyStore _keyStore;
  final SecureQrCrypto _crypto;
  final http.Client _http;
  final String _apiBase;
  final Future<String?> Function() _appCheckTokenProvider;
  final bool _requireAppCheckHeader;
  TrustedServerPublicKeyring? _trustedServerKeyring;
  final String _trustedServerKeysConfiguration;
  ServerSignedArtifactVerifier? _serverArtifactVerifier;
  final _uuid = const Uuid();

  /// True when compile-time dart-define targets Functions emulator.
  static bool _talkingToFunctionsEmulator() {
    const useEmu = bool.fromEnvironment('ATTENDANCE_QR_USE_EMULATOR');
    return useEmu;
  }

  static Future<String?> _defaultAppCheckTokenProvider() async {
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Production Hosting rewrite base (Functions behind `/api/*`).
  static const String kProductionApiBase =
      'https://sistema-integrado-sindicato.web.app/api';

  /// Resolves API base for production / emulator / compile-time override.
  ///
  /// Prefer `--dart-define=ATTENDANCE_QR_API_BASE=...` for emulator/CI.
  /// Never embeds personal LAN IPs in versioned code.
  static String resolveApiBaseUrl() {
    const fromDefine = String.fromEnvironment('ATTENDANCE_QR_API_BASE');
    if (fromDefine.trim().isNotEmpty) {
      return fromDefine.trim().replaceAll(RegExp(r'/+$'), '');
    }
    // Functions emulator default when explicitly requested.
    const useEmu = bool.fromEnvironment('ATTENDANCE_QR_USE_EMULATOR');
    if (useEmu) {
      const host = String.fromEnvironment(
        'ATTENDANCE_QR_FUNCTIONS_HOST',
        defaultValue: '127.0.0.1',
      );
      const port = String.fromEnvironment(
        'ATTENDANCE_QR_FUNCTIONS_PORT',
        defaultValue: '5001',
      );
      const project = String.fromEnvironment(
        'ATTENDANCE_QR_PROJECT_ID',
        defaultValue: 'demo-sindicat-attendance-qr-v2',
      );
      return 'http://$host:$port/$project/us-central1';
    }
    return kProductionApiBase;
  }

  String get apiBaseUrl => _apiBase;

  SecureAttendanceAssurance get assurance => _keyStore.detectAssurance();

  ServerSignedArtifactVerifier _requireServerArtifactVerifier() {
    try {
      final keyring = _trustedServerKeyring ??=
          TrustedServerPublicKeyring.parse(_trustedServerKeysConfiguration);
      return _serverArtifactVerifier ??= ServerSignedArtifactVerifier(
        keyring: keyring,
        crypto: _crypto,
      );
    } on AttendanceServerTrustException catch (error) {
      throw SecureAttendanceApiException(error.code);
    }
  }

  /// Test-only: exercises HTTP JSON/content-type handling of [_post].
  @visibleForTesting
  Future<Map<String, dynamic>> debugPostForTests(
    String path,
    Map<String, dynamic> body,
  ) => _post(path, body);

  Future<String> _idToken() async {
    final user = _auth.currentUser;
    if (user == null) throw SecureAttendanceApiException('not-authenticated');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw SecureAttendanceApiException('missing-id-token');
    }
    return token;
  }

  bool _isJsonContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) return false;
    final lower = contentType.toLowerCase();
    return lower.contains('application/json') ||
        lower.contains('+json') ||
        lower.contains('text/json');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _idToken();
    final endpoint = '$_apiBase$path';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    if (_requireAppCheckHeader) {
      String? appCheckToken;
      try {
        appCheckToken = await _appCheckTokenProvider();
      } catch (_) {
        throw SecureAttendanceApiException(
          'app-check-unavailable',
          endpoint: endpoint,
        );
      }
      final trimmed = appCheckToken?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw SecureAttendanceApiException(
          'app-check-unavailable',
          endpoint: endpoint,
        );
      }
      headers['X-Firebase-AppCheck'] = trimmed;
    }

    late final http.Response response;
    try {
      response = await _http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );
    } catch (_) {
      throw SecureAttendanceApiException(
        'backend-unavailable',
        endpoint: endpoint,
      );
    }

    final contentType = response.headers['content-type'];
    if (!_isJsonContentType(contentType)) {
      if (kDebugMode) {
        debugPrint(
          '[SATT2] non-JSON response status=${response.statusCode} '
          'content-type=$contentType endpoint=$endpoint',
        );
      }
      throw SecureAttendanceApiException(
        'backend-unavailable',
        statusCode: response.statusCode,
        contentType: contentType,
        endpoint: endpoint,
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    } on FormatException {
      throw SecureAttendanceApiException(
        'backend-unavailable',
        statusCode: response.statusCode,
        contentType: contentType,
        endpoint: endpoint,
      );
    }

    if (decoded == null) {
      throw SecureAttendanceApiException(
        'invalid-response',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    }

    if (response.statusCode == 401) {
      throw SecureAttendanceApiException(
        decoded['code']?.toString() ?? 'unauthorized',
        statusCode: 401,
        endpoint: endpoint,
      );
    }
    if (response.statusCode == 403) {
      throw SecureAttendanceApiException(
        decoded['code']?.toString() ?? 'forbidden',
        statusCode: 403,
        endpoint: endpoint,
      );
    }
    if (response.statusCode >= 500) {
      throw SecureAttendanceApiException(
        decoded['code']?.toString() ?? 'backend-error',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    }
    if (response.statusCode >= 400 || decoded['ok'] != true) {
      throw SecureAttendanceApiException(
        decoded['code']?.toString() ?? 'http-${response.statusCode}',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    }
    return decoded;
  }

  /// User-facing message for enrollment / API failures (no stack / HTML).
  static String userFacingActivationError(Object error) {
    if (error is SecureAttendanceApiException) {
      switch (error.code) {
        case 'not-authenticated':
        case 'missing-id-token':
        case 'unauthorized':
          return 'Debes iniciar sesión para activar tu código de asistencia.';
        case 'forbidden':
        case 'user-inactive':
        case 'missing-memberId':
        case 'member-missing':
        case 'member-inactive':
          return 'No tienes permiso para activar el código de asistencia.';
        case 'app-check-unavailable':
        case 'missing-app-check':
        case 'invalid-app-check':
          return 'No se pudo verificar la seguridad de este dispositivo. '
              'Inténtalo nuevamente.';
        case 'attendance-server-trust-not-configured':
        case 'unknown-server-key-version':
        case 'invalid-server-credential-signature':
          return 'No se pudo validar la credencial segura de asistencia. '
              'Conéctate para activarla nuevamente.';
        case 'invalid-server-package-signature':
          return 'El paquete seguro de asistencia no es válido. '
              'Conéctate para descargarlo nuevamente.';
        case 'offline-not-activated':
          return 'Este dispositivo todavía no ha sido activado para asistencia. '
              'Conéctate a Internet una vez para activar tu QR seguro.';
        case 'backend-unavailable':
        case 'backend-error':
        case 'invalid-response':
          return 'No se pudo activar el QR seguro. '
              'El servicio de asistencia todavía no está disponible. '
              'Inténtalo nuevamente cuando tengas conexión.';
        default:
          return 'No se pudo activar el QR seguro. '
              'El servicio de asistencia todavía no está disponible. '
              'Inténtalo nuevamente cuando tengas conexión.';
      }
    }
    final text = error.toString();
    if (text.contains('FormatException') ||
        text.contains('<!DOCTYPE') ||
        text.contains('Unexpected character')) {
      return 'No se pudo activar el QR seguro. '
          'El servicio de asistencia todavía no está disponible. '
          'Inténtalo nuevamente cuando tengas conexión.';
    }
    return 'No se pudo activar el QR seguro. '
        'Inténtalo nuevamente cuando tengas conexión.';
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

  /// True when credential expires within [withinMs] (default 24h).
  bool _isCredentialNearExpiry(
    Map<String, dynamic>? credential, {
    int withinMs = 24 * 60 * 60 * 1000,
    int? nowMs,
  }) {
    if (credential == null) return true;
    final expiresAt = int.tryParse('${credential['expiresAt']}') ?? 0;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return expiresAt - now <= withinMs;
  }

  /// Loads a credential only after verifying server signature, pinned key,
  /// local device binding, structure, and expiration.
  Future<Map<String, dynamic>?> loadVerifiedStoredCredential({
    int? nowMs,
  }) async {
    final verifier = _requireServerArtifactVerifier();
    final credential = await _store.loadActiveCredential();
    if (credential == null) return null;

    final user = _auth.currentUser;
    if (user == null) {
      throw SecureAttendanceApiException('not-authenticated');
    }
    final meta = await _store.loadDeviceMeta();
    final deviceId = meta?['deviceId']?.toString() ?? '';
    final enrolledUid = meta?['enrolledUid']?.toString() ?? '';
    final memberId = meta?['memberId']?.toString() ?? '';
    if (deviceId.isEmpty || enrolledUid != user.uid || memberId.isEmpty) {
      throw SecureAttendanceApiException('invalid-server-credential-signature');
    }
    final keyPair = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    final publicKey = await _crypto.publicKeyBase64Url(keyPair);
    try {
      await verifier.verifyCredential(
        credential,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
        expectedUid: user.uid,
        expectedMemberId: memberId,
        expectedMemberDeviceId: deviceId,
        expectedMemberPublicKey: publicKey,
      );
    } on AttendanceServerTrustException catch (error) {
      throw SecureAttendanceApiException(error.code);
    }
    return credential;
  }

  /// Ensures a usable offline credential: reuse, renew, or enroll automatically.
  ///
  /// Throws [SecureAttendanceApiException] with `offline-not-activated` when
  /// there is no credential and the network/backend is unavailable.
  Future<Map<String, dynamic>> ensureCredentialReady({
    bool forceRenew = false,
  }) async {
    _requireServerArtifactVerifier();
    Map<String, dynamic>? existing;
    try {
      existing = await loadVerifiedStoredCredential();
    } on SecureAttendanceApiException catch (error) {
      if (error.code != 'invalid-server-credential-signature') rethrow;
    }
    final nearExpiry = _isCredentialNearExpiry(existing);

    if (existing != null && !forceRenew && !nearExpiry) {
      return existing;
    }

    try {
      await enrollMemberDevice();
      return await prepareOfflineCredential(locationPermission: false);
    } catch (e) {
      if (existing != null && !forceRenew) {
        // Existing credential has already passed pinned signature validation.
        return existing;
      }
      if (e is SecureAttendanceApiException) rethrow;
      throw SecureAttendanceApiException('offline-not-activated');
    }
  }

  /// Enrolls device public key with backend and stores local meta.
  Future<void> enrollMemberDevice() async {
    _requireServerArtifactVerifier();
    final deviceId = await ensureLocalDeviceId();
    final pair = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    final publicKey = await _crypto.publicKeyBase64Url(pair);
    final result = await _post('/attendance-enroll-member-device', {
      'deviceId': deviceId,
      'publicKey': publicKey,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
    final enrolledDeviceId = result['deviceId'];
    final memberId = result['memberId'];
    final status = result['status'];
    final user = _auth.currentUser;
    if (user == null) {
      throw SecureAttendanceApiException('not-authenticated');
    }
    if (enrolledDeviceId is! String ||
        enrolledDeviceId != deviceId ||
        memberId is! String ||
        memberId.isEmpty ||
        memberId.trim() != memberId ||
        status != 'active') {
      throw SecureAttendanceApiException('invalid-response');
    }
    final meta = await _store.loadDeviceMeta() ?? <String, dynamic>{};
    await _store.saveDeviceMeta({
      ...meta,
      'deviceId': deviceId,
      'enrolledUid': user.uid,
      'memberId': memberId,
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
    final verifier = _requireServerArtifactVerifier();
    final deviceId = await ensureLocalDeviceId();
    final keyPair = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    final memberPublicKey = await _crypto.publicKeyBase64Url(keyPair);
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
    final rawCredential = result['credential'];
    if (rawCredential is! Map) {
      throw SecureAttendanceApiException('invalid-response');
    }
    final credential = Map<String, dynamic>.from(rawCredential);
    final user = _auth.currentUser;
    if (user == null) {
      throw SecureAttendanceApiException('not-authenticated');
    }
    final meta = await _store.loadDeviceMeta();
    final enrolledUid = meta?['enrolledUid']?.toString() ?? '';
    final memberId = meta?['memberId']?.toString() ?? '';
    if (enrolledUid != user.uid || memberId.isEmpty) {
      throw SecureAttendanceApiException('invalid-server-credential-signature');
    }
    try {
      await verifier.verifyCredential(
        credential,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        expectedUid: user.uid,
        expectedMemberId: memberId,
        expectedMemberDeviceId: deviceId,
        expectedMemberPublicKey: memberPublicKey,
      );
    } on AttendanceServerTrustException catch (error) {
      throw SecureAttendanceApiException(error.code);
    }
    await _store.saveCredential(credential);
    return credential;
  }

  Future<void> cacheRecentEvents(List<Map<String, dynamic>> events) =>
      _store.saveRecentEvents(events);

  Future<List<Map<String, dynamic>>> loadCachedEvents() =>
      _store.loadRecentEvents();

  /// Member: list only sanitized attendance event metadata usable for QR UX.
  Future<List<Map<String, dynamic>>> listMemberQrEvents() async {
    final result = await _post('/attendance-list-member-qr-events', const {});
    final rawEvents = result['events'];
    if (rawEvents is! List) {
      throw SecureAttendanceApiException('invalid-response');
    }
    return rawEvents
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList(growable: false);
  }

  /// Operator: download signed offline package for an event + scanner.
  Future<Map<String, dynamic>> prepareOfflineEvent({
    required String eventId,
    required String scannerId,
  }) async {
    final verifier = _requireServerArtifactVerifier();
    final scannerKeys = await _keyStore.getOrCreateScannerKeyPair(scannerId);
    final scannerPublicKey = await _crypto.publicKeyBase64Url(scannerKeys);
    final result = await _post('/attendance-prepare-offline-event', {
      'eventId': eventId,
      'scannerId': scannerId,
    });
    final rawPackage = result['package'];
    if (rawPackage is! Map) {
      throw SecureAttendanceApiException('invalid-response');
    }
    final package = Map<String, dynamic>.from(rawPackage);
    try {
      await verifier.verifyPackage(
        package,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        expectedEventId: eventId,
        expectedScannerId: scannerId,
        expectedScannerPublicKey: scannerPublicKey,
      );
    } on AttendanceServerTrustException catch (error) {
      throw SecureAttendanceApiException(error.code);
    }
    await _store.savePackage(package);
    return package;
  }

  /// Returns the active package only after validating its pinned server key,
  /// signature, participant hash, structure, scope, and expiration.
  Future<AttendanceOfflinePackage?> loadVerifiedStoredPackage({
    required String expectedEventId,
    required String expectedScannerId,
    int? nowMs,
  }) async {
    final verifier = _requireServerArtifactVerifier();
    final raw = await _store.loadActivePackage();
    if (raw == null) return null;
    final scannerKeys = await _keyStore.getOrCreateScannerKeyPair(
      expectedScannerId,
    );
    final scannerPublicKey = await _crypto.publicKeyBase64Url(scannerKeys);
    try {
      await verifier.verifyPackage(
        raw,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
        expectedEventId: expectedEventId,
        expectedScannerId: expectedScannerId,
        expectedScannerPublicKey: scannerPublicKey,
      );
    } on AttendanceServerTrustException catch (error) {
      throw SecureAttendanceApiException(error.code);
    }
    final parsed = _packageFromVerifiedMap(raw);
    if (parsed == null) {
      throw SecureAttendanceApiException('invalid-server-package-signature');
    }
    return parsed;
  }

  AttendanceOfflinePackage? _packageFromVerifiedMap(Map<String, dynamic> raw) {
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
        keyVersion: raw['keyVersion']?.toString() ?? '',
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

  /// Everyday mode: build rotating SATT2M for [eventId] using local credential.
  Future<Satt2MemberQr> buildMemberDynamicQr({
    required String eventId,
    int? issuedAtMs,
  }) async {
    if (eventId.trim().isEmpty) {
      throw StateError('missing-event');
    }
    final credential = await loadVerifiedStoredCredential();
    if (credential == null) {
      throw StateError('missing-credential');
    }
    final deviceId = await ensureLocalDeviceId();
    final keys = await _keyStore.getOrCreateMemberKeyPair(deviceId);
    return Satt2MemberQr.create(
      eventId: eventId.trim(),
      memberDeviceId: deviceId,
      credentialId: credential['credentialId']?.toString() ?? '',
      memberKeyPair: keys,
      issuedAtMs: issuedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Member: scan SATT2C and produce SATT2R QR string (high-security mode).
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

    final credential = await loadVerifiedStoredCredential();
    if (credential == null) throw StateError('missing-credential');

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
    final scannerKeys = await _keyStore.getOrCreateScannerKeyPair(
      package.scannerId,
    );

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
      signReceipt: (fields) async {
        return _crypto.signReceipt(fields: fields, keyPair: scannerKeys);
      },
    );

    if (!result.rejected && result.receipt != null) {
      await _store.saveReceipt(result.receipt!);
    }
    return result;
  }

  /// Scanner entry: accepts SATT2M (default) or SATT2R (high-security).
  Future<SecureScanValidationResult> validateAndStoreScannedQr({
    required String rawQr,
    required AttendanceOfflinePackage package,
    required TrustedOfflineClock clock,
    Satt2Challenge? expectedChallenge,
    double? scanLatitude,
    double? scanLongitude,
    double? scanAccuracyMeters,
  }) async {
    final trimmed = rawQr.trim();
    if (trimmed.startsWith(kSatt2MemberType)) {
      return validateAndStoreMemberQr(
        memberQr: trimmed,
        package: package,
        clock: clock,
        scanLatitude: scanLatitude,
        scanLongitude: scanLongitude,
        scanAccuracyMeters: scanAccuracyMeters,
      );
    }
    if (trimmed.startsWith(kSatt2ResponseType)) {
      if (expectedChallenge == null) {
        return const SecureScanValidationResult.reject(
          SecureQrRejectReason.invalidWireFormat,
        );
      }
      return validateAndStoreResponse(
        responseQr: trimmed,
        expectedChallenge: expectedChallenge,
        package: package,
        clock: clock,
        scanLatitude: scanLatitude,
        scanLongitude: scanLongitude,
        scanAccuracyMeters: scanAccuracyMeters,
      );
    }
    if (Satt2WireCodec.isLegacyWorkerCodeQr(trimmed)) {
      return const SecureScanValidationResult.reject(
        SecureQrRejectReason.legacyQr,
      );
    }
    return const SecureScanValidationResult.reject(
      SecureQrRejectReason.invalidWireFormat,
    );
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

    final payload = batch.map((r) => r.toMap()).toList();

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
