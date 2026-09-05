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
import '../../services/attendance_service.dart';
import '../../services/secure_attendance_qr_service.dart';

/// Secure Attendance QR V2 tab for Mi Perfil — everyday SATT2M personal QR.
class SecureAttendanceQrTab extends StatefulWidget {
  const SecureAttendanceQrTab({
    super.key,
    required this.hasLinkedMember,
    this.memberDisplayName = '',
    this.service,
    this.attendanceService,
    this.eventsLoader,
  });

  final bool hasLinkedMember;
  final String memberDisplayName;
  final SecureAttendanceQrService? service;

  /// Deprecated test hook kept for compatibility; production event listing uses
  /// [SecureAttendanceQrService.listMemberQrEvents].
  final AttendanceService? attendanceService;

  /// Test override: when set, used instead of the sanitized backend endpoint.
  final Stream<List<AttendanceEvent>> Function()? eventsLoader;

  @override
  State<SecureAttendanceQrTab> createState() => _SecureAttendanceQrTabState();
}

class _SecureAttendanceQrTabState extends State<SecureAttendanceQrTab> {
  late final SecureAttendanceQrService _service;

  Map<String, dynamic>? _credential;
  List<AttendanceEvent> _events = const [];
  AttendanceEvent? _selectedEvent;
  String? _statusMessage;
  bool _busy = false;
  bool _needsActivation = false;
  bool _booting = true;

  Satt2MemberQr? _activeMemberQr;
  Timer? _rotationTimer;
  Timer? _tickTimer;
  int _secondsLeft = 0;

