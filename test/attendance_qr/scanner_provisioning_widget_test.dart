import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fluter_apk/core/models/user.dart';
import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_models.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_protocol.dart';
import 'package:fluter_apk/core/security/attendance_qr/secure_qr_validator.dart';
import 'package:fluter_apk/core/security/attendance_qr/trusted_offline_clock.dart';
import 'package:fluter_apk/features/asistencia/scanner_approval_dialog.dart';
import 'package:fluter_apk/features/asistencia/secure_scanner_screen.dart';
import 'package:fluter_apk/providers/auth_provider.dart';
import 'package:fluter_apk/services/attendance_service.dart';
import 'package:fluter_apk/services/secure_attendance_qr_service.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  _FakeAuthProvider(UserRole role)
    : user = AppUser(id: 'user-1', email: 'user@test.invalid', role: role);

  @override
  final AppUser user;

  @override
  bool get isLoading => false;

  @override
  bool get isSignedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttendanceService extends Fake implements AttendanceService {
  _FakeAttendanceService({this.challengeMode = false});

  final bool challengeMode;

  @override
  Future<AttendanceEvent?> getEventById(String eventId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AttendanceEvent(
      id: eventId,
      nombre: 'Evento test',
      descripcion: '',
      fecha: now - 1000,
      fechaFin: now + 86_400_000,
      lugar: 'Test',
      tipo: 'reunion',
      activo: true,
      miembrosConvocados: const [],
      creadoPor: 'admin-1',
      createdAt: now,
      secureQrMode: challengeMode
          ? kSecureQrModeChallengeResponse
          : kSecureQrModeDynamicMember,
    );
  }
}

class _UnavailableAttendanceService extends Fake implements AttendanceService {
  @override
  Future<AttendanceEvent?> getEventById(String eventId) =>
      Completer<AttendanceEvent?>().future;
}

class _FakeSecureAttendanceService extends Fake
    implements SecureAttendanceQrService {
  _FakeSecureAttendanceService({
    this.registrationStatus = ScannerProvisioningStatus.pending,
    this.storedPackage,
    this.registrationError,
  });

  final ScannerProvisioningStatus registrationStatus;
  final AttendanceOfflinePackage? storedPackage;
  final Object? registrationError;
  int registerCalls = 0;
  int prepareCalls = 0;
  int approveCalls = 0;
  int loadCalls = 0;
  final approveArguments = <bool>[];
  String? approvedScannerId;

  @override
  Future<String> ensureLocalDeviceId() async => 'scanner-local-1';

  @override
  Future<AttendanceOfflinePackage?> loadVerifiedStoredPackage({
    required String expectedEventId,
    required String expectedScannerId,
    int? nowMs,
  }) async {
    loadCalls += 1;
    return storedPackage;
  }

  @override
  Future<ScannerProvisioningResult> registerScannerDevice({
    required String scannerId,
    bool approve = false,
    String? deviceLabel,
  }) async {
    registerCalls += 1;
    approveArguments.add(approve);
    if (registrationError != null) throw registrationError!;
    return ScannerProvisioningResult(
      scannerId: scannerId,
      status: registrationStatus,
    );
  }

  @override
  Future<Map<String, dynamic>> prepareOfflineEvent({
    required String eventId,
    required String scannerId,
  }) async {
    prepareCalls += 1;
    return const {};
  }

  @override
  Future<ScannerProvisioningResult> approveScannerDevice({
    required String scannerId,
  }) async {
    approveCalls += 1;
    approvedScannerId = scannerId;
    return ScannerProvisioningResult(
      scannerId: scannerId,
      status: ScannerProvisioningStatus.active,
    );
  }

  @override
  TrustedOfflineClock clockForPackage(AttendanceOfflinePackage package) {
    return TrustedOfflineClock(
      serverTimeAtPreparationMs: package.serverTimeAtPreparation,
      deviceTimeAtPreparationMs: package.serverTimeAtPreparation,
    );
  }

  @override
  Future<Satt2Challenge> createChallenge({
    required AttendanceOfflinePackage package,
    required TrustedOfflineClock clock,
  }) async {
    final now = package.serverTimeAtPreparation;
    return Satt2Challenge(
      eventId: package.eventId,
      scannerId: package.scannerId,
      challengeId: 'challenge-1',
      challengeNonce: 'nonce-1',
      issuedAtTrusted: now,
      expiresAtTrusted: now + 15_000,
      signature: 'test-signature',
    );
  }
}

