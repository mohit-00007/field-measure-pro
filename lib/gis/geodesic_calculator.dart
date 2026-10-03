import 'dart:math' as math;
import '../models/geo_point.dart';
import '../core/constants.dart';

class GeodesicCalculator {
  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Geodesic distance between two points in meters using Haversine formula on WGS84 authalic sphere.
  static double distanceMeters(GeoPoint p1, GeoPoint p2) {
    final double phi1 = _toRadians(p1.latitude);
    final double phi2 = _toRadians(p2.latitude);
    final double deltaPhi = _toRadians(p2.latitude - p1.latitude);
    final double deltaLambda = _toRadians(p2.longitude - p1.longitude);

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return AppConstants.wgs84AuthalicRadius * c;
  }

  /// Total closed perimeter of a polygon in meters.
  static double perimeterMeters(List<GeoPoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length; i++) {
      final int nextIndex = (i + 1) % points.length;
      total += distanceMeters(points[i], points[nextIndex]);
    }
    return total;
  }

  /// Open path length in meters.
  static double pathLengthMeters(List<GeoPoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }

  /// Calculates geodesic surface area of a closed polygon in square meters (m²)
  /// using spherical excess integration across ellipsoidal latitude/longitude coordinates.
  static double areaSqMeters(List<GeoPoint> points) {
    if (points.length < 3) return 0.0;

    double totalExcess = 0.0;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final GeoPoint p1 = points[i];
      final GeoPoint p2 = points[(i + 1) % n];

      final double lambda1 = _toRadians(p1.longitude);
      final double lambda2 = _toRadians(p2.longitude);
      final double phi1 = _toRadians(p1.latitude);
      final double phi2 = _toRadians(p2.latitude);

      double deltaLambda = lambda2 - lambda1;
      while (deltaLambda > math.pi) {
        deltaLambda -= 2 * math.pi;
      }
      while (deltaLambda < -math.pi) {
        deltaLambda += 2 * math.pi;
      }

      totalExcess += deltaLambda * (2 + math.sin(phi1) + math.sin(phi2));
    }

    final double r = AppConstants.wgs84AuthalicRadius;
    final double rawArea = (totalExcess.abs() * r * r) / 2.0;
    return rawArea;
  }

  /// Midpoint between two coordinates
  static GeoPoint midpoint(GeoPoint p1, GeoPoint p2) {
    return GeoPoint(
      latitude: (p1.latitude + p2.latitude) / 2,
      longitude: (p1.longitude + p2.longitude) / 2,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
