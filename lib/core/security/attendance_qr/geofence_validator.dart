import 'dart:math';

/// Haversine distance in meters between two WGS84 points.
double calculateDistanceMeters({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRadians(double degrees) => degrees * pi / 180.0;

enum GeofenceEvaluation {
  pass,
  outside,
  lowAccuracy,
  missingRequired,
  disabled,
}

class GeofenceConfig {
  const GeofenceConfig({
    this.enabled = false,
    this.latitude,
    this.longitude,
    this.radiusMeters = 150,
    this.requireScannerLocation = false,
    this.maxAccuracyMeters = 80,
  });

  final bool enabled;
  final double? latitude;
  final double? longitude;
  final double radiusMeters;
  final bool requireScannerLocation;
  final double maxAccuracyMeters;
}

class GeofenceResult {
  const GeofenceResult({required this.evaluation, this.distanceMeters});

  final GeofenceEvaluation evaluation;
  final double? distanceMeters;
}

/// GPS is reinforcement / audit only — never sole presence proof.
GeofenceResult evaluateGeofence({
  required GeofenceConfig config,
  double? scanLatitude,
  double? scanLongitude,
  double? scanAccuracyMeters,
}) {
  if (!config.enabled) {
    return const GeofenceResult(evaluation: GeofenceEvaluation.disabled);
  }

  final hasLocation = scanLatitude != null && scanLongitude != null;
  if (!hasLocation) {
    return GeofenceResult(
      evaluation: config.requireScannerLocation
          ? GeofenceEvaluation.missingRequired
          : GeofenceEvaluation.lowAccuracy,
    );
  }

  if (config.latitude == null || config.longitude == null) {
    return const GeofenceResult(evaluation: GeofenceEvaluation.disabled);
  }

  if (scanAccuracyMeters != null &&
      scanAccuracyMeters > config.maxAccuracyMeters) {
    return GeofenceResult(
      evaluation: GeofenceEvaluation.lowAccuracy,
      distanceMeters: calculateDistanceMeters(
        lat1: config.latitude!,
        lon1: config.longitude!,
        lat2: scanLatitude,
        lon2: scanLongitude,
      ),
    );
  }

  final distance = calculateDistanceMeters(
    lat1: config.latitude!,
    lon1: config.longitude!,
    lat2: scanLatitude,
    lon2: scanLongitude,
  );

  if (distance > config.radiusMeters) {
    return GeofenceResult(
      evaluation: GeofenceEvaluation.outside,
      distanceMeters: distance,
    );
  }

  return GeofenceResult(
    evaluation: GeofenceEvaluation.pass,
    distanceMeters: distance,
  );
}
