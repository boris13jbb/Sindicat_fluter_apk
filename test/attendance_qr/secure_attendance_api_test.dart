import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

class _FakeUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

void main() {
  group('API error handling', () {
    test(
      '14. HTML response → backend-unavailable (no FormatException)',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            '<!DOCTYPE html><html><body>Hosting</body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        });
        final service = SecureAttendanceQrService(
          auth: _FakeAuth(),
          httpClient: client,
          apiBaseUrl: 'http://test.local/api',
        );
        try {
          await service.debugPostForTests('/attendance-enroll-member-device', {
            'deviceId': 'd1',
            'publicKey': 'pk',
          });
          fail('expected SecureAttendanceApiException');
        } on SecureAttendanceApiException catch (e) {
          expect(e.code, 'backend-unavailable');
          final msg = SecureAttendanceQrService.userFacingActivationError(e);
          expect(msg.contains('FormatException'), isFalse);
          expect(msg.contains('<!DOCTYPE'), isFalse);
          expect(msg.contains('disponible'), isTrue);
        }
      },
    );

    test('15. 500 JSON → controlled backend-error', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'code': 'internal', 'message': 'boom'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SecureAttendanceQrService(
        auth: _FakeAuth(),
        httpClient: client,
        apiBaseUrl: 'http://test.local/api',
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected SecureAttendanceApiException');
      } on SecureAttendanceApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.code, anyOf('internal', 'backend-error'));
      }
    });

    test('16. 401 JSON → controlled auth error', () async {
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
      );
      try {
        await service.debugPostForTests('/x', {});
        fail('expected SecureAttendanceApiException');
      } on SecureAttendanceApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, 'invalid-auth');
      }
    });

    test('HTML FormatException string is sanitized for UI', () {
      final msg = SecureAttendanceQrService.userFacingActivationError(
        FormatException('Unexpected character\n<!DOCTYPE html>'),
      );
      expect(msg.contains('FormatException'), isFalse);
      expect(msg.contains('<!DOCTYPE'), isFalse);
    });

    test('resolveApiBaseUrl production constant', () {
      expect(
        SecureAttendanceQrService.kProductionApiBase,
        contains('sistema-integrado-sindicato.web.app/api'),
      );
    });
  });
}
