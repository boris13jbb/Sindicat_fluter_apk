/// Trusted offline clock for scanners.
///
/// The anchor is the later of signed server preparation time and the device
/// time observed when the package passed verification. After that point time
/// advances with [Stopwatch], so wall-clock changes cannot extend a loaded
/// package's validity.
enum ClockTrustState { clockOk, clockSuspicious, clockUntrusted }

class TrustedOfflineClock {
  TrustedOfflineClock({
    required this.serverTimeAtPreparationMs,
    required this.deviceTimeAtPreparationMs,
  }) : _trustedTimeAtAnchorMs =
           serverTimeAtPreparationMs > deviceTimeAtPreparationMs
           ? serverTimeAtPreparationMs
           : deviceTimeAtPreparationMs,
       _elapsed = Stopwatch()..start();

  final int serverTimeAtPreparationMs;
  final int deviceTimeAtPreparationMs;
  final int _trustedTimeAtAnchorMs;
  final Stopwatch _elapsed;

  /// Offset: trusted ≈ deviceNow + offset.
  int get trustedTimeOffsetMs =>
      _trustedTimeAtAnchorMs - deviceTimeAtPreparationMs;

  int nowTrustedMs() => _trustedTimeAtAnchorMs + _elapsed.elapsedMilliseconds;

  /// Detect abrupt jumps between wall clock and expected monotonic progression.
  ClockTrustState evaluate({
    required int deviceNowMs,
    int maxDriftMs = 120000,
  }) {
    final elapsedWall = deviceNowMs - deviceTimeAtPreparationMs;
    final expectedElapsed = _elapsed.elapsedMilliseconds;
    final drift = (elapsedWall - expectedElapsed).abs();
    if (drift > maxDriftMs * 5) return ClockTrustState.clockUntrusted;
    if (drift > maxDriftMs) return ClockTrustState.clockSuspicious;
    return ClockTrustState.clockOk;
  }

  bool isWithinChallengeWindow({required int expiresAtTrustedMs}) {
    return nowTrustedMs() <= expiresAtTrustedMs;
  }
}
