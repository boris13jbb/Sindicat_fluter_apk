import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

class _FakeUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'test-id-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

void main() {
  group('SecureAttendanceQrService App Check headers', () {
    test('_post sends Authorization + X-Firebase-AppCheck', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async => 'test-app-check-token',
      );
      await service.debugPostForTests('/attendance-enroll-member-device', {
        'deviceId': 'd1',
      });
      expect(seen, isNotNull);
      expect(seen!.headers['authorization'], 'Bearer test-id-token');
      expect(seen!.headers['x-firebase-appcheck'], 'test-app-check-token');
      // Never leak tokens into body/URL.
      expect(seen!.url.query, isEmpty);
      expect(seen!.body.contains('test-app-check-token'), isFalse);
      expect(seen!.body.contains('test-id-token'), isFalse);
    });

    test('missing App Check token → app-check-unavailable', () async {
      final client = MockClient((request) async {
        fail('must not send request without App Check');
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async => null,
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected SecureAttendanceApiException');
      } on SecureAttendanceApiException catch (e) {
        expect(e.code, 'app-check-unavailable');
        final msg = SecureAttendanceQrService.userFacingActivationError(e);
        expect(msg.contains('seguridad'), isTrue);
        expect(msg.toLowerCase().contains('app check'), isFalse);
        expect(msg.toLowerCase().contains('token'), isFalse);
      }
    });

    test('App Check provider throws → app-check-unavailable', () async {
      final client = MockClient((request) async {
        fail('must not send request');
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async {
          throw StateError('provider-down');
        },
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected SecureAttendanceApiException');
      } on SecureAttendanceApiException catch (e) {
        expect(e.code, 'app-check-unavailable');
      }
    });

    test('HTML backend still → backend-unavailable', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<!DOCTYPE html><html></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async => 'tok',
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected SecureAttendanceApiException');
      } on SecureAttendanceApiException catch (e) {
        expect(e.code, 'backend-unavailable');
      }
    });

    test('401 JSON still controlled', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'code': 'invalid-auth'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: true,
        appCheckTokenProvider: () async => 'tok',
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected');
      } on SecureAttendanceApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, 'invalid-auth');
      }
    });

    test('requireAppCheckHeader false skips header (emulator path)', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://127.0.0.1:5001/demo/us-central1',
        requireAppCheckHeader: false,
        appCheckTokenProvider: () async => 'should-not-be-used',
      );
      await service.debugPostForTests('/attendance-sync-offline-batch', {});
      expect(seen!.headers.containsKey('x-firebase-appcheck'), isFalse);
      expect(seen!.headers['authorization'], startsWith('Bearer '));
    });
  });
}
