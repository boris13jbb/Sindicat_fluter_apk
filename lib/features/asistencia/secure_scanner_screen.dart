import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/security/attendance_qr/secure_qr_models.dart';
import '../../core/security/attendance_qr/secure_qr_protocol.dart';
import '../../core/security/attendance_qr/secure_qr_validator.dart';
import '../../core/security/attendance_qr/trusted_offline_clock.dart';
import '../../services/attendance_service.dart';
import '../../services/secure_attendance_qr_service.dart';

/// Secure Attendance QR V2 scanner — SATT2M (default) + optional SATT2C/R.
class SecureScannerScreen extends StatefulWidget {
  const SecureScannerScreen({
    super.key,
    required this.eventId,
    this.scannerId,
    this.service,
    this.attendanceService,
  });

  final String eventId;
  final String? scannerId;
  final SecureAttendanceQrService? service;
  final AttendanceService? attendanceService;

  @override
  State<SecureScannerScreen> createState() => _SecureScannerScreenState();
}

class _SecureScannerScreenState extends State<SecureScannerScreen> {
  late final SecureAttendanceQrService _service;
  late final AttendanceService _attendance;
  AttendanceOfflinePackage? _package;
  TrustedOfflineClock? _clock;
  Satt2Challenge? _challenge;
  Timer? _rotation;
  String? _message;
  bool _busy = false;
  bool _scanMode = true;
  bool _challengeMode = false;
  OfflineParticipantSnapshot? _lastParticipant;
  OfflineAttendanceReceipt? _lastReceipt;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecureAttendanceQrService();
    _attendance = widget.attendanceService ?? AttendanceService();
    _bootstrap();
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final event = await _attendance.getEventById(widget.eventId);
      final challengeMode =
          event?.secureQrMode == kSecureQrModeChallengeResponse;
      setState(() => _challengeMode = challengeMode);
      await _loadPackage();
    } catch (e) {
      setState(() {
        _busy = false;
        _message = 'Error iniciando escáner: $e';
      });
    }
  }

  Future<void> _loadPackage() async {
    setState(() => _busy = true);
    try {
      final pkgMap = await _service.loadActiveOfflinePackage();
      if (pkgMap == null) {
        setState(() {
          _message =
              'Sin paquete offline. Prepáralo con Internet antes del evento.';
          _busy = false;
        });
        return;
      }
      final package = _service.packageFromStored(pkgMap);
      if (package == null || package.eventId != widget.eventId) {
        setState(() {
          _message = 'Paquete offline no corresponde a este evento.';
          _busy = false;
        });
        return;
      }
      final clock = _service.clockForPackage(package);
      final expired = clock.nowTrustedMs() > package.expiresAt;
      setState(() {
        _package = package;
        _clock = clock;
        _busy = false;
        _message = expired
            ? 'Paquete offline vencido. Vuelve a prepararlo.'
            : null;
        _scanMode = !_challengeMode;
      });
      if (!expired && _challengeMode) {
        await _startChallengeRotation();
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _message = 'Error cargando paquete: $e';
      });
    }
  }

  Future<void> _prepareOnline() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final scannerId =
          widget.scannerId ?? await _service.ensureLocalDeviceId();
      await _service.prepareOfflineEvent(
        eventId: widget.eventId,
        scannerId: scannerId,
      );
      await _loadPackage();
    } catch (e) {
      setState(() {
        _busy = false;
        _message = SecureAttendanceQrService.userFacingActivationError(e);
      });
    }
  }

  Future<void> _startChallengeRotation() async {
    _rotation?.cancel();
    await _rotateChallenge();
    _rotation = Timer.periodic(
      const Duration(seconds: kChallengeRotationSeconds),
      (_) => _rotateChallenge(),
    );
  }

  Future<void> _rotateChallenge() async {
    final package = _package;
    final clock = _clock;
    if (package == null || clock == null) return;
    if (clock.evaluate(deviceNowMs: DateTime.now().millisecondsSinceEpoch) ==
        ClockTrustState.clockUntrusted) {
      setState(() => _message = 'Reloj no confiable — re-prepara el paquete.');
      return;
    }
    try {
      final challenge = await _service.createChallenge(
        package: package,
        clock: clock,
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Error generando challenge: $e');
    }
  }

  Future<void> _onQrScanned(String raw) async {
    final package = _package;
    final clock = _clock;
    if (package == null || clock == null) return;

    if (Satt2WireCodec.isLegacyWorkerCodeQr(raw) &&
        !raw.trim().startsWith(kSatt2MemberType) &&
        !raw.trim().startsWith(kSatt2ResponseType)) {
      setState(() {
        _message =
            'Código QR antiguo. Este código ya no es válido para asistencia segura.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _service.validateAndStoreScannedQr(
        rawQr: raw,
        package: package,
        clock: clock,
        expectedChallenge: _challengeMode ? _challenge : null,
      );
      if (!mounted) return;
      if (result.rejected) {
        setState(() {
          _busy = false;
          _message = _rejectLabel(result.reason);
        });
        return;
      }
      setState(() {
        _busy = false;
        _lastParticipant = result.participant;
        _lastReceipt = result.receipt;
        _scanMode = true;
        _message = 'Asistencia registrada offline — pendiente sincronizar';
      });
      if (_challengeMode) {
        await _rotateChallenge();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Error: $e';
      });
    }
  }

  String _rejectLabel(SecureQrRejectReason? reason) {
    return switch (reason) {
      SecureQrRejectReason.legacyQr =>
        'Código QR antiguo. Este código ya no es válido para asistencia segura.',
      SecureQrRejectReason.expired => 'Código expirado',
      SecureQrRejectReason.replay => 'Código ya usado',
      SecureQrRejectReason.wrongEvent => 'Código de otro evento',
      SecureQrRejectReason.wrongScanner => 'Código de otro escáner',
      SecureQrRejectReason.invalidSignature => 'Firma inválida',
      SecureQrRejectReason.inactiveMember => 'Socio no autorizado',
      SecureQrRejectReason.revokedDevice => 'Dispositivo no autorizado',
      SecureQrRejectReason.duplicateLocal =>
        'Este socio ya fue registrado en este evento.',
      SecureQrRejectReason.geofenceOutside => 'Fuera de ubicación permitida',
      SecureQrRejectReason.geofenceMissing =>
        'Ubicación requerida no disponible',
      SecureQrRejectReason.geofenceLowAccuracy => 'Ubicación poco precisa',
      SecureQrRejectReason.packageExpired => 'Paquete offline vencido',
      _ => 'Código inválido',
    };
  }

  Future<void> _sync() async {
    final package = _package;
    if (package == null) return;
    setState(() => _busy = true);
    try {
      await _service.syncPendingBatch(scannerId: package.scannerId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Sincronización enviada';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Sync pendiente / error: '
            '${SecureAttendanceQrService.userFacingActivationError(e)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengeQr = _challenge?.toQrString();
    final expiresAt = _package?.expiresAt;
    final expiresLabel = expiresAt == null
        ? '—'
        : DateTime.fromMillisecondsSinceEpoch(expiresAt).toLocal().toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _challengeMode ? 'Asistencia (alta seguridad)' : 'Asistencia segura',
        ),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _challengeMode
                        ? 'Modo challenge / respuesta'
                        : 'Escanear código del socio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paquete válido hasta: $expiresLabel',
                    style: AppDesignTokens.bodyMuted(context),
                  ),
                  const SizedBox(height: 12),
                  if (_package == null)
                    PrimaryButton(
                      onPressed: _busy ? null : _prepareOnline,
                      label: 'Preparar paquete offline',
                      icon: Icons.cloud_download_outlined,
                    )
                  else ...[
                    if (_challengeMode &&
                        challengeQr != null &&
                        !_scanMode) ...[
                      const Text(
                        'Muestra este challenge al socio (rota cada 15 s)',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: QrImageView(
                          data: challengeQr,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        onPressed: () => setState(() => _scanMode = true),
                        label: 'Escanear respuesta del socio',
                        icon: Icons.qr_code_scanner,
                      ),
                    ],
                    if (_scanMode)
                      SizedBox(
                        height: 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            onDetect: (capture) {
                              final values = <String>[];
                              for (final b in capture.barcodes) {
                                final v = b.rawValue;
                                if (v != null && v.isNotEmpty) values.add(v);
                              }
                              if (values.isEmpty || _busy) return;
                              _onQrScanned(values.first);
                            },
                          ),
                        ),
                      ),
                    if (_challengeMode && _scanMode) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _scanMode = false),
                        child: const Text('Volver al challenge'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _sync,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sincronizar pendientes'),
                    ),
                  ],
                ],
              ),
            ),
            if (_lastParticipant != null && _lastReceipt != null) ...[
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ASISTENCIA REGISTRADA OFFLINE',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastParticipant!.displayName.isEmpty
                          ? 'Socio ${_lastParticipant!.memberId}'
                          : _lastParticipant!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Nº socio: ${_lastParticipant!.memberNumber}'),
                    Text('Sync: ${_lastReceipt!.syncStatus.name}'),
                  ],
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color:
                      _message!.contains('offline') ||
                          _message!.contains('Sincronización')
                      ? AppDesignTokens.primaryDark
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
