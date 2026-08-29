import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Controlled App Check bootstrap failures (safe codes for UI / tests).
class AppCheckBootstrapException implements Exception {
  AppCheckBootstrapException(this.code);
  final String code;

  @override
  String toString() => 'AppCheckBootstrapException($code)';
}

/// Platform classification for Firebase App Check in this app.
enum AppCheckPlatformSupport {
  /// Android / iOS / Web with official providers.
  supported,

  /// Desktop Windows: Firebase App Check plugin has no official provider
  /// for Secure Attendance online calls in this stack.
  unsupportedForThisFlow,
}

/// Resolves App Check support for the current compile / runtime target.
AppCheckPlatformSupport resolveAppCheckPlatformSupport({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  final web = isWeb ?? kIsWeb;
  if (web) return AppCheckPlatformSupport.supported;
  final p = platform ?? defaultTargetPlatform;
  if (p == TargetPlatform.android || p == TargetPlatform.iOS) {
    return AppCheckPlatformSupport.supported;
  }
  if (p == TargetPlatform.windows) {
    return AppCheckPlatformSupport.unsupportedForThisFlow;
  }
  return AppCheckPlatformSupport.unsupportedForThisFlow;
}

/// Reads Web reCAPTCHA site key from `--dart-define` only (never hardcoded).
String readFirebaseAppCheckWebSiteKey({
  String fromEnvironment = const String.fromEnvironment(
    'FIREBASE_APPCHECK_WEB_SITE_KEY',
  ),
}) => fromEnvironment.trim();

/// `recaptcha_v3` (default) or `recaptcha_enterprise`.
String readFirebaseAppCheckWebProviderName({
  String fromEnvironment = const String.fromEnvironment(
    'FIREBASE_APPCHECK_WEB_PROVIDER',
    defaultValue: 'recaptcha_v3',
  ),
}) => fromEnvironment.trim().toLowerCase();

bool _isEnterpriseWebProviderName(String name) {
  final n = name.trim().toLowerCase();
  return n == 'recaptcha_enterprise' || n == 'enterprise';
}

/// Builds the official Web provider for firebase_app_check 0.3.x.
///
/// Returns [ReCaptchaV3Provider] or [ReCaptchaEnterpriseProvider].
/// Throws [AppCheckBootstrapException] with `app-check-web-not-configured`
/// when the site key is missing — never silently disables App Check.
Object buildWebAppCheckProvider({String? siteKey, String? providerName}) {
  final key = (siteKey ?? readFirebaseAppCheckWebSiteKey()).trim();
  if (key.isEmpty) {
    throw AppCheckBootstrapException('app-check-web-not-configured');
  }
  final name = providerName ?? readFirebaseAppCheckWebProviderName();
  if (_isEnterpriseWebProviderName(name)) {
    return ReCaptchaEnterpriseProvider(key);
  }
  return ReCaptchaV3Provider(key);
}

/// Test hook / injectable activator for [FirebaseAppCheck.instance.activate].
typedef AttendanceAppCheckActivator =
    Future<void> Function({
      Object? webProvider,
      required AndroidProvider androidProvider,
      required AppleProvider appleProvider,
    });

/// Activates Firebase App Check for platforms that support Secure Attendance.
///
/// Android: debug → [AndroidProvider.debug]; release → Play Integrity.
/// iOS: debug → [AppleProvider.debug]; release → App Attest.
/// Web: requires `FIREBASE_APPCHECK_WEB_SITE_KEY` dart-define.
/// Windows: no activation (unsupported for this online flow).
Future<void> activateAttendanceAppCheck({
  AttendanceAppCheckActivator? activate,
  bool? isWeb,
  TargetPlatform? platform,
  bool? debugMode,
  String? webSiteKey,
  String? webProviderName,
}) async {
  final web = isWeb ?? kIsWeb;
  final p = platform ?? defaultTargetPlatform;
  final debug = debugMode ?? kDebugMode;

  final support = resolveAppCheckPlatformSupport(isWeb: web, platform: p);
  if (support == AppCheckPlatformSupport.unsupportedForThisFlow) {
    if (kDebugMode) {
      debugPrint(
        'ℹ️ App Check: plataforma sin proveedor oficial para '
        'Secure Attendance online (p.ej. Windows). '
        'Los endpoints HTTP seguirán exigiendo App Check; '
        'usar Android/iOS/Web para flujos online.',
      );
    }
    return;
  }

  if (web) {
    final key = (webSiteKey ?? readFirebaseAppCheckWebSiteKey()).trim();
    if (key.isEmpty) {
      throw AppCheckBootstrapException('app-check-web-not-configured');
    }
    final name = webProviderName ?? readFirebaseAppCheckWebProviderName();
    final useEnterprise = _isEnterpriseWebProviderName(name);
    if (activate != null) {
      await activate(
        webProvider: useEnterprise
            ? ReCaptchaEnterpriseProvider(key)
            : ReCaptchaV3Provider(key),
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      return;
    }
    if (useEnterprise) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(key),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(key),
      );
    }
    return;
  }

  final mobile = p == TargetPlatform.android || p == TargetPlatform.iOS;
  if (!mobile) return;

  final androidProvider = debug
      ? AndroidProvider.debug
      : AndroidProvider.playIntegrity;
  final appleProvider = debug ? AppleProvider.debug : AppleProvider.appAttest;

  if (activate != null) {
    await activate(
      androidProvider: androidProvider,
      appleProvider: appleProvider,
    );
    return;
  }
  await FirebaseAppCheck.instance.activate(
    androidProvider: androidProvider,
    appleProvider: appleProvider,
  );
}
