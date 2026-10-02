class AppConstants {
  static const String appName = 'FIELD MEASURE PRO';
  static const String appTagline = 'Measure. Adjust. Know.';

  // WGS84 Authalic Sphere constants
  static const double wgs84SemiMajorAxis = 6378137.0; // a (meters)
  static const double wgs84SemiMinorAxis = 6356752.314245; // b (meters)
  static const double wgs84Flattening = 1 / 298.257223563; // f
  static const double wgs84AuthalicRadius = 6371007.2; // Rq (meters)

  // GPS Quality evaluation thresholds
  static const double accuracyExcellentMeters = 5.0;
  static const double accuracyGoodMeters = 10.0;
  static const double accuracyFairMeters = 20.0;
  static const double maxWalkingSpeedMps = 15.0; // 54 km/h jump threshold
  static const double minPointMovementMeters = 0.8; // Station jitter threshold
  static const double closeFieldDistanceMeters = 15.0; // Proximity to start point

  // Legal survey estimate disclaimer
  static const String surveyDisclaimer =
      'GPS/map-based measurements are estimates and should not be treated as a legally certified land survey.';
}
