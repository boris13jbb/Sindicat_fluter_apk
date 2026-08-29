import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/security/attendance_qr/secure_qr_models.dart';
import '../../core/security/attendance_qr/secure_qr_protocol.dart';
import '../../services/secure_attendance_qr_service.dart';

/// Secure Attendance QR V2 tab for Mi Perfil.
///
/// Replaces legacy static workerCode QR for attendance. Does NOT offer
/// download/share of static QR.
class SecureAttendanceQrTab extends StatefulWidget {
  const SecureAttendanceQrTab({
    super.key,
    required this.hasLinkedMember,
    this.service,
  });

  final bool hasLinkedMember;
  final SecureAttendanceQrService? service;

  @override
  State<SecureAttendanceQrTab> createState() => _SecureAttendanceQrTabState();
}

class _SecureAttendanceQrTabState extends State<SecureAttendanceQrTab> {
  late final SecureAttendanceQrService _service;
  Map<String, dynamic>? _credential;
  String? _statusMessage;
  bool _busy = false;
  Satt2Response? _activeResponse;
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _scanningChallenge = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecureAttendanceQrService();
    _loadCredential();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _loadCredential() async {
    final cred = await _service.loadStoredCredential();
    if (!mounted) return;
    setState(() => _credential = cred);
  }

  Future<void> _prepareCredential() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      if (_service.assurance == SecureAttendanceAssurance.limitedAssurance ||
          _service.assurance == SecureAttendanceAssurance.onlineOnly) {
        // Honest Web limitation notice — do not claim hardware security.
        _statusMessage =
            'Este navegador ofrece protección limitada de claves. '
            'Para máxima seguridad usa la app Android/iOS.';
      }
      await _service.enrollMemberDevice();
      final cred = await _service.prepareOfflineCredential(
        locationPermission: false,
      );
      if (!mounted) return;
      setState(() {
        _credential = cred;
        _statusMessage = 'Credencial offline preparada.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'No se pudo preparar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startChallengeScan() async {
    setState(() => _scanningChallenge = true);
  }

  Future<void> _onChallengeDetected(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _scanningChallenge = false;
    });
    try {
      final response = await _service.buildResponseForChallenge(
        challengeQr: raw,
      );
      if (!mounted) return;
      _startCountdown(response);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('legacy')
          ? 'Código QR antiguo. Este código ya no es válido para asistencia segura.'
          : 'Challenge inválido: $e';
      setState(() => _statusMessage = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown(Satt2Response response) {
    _countdown?.cancel();
    setState(() {
      _activeResponse = response;
      _secondsLeft = kResponseMaxValiditySeconds;
      _statusMessage = 'Muestra este QR al operador. No compartas capturas.';
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _activeResponse = null;
          _secondsLeft = 0;
          _statusMessage = 'Respuesta expirada. Escanea un nuevo challenge.';
        });
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLinkedMember) {
      return PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Vincula tu socio activo para usar asistencia segura.',
            style: TextStyle(
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    if (_scanningChallenge) {
      return Column(
        children: [
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null && value.isNotEmpty) {
                    _onChallengeDetected(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _scanningChallenge = false),
            child: const Text('Cancelar'),
          ),
        ],
      );
    }

    final expiresAt = int.tryParse('${_credential?['expiresAt']}') ?? 0;
    final issuedAt = int.tryParse('${_credential?['issuedAtServer']}') ?? 0;
    final hasCred =
        _credential != null &&
        DateTime.now().millisecondsSinceEpoch < expiresAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de asistencia seguro',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Protocolo SATT2 (Ed25519). El QR estático por workerCode '
                  'ya no se usa para asistencia.',
                  style: TextStyle(
                    color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
                    height: 1.35,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Web: almacenamiento de claves con protección limitada '
                    '(LIMITED_ASSURANCE). Preferir app nativa para eventos.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (!hasCred) ...[
                  Text(
                    'Sin credencial offline en este dispositivo.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    onPressed: _busy ? null : _prepareCredential,
                    label: _busy
                        ? 'Preparando…'
                        : 'Preparar credencial offline',
                  ),
                ] else ...[
                  _infoRow('Estado', '🟢 Credencial lista'),
                  _infoRow(
                    'Preparado',
                    DateTime.fromMillisecondsSinceEpoch(
                      issuedAt,
                    ).toLocal().toString(),
                  ),
                  _infoRow(
                    'Válida hasta',
                    DateTime.fromMillisecondsSinceEpoch(
                      expiresAt,
                    ).toLocal().toString(),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    onPressed: _busy ? null : _startChallengeScan,
                    label: 'Escanear código del evento',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _prepareCredential,
                    child: const Text('Renovar credencial'),
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: AppDesignTokens.primaryDark.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_activeResponse != null) ...[
          const SizedBox(height: 16),
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Respuesta segura',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Válido por $_secondsLeft s',
                    style: TextStyle(
                      color: _secondsLeft <= 5
                          ? Colors.red
                          : AppDesignTokens.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: _activeResponse!.toQrString(),
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No descargues ni reenvíes este código. Expira automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
