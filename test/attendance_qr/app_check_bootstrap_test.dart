import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/security/app_check_bootstrap.dart';

void main() {
  group('App Check bootstrap', () {
    test('Windows → unsupportedForThisFlow', () {
      expect(
        resolveAppCheckPlatformSupport(
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        AppCheckPlatformSupport.unsupportedForThisFlow,
      );
    });

    test('Android / iOS / Web → supported', () {
      expect(
        resolveAppCheckPlatformSupport(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        AppCheckPlatformSupport.supported,
      );
      expect(
        resolveAppCheckPlatformSupport(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        AppCheckPlatformSupport.supported,
      );
      expect(
        resolveAppCheckPlatformSupport(isWeb: true),
        AppCheckPlatformSupport.supported,
      );
    });

    test('Web without site key → app-check-web-not-configured', () {
      expect(
        () => buildWebAppCheckProvider(siteKey: ''),
        throwsA(
          isA<AppCheckBootstrapException>().having(
            (e) => e.code,
            'code',
            'app-check-web-not-configured',
          ),
        ),
      );
    });

    test('Web with site key builds ReCaptchaV3Provider by default', () {
      final provider = buildWebAppCheckProvider(
        siteKey: 'test-site-key-not-production',
      );
      expect(provider, isA<ReCaptchaV3Provider>());
      expect(
        (provider as ReCaptchaV3Provider).siteKey,
        'test-site-key-not-production',
      );
    });

    test('Web enterprise provider name builds ReCaptchaEnterpriseProvider', () {
      final provider = buildWebAppCheckProvider(
        siteKey: 'test-site-key-not-production',
        providerName: 'recaptcha_enterprise',
      );
      expect(provider, isA<ReCaptchaEnterpriseProvider>());
    });

    test('activateAttendanceAppCheck web without key fails safely', () async {
      await expectLater(
        () => activateAttendanceAppCheck(
          isWeb: true,
          webSiteKey: '',
          activate:
              ({
                webProvider,
                required androidProvider,
                required appleProvider,
              }) async {},
        ),
        throwsA(
          isA<AppCheckBootstrapException>().having(
            (e) => e.code,
            'code',
            'app-check-web-not-configured',
          ),
        ),
      );
    });

    test(
      'activateAttendanceAppCheck Android release uses Play Integrity',
      () async {
        AndroidProvider? seenAndroid;
        AppleProvider? seenApple;
        await activateAttendanceAppCheck(
          isWeb: false,
          platform: TargetPlatform.android,
          debugMode: false,
          activate:
              ({
                webProvider,
                required androidProvider,
                required appleProvider,
              }) async {
                seenAndroid = androidProvider;
                seenApple = appleProvider;
              },
        );
        expect(seenAndroid, AndroidProvider.playIntegrity);
        expect(seenApple, AppleProvider.appAttest);
      },
    );

    test(
      'activateAttendanceAppCheck Android debug uses debug provider',
      () async {
        AndroidProvider? seenAndroid;
        await activateAttendanceAppCheck(
          isWeb: false,
          platform: TargetPlatform.android,
          debugMode: true,
          activate:
              ({
                webProvider,
                required androidProvider,
                required appleProvider,
              }) async {
                seenAndroid = androidProvider;
              },
        );
        expect(seenAndroid, AndroidProvider.debug);
      },
    );

    test(
      'Windows activate is no-op (does not weaken other platforms)',
      () async {
        var called = false;
        await activateAttendanceAppCheck(
          isWeb: false,
          platform: TargetPlatform.windows,
          activate:
              ({
                webProvider,
                required androidProvider,
                required appleProvider,
              }) async {
                called = true;
              },
        );
        expect(called, isFalse);
      },
    );
  });
}