  /// High-security challenge/response path (only when event requires it).
  bool _scanningChallenge = false;
  Satt2Response? _activeResponse;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecureAttendanceQrService();
    _bootstrap();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!widget.hasLinkedMember) {
      setState(() => _booting = false);
      return;
    }
    setState(() {
      _booting = true;
      _statusMessage = null;
      _needsActivation = false;
    });
    try {
      await _loadEvents();
      await _activateCredential(silent: true);
      if (_selectedEvent != null &&
          _credential != null &&
          !_isChallengeMode(_selectedEvent!)) {
        await _startMemberQrRotation();
      }
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _loadEvents() async {
    List<AttendanceEvent> events = const [];
    try {
      if (widget.eventsLoader != null) {
        events = await widget.eventsLoader!().first.timeout(
          const Duration(seconds: 8),
        );
      } else {
        final eventMaps = await _service.listMemberQrEvents().timeout(
          const Duration(seconds: 8),
        );
        events = eventMaps
            .map((m) => AttendanceEvent.fromMap(m, m['id']?.toString() ?? ''))
            .where((e) => e.id.isNotEmpty)
            .toList();
      }
    } catch (_) {
      final cached = await _service.loadCachedEvents();
      events = cached
          .map((m) => AttendanceEvent.fromMap(m, m['id']?.toString() ?? ''))
          .where((e) => e.id.isNotEmpty)
          .toList();
    }

    final eligible = events.where(_isEligibleEvent).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (eligible.isNotEmpty) {
      await _service.cacheRecentEvents([
        for (final e in eligible.take(20)) _eventToMemberQrCacheMap(e),
      ]);
    }

    if (!mounted) return;
    setState(() {
      _events = eligible;
      if (eligible.isEmpty) {
        _selectedEvent = null;
      } else if (eligible.length == 1) {
        _selectedEvent = eligible.first;
      } else {
        final highlighted = AttendanceService.pickHighlightedOperationalEventId(
          eligible,
        );
        _selectedEvent = eligible.firstWhere(
          (e) => e.id == highlighted,
          orElse: () => eligible.first,
        );
      }
    });
  }

  bool _isEligibleEvent(AttendanceEvent e) {
    if (!e.activo) return false;
    final estado = e.estado.toLowerCase().trim();
    if (estado == 'finalizado' || estado == 'cancelado') return false;
    return true;
  }

  bool _isChallengeMode(AttendanceEvent e) =>
      e.secureQrMode == kSecureQrModeChallengeResponse;

  Map<String, dynamic> _eventToMemberQrCacheMap(AttendanceEvent e) {
    final data = <String, dynamic>{
      'id': e.id,
      'nombre': e.nombre,
      'fecha': e.fecha,
      'lugar': e.lugar,
      'tipo': e.tipo,
      'activo': e.activo,
      'estado': e.estado,
      'secureQrMode': e.secureQrMode,
    };
    if (e.fechaFin != null) {
      data['fechaFin'] = e.fechaFin;
    }
    return data;
  }

  Future<void> _activateCredential({bool silent = false}) async {
    setState(() {
      _busy = true;
      if (!silent) _statusMessage = null;
    });
    try {
      final cred = await _service.ensureCredentialReady();
      if (!mounted) return;
      setState(() {
        _credential = cred;
        _needsActivation = false;
        _statusMessage = null;
      });
    } catch (e) {
      Map<String, dynamic>? existing;
      try {
        existing = await _service.loadVerifiedStoredCredential();
      } catch (_) {
        existing = null;
      }
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _credential = existing;
          _needsActivation = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _credential = null;
        _needsActivation = true;
        _statusMessage = SecureAttendanceQrService.userFacingActivationError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onEventChanged(AttendanceEvent? event) async {
    _rotationTimer?.cancel();
    _tickTimer?.cancel();
    setState(() {
      _selectedEvent = event;
      _activeMemberQr = null;
      _activeResponse = null;
      _secondsLeft = 0;
      _scanningChallenge = false;
    });
    if (event == null) return;
    if (_isChallengeMode(event)) return;
    if (_credential != null) {
      await _startMemberQrRotation();
    }
  }

  Future<void> _startMemberQrRotation() async {
    final event = _selectedEvent;
    if (event == null || _credential == null) return;
    _rotationTimer?.cancel();
    _tickTimer?.cancel();
    await _rotateMemberQr();
    _rotationTimer = Timer.periodic(
      const Duration(seconds: kQrRotationSeconds),
      (_) => _rotateMemberQr(),
    );
  }

  Future<void> _rotateMemberQr() async {
    final event = _selectedEvent;
    if (event == null) return;
    try {
      final qr = await _service.buildMemberDynamicQr(eventId: event.id);
      if (!mounted) return;
      _tickTimer?.cancel();
      setState(() {
        _activeMemberQr = qr;
        _secondsLeft =
            ((qr.expiresAt - DateTime.now().millisecondsSinceEpoch) / 1000)
                .ceil()
                .clamp(0, kQrMaxValiditySeconds);
        _statusMessage = null;
      });
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final left =
            ((_activeMemberQr!.expiresAt -
                        DateTime.now().millisecondsSinceEpoch) /
                    1000)
                .ceil();
        if (left <= 0) {
          t.cancel();
          setState(() {
            _secondsLeft = 0;
          });
          return;
        }
        setState(() => _secondsLeft = left);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeMemberQr = null;
        _statusMessage = e.toString().contains('missing-credential')
            ? 'Este dispositivo todavía no ha sido activado para asistencia. '
                  'Conéctate a Internet una vez para activar tu QR seguro.'
            : 'No se pudo generar el código. Inténtalo de nuevo.';
      });
    }
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
      _startResponseCountdown(response);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('legacy')
          ? 'Código QR antiguo. Este código ya no es válido para asistencia segura.'
          : 'No se pudo generar la respuesta. Escanea de nuevo el código del evento.';
      setState(() => _statusMessage = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResponseCountdown(Satt2Response response) {
    _tickTimer?.cancel();
    setState(() {
      _activeResponse = response;
      _secondsLeft = kResponseMaxValiditySeconds;
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _activeResponse = null;
          _secondsLeft = 0;
          _statusMessage =
              'Código expirado. Escanea un nuevo código del evento.';
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

    if (_booting) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
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

    final event = _selectedEvent;
    final challengeMode = event != null && _isChallengeMode(event);

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
                  'MI CÓDIGO DE ASISTENCIA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_events.isEmpty) ...[
                  Text(
                    'No existe un evento de asistencia activo.',
                    style: TextStyle(
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.7),
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  if (_events.length > 1) ...[
                    Text(
                      'Evento para registrar asistencia',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AttendanceEvent>(
                      initialValue: _selectedEvent,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final e in _events)
                          DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.nombre,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy ? null : _onEventChanged,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_needsActivation || _credential == null) ...[
                    Text(
                      'Este dispositivo todavía no ha sido activado para asistencia. '
                      'Conéctate a Internet una vez para activar tu QR seguro.',
                      style: TextStyle(
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _activateCredential();
                              if (_credential != null &&
                                  _selectedEvent != null &&
                                  !_isChallengeMode(_selectedEvent!)) {
                                await _startMemberQrRotation();
                              }
                            },
                      label: _busy ? 'Activando…' : 'Reintentar activación',
                    ),
                  ] else if (challengeMode) ...[
                    Text(
                      'Este evento requiere el modo de alta seguridad.',
                      style: TextStyle(
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _scanningChallenge = true),
                      label: 'Escanear código del evento',
                    ),
                  ] else if (_activeMemberQr != null) ...[
                    Center(
                      child: QrImageView(
                        data: _activeMemberQr!.toQrString(),
                        size: 260,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.memberDisplayName.trim().isNotEmpty)
                      Text(
                        widget.memberDisplayName.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    if (event != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.nombre,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppDesignTokens.primaryDark.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '🟢 QR seguro activo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Válido durante $_secondsLeft segundos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _secondsLeft <= 5
                            ? Colors.red
                            : AppDesignTokens.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_secondsLeft / kQrMaxValiditySeconds).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Este código cambia automáticamente por seguridad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Para mayor seguridad en eventos presenciales recomendamos '
                        'usar la aplicación móvil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Text(
                      'Preparando tu código…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.7),
                      height: 1.35,
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
                  const Text(
                    'Código de respuesta',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Válido durante $_secondsLeft segundos',
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
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
