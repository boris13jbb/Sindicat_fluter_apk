/// Trusted offline clock for scanners.
///
/// Authority comes from server time captured during package preparation,
/// not from the member phone clock.
enum ClockTrustState { clockOk, clockSuspicious, clockUntrusted }

class TrustedOfflineClock {
  TrustedOfflineClock({
    required this.serverTimeAtPreparationMs,
    required this.deviceTimeAtPreparationMs,
  }) : _monotonicStart = DateTime.now().millisecondsSinceEpoch;

  final int serverTimeAtPreparationMs;
  final int deviceTimeAtPreparationMs;
  final int _monotonicStart;

  /// Offset: trusted ≈ deviceNow + offset.
  int get trustedTimeOffsetMs =>
      serverTimeAtPreparationMs - deviceTimeAtPreparationMs;

  int nowTrustedMs({int? deviceNowMs}) {
    final device = deviceNowMs ?? DateTime.now().millisecondsSinceEpoch;
    return device + trustedTimeOffsetMs;
  }

  /// Detect abrupt jumps between wall clock and expected monotonic progression.
  ClockTrustState evaluate({
    required int deviceNowMs,
    int maxDriftMs = 120000,
  }) {
    final elapsedWall = deviceNowMs - deviceTimeAtPreparationMs;
    final expectedElapsed =
        DateTime.now().millisecondsSinceEpoch - _monotonicStart;
    final drift = (elapsedWall - expectedElapsed).abs();
    if (drift > maxDriftMs * 5) return ClockTrustState.clockUntrusted;
    if (drift > maxDriftMs) return ClockTrustState.clockSuspicious;
    return ClockTrustState.clockOk;
  }

  bool isWithinChallengeWindow({
    required int expiresAtTrustedMs,
    int? deviceNowMs,
  }) {
    return nowTrustedMs(deviceNowMs: deviceNowMs) <= expiresAtTrustedMs;
  }
}