AttendanceOfflinePackage _offlinePackage() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return AttendanceOfflinePackage(
    packageId: 'package-1',
    eventId: 'event-1',
    eventName: 'Evento test',
    startAt: now - 1000,
    endAt: now + 86_400_000,
    issuedAtServer: now,
    expiresAt: now + 86_400_000,
    serverTimeAtPreparation: now,
    scannerId: 'scanner-local-1',
    scannerPublicKey: 'test-public-key',
    participants: const [],
    signature: 'test-signature',
    keyVersion: 'v1',
  );
}

Widget _scannerApp({
  required _FakeSecureAttendanceService service,
  required UserRole role,
  bool challengeMode = false,
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuthProvider(role),
    child: MaterialApp(
      home: SecureScannerScreen(
        eventId: 'event-1',
        service: service,
        attendanceService: _FakeAttendanceService(challengeMode: challengeMode),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'offline package loads while event network request never completes',
    (tester) async {
      final service = _FakeSecureAttendanceService(
        storedPackage: _offlinePackage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SecureScannerScreen(
            eventId: 'event-1',
            service: service,
            attendanceService: _UnavailableAttendanceService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.loadCalls, 1);
      expect(service.registerCalls, 0);
      expect(service.prepareCalls, 0);
      expect(find.text('Sincronizar pendientes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );
  testWidgets('new operator scanner stays pending and package is blocked', (
    tester,
  ) async {
    final service = _FakeSecureAttendanceService();
    await tester.pumpWidget(
      _scannerApp(service: service, role: UserRole.operadorAsistencia),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prepare_secure_offline_package')));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 1);
    expect(service.approveArguments, [false]);
    expect(service.prepareCalls, 0);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(find.byKey(const Key('scanner_provisioning_id')), findsOneWidget);
    expect(find.text('scanner-local-1'), findsOneWidget);
  });

  testWidgets('active scanner prepares the offline package', (tester) async {
    final service = _FakeSecureAttendanceService(
      registrationStatus: ScannerProvisioningStatus.active,
    );
    await tester.pumpWidget(
      _scannerApp(service: service, role: UserRole.operadorAsistencia),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prepare_secure_offline_package')));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 1);
    expect(service.approveArguments, [false]);
    expect(service.prepareCalls, 1);
  });

  testWidgets(
    'admin self-registration requests approval and prepares package',
    (tester) async {
      final service = _FakeSecureAttendanceService(
        registrationStatus: ScannerProvisioningStatus.active,
      );
      await tester.pumpWidget(
        _scannerApp(service: service, role: UserRole.admin),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prepare_secure_offline_package')));
      await tester.pumpAndSettle();

      expect(service.approveArguments, [true]);
      expect(service.prepareCalls, 1);
    },
  );

  testWidgets('revoked scanner shows safe error and never prepares package', (
    tester,
  ) async {
    final service = _FakeSecureAttendanceService(
      registrationError: SecureAttendanceApiException('scanner-revoked'),
    );
    await tester.pumpWidget(
      _scannerApp(service: service, role: UserRole.operadorAsistencia),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prepare_secure_offline_package')));
    await tester.pumpAndSettle();

    expect(service.prepareCalls, 0);
    expect(
      find.text('Este dispositivo ya no está autorizado como escáner.'),
      findsOneWidget,
    );
  });

  testWidgets('verified stored package remains usable without registration', (
    tester,
  ) async {
    final service = _FakeSecureAttendanceService(
      storedPackage: _offlinePackage(),
    );
    await tester.pumpWidget(
      _scannerApp(
        service: service,
        role: UserRole.operadorAsistencia,
        challengeMode: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(service.loadCalls, 1);
    expect(service.registerCalls, 0);
    expect(service.prepareCalls, 0);
    expect(find.text('Modo challenge / respuesta'), findsOneWidget);
  });

  testWidgets('admin approval dialog calls backend and shows success', (
    tester,
  ) async {
    final service = _FakeSecureAttendanceService(
      registrationStatus: ScannerProvisioningStatus.active,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScannerApprovalDialog(service: service)),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('scanner_approval_id_input')),
      ' scanner-pending-9 ',
    );
    await tester.tap(find.byKey(const Key('approve_scanner_button')));
    await tester.pumpAndSettle();

    expect(service.approveCalls, 1);
    expect(service.approvedScannerId, 'scanner-pending-9');
    expect(find.text('Escáner aprobado correctamente.'), findsOneWidget);
  });
}
