import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:fluter_apk/core/models/asistencia/attendance_event.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_crypto.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_models.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/features/profile/secure_attendance_qr_tab.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

const _testSeedB64 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _FakeUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeSecureService extends SecureAttendanceQrService {
  _FakeSecureService({required this.credential})
    : super(
        auth: _FakeAuth(),
        httpClient: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        apiBaseUrl: 'http://test.local/api',
        requireAppCheckHeader: false,
        appCheckTokenProvider: () async => null,
      );

  final Map<String, dynamic> credential;
  Satt2MemberQr? memberQr;
  int buildCalls = 0;

  @override
  Future<Map<String, dynamic>?> loadStoredCredential() async => credential;

  @override
  bool isCredentialUsable(Map<String, dynamic>? c, {int? nowMs}) => true;

  @override
  bool isCredentialNearExpiry(
    Map<String, dynamic>? c, {
    int withinMs = 24 * 60 * 60 * 1000,
    int? nowMs,
  }) => false;

  @override
  Future<Map<String, dynamic>> ensureCredentialReady({
    bool forceRenew = false,
  }) async => credential;

  @override
  Future<void> cacheRecentEvents(List<Map<String, dynamic>> events) async {}

  @override
  Future<List<Map<String, dynamic>>> loadCachedEvents() async => [];

  @override
  Future<Satt2MemberQr> buildMemberDynamicQr({
    required String eventId,
    int? issuedAtMs,
  }) async {
    buildCalls++;
    final crypto = SecureQrCrypto();
    final keys = await crypto.keyPairFromSeedBase64Url(_testSeedB64);
    memberQr = await Satt2MemberQr.create(
      eventId: eventId,
      memberDeviceId: 'dev-test',
      credentialId: credential['credentialId']?.toString() ?? 'cred1',
      memberKeyPair: keys,
      issuedAtMs: issuedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    return memberQr!;
  }
}

AttendanceEvent _event({
  required String id,
  required String nombre,
  String mode = kSecureQrModeDynamicMember,
}) {
  return AttendanceEvent(
    id: id,
    nombre: nombre,
    descripcion: '',
    fecha: DateTime.now().millisecondsSinceEpoch,
    lugar: '',
    tipo: 'reunion',
    activo: true,
    miembrosConvocados: const [],
    creadoPor: 'u',
    createdAt: 1,
    estado: 'en_curso',
    secureQrMode: mode,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final credential = <String, dynamic>{
    'credentialId': 'cred1',
    'expiresAt': DateTime.now()
        .add(const Duration(days: 3))
        .millisecondsSinceEpoch,
    'issuedAtServer': DateTime.now().millisecondsSinceEpoch,
  };

  testWidgets(
    'dynamic_member_qr: shows MI CÓDIGO, QrImageView, event, countdown',
    (tester) async {
      final events = [
        _event(id: 'evt1', nombre: 'Asamblea General Agosto 2026'),
      ];
      final service = _FakeSecureService(credential: credential);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecureAttendanceQrTab(
                hasLinkedMember: true,
                memberDisplayName: 'Juan Pérez',
                service: service,
                eventsLoader: () => Stream.value(events),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('MI CÓDIGO DE ASISTENCIA'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Asamblea General Agosto 2026'), findsOneWidget);
      expect(find.textContaining('Válido durante'), findsOneWidget);
      expect(find.textContaining('🟢 QR seguro activo'), findsOneWidget);

      expect(find.text('Preparar credencial offline'), findsNothing);
      expect(find.text('Escanear código del evento'), findsNothing);
      expect(service.buildCalls, greaterThan(0));
    },
  );

  testWidgets(
    'challenge_response: shows Escanear código del evento as primary action',
    (tester) async {
      final events = [
        _event(
          id: 'evt-hs',
          nombre: 'Evento alta seguridad',
          mode: kSecureQrModeChallengeResponse,
        ),
      ];
      final service = _FakeSecureService(credential: credential);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecureAttendanceQrTab(
                hasLinkedMember: true,
                memberDisplayName: 'Juan Pérez',
                service: service,
                eventsLoader: () => Stream.value(events),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('MI CÓDIGO DE ASISTENCIA'), findsOneWidget);
      expect(find.text('Escanear código del evento'), findsOneWidget);
      expect(find.text('Preparar credencial offline'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
    },
  );

  testWidgets('multiple events show event selector dropdown', (tester) async {
    final events = [
      _event(id: 'e1', nombre: 'Evento Uno'),
      _event(id: 'e2', nombre: 'Evento Dos'),
    ];
    final service = _FakeSecureService(credential: credential);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecureAttendanceQrTab(
              hasLinkedMember: true,
              service: service,
              eventsLoader: () => Stream.value(events),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Evento para registrar asistencia'), findsOneWidget);
    expect(
      find.byType(DropdownButtonFormField<AttendanceEvent>),
      findsOneWidget,
    );
  });
}
