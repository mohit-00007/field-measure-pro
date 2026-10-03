import 'dart:math' as math;
import '../models/geo_point.dart';
import 'geodesic_calculator.dart';

class PathSimplifier {
  static double _perpendicularDistanceMeters(
      GeoPoint p, GeoPoint a, GeoPoint b) {
    final double dAB = GeodesicCalculator.distanceMeters(a, b);
    if (dAB < 0.001) {
      return GeodesicCalculator.distanceMeters(p, a);
    }

    final double cosLat =
        math.cos((a.latitude + b.latitude) / 2.0 * math.pi / 180.0);
    const double degToMetersLat = 111132.95;
    final double degToMetersLon = 111132.95 * cosLat;

    final double px = (p.longitude - a.longitude) * degToMetersLon;
    final double py = (p.latitude - a.latitude) * degToMetersLat;
    final double bx = (b.longitude - a.longitude) * degToMetersLon;
    final double by = (b.latitude - a.latitude) * degToMetersLat;

    final double abSq = bx * bx + by * by;
    if (abSq == 0) return math.sqrt(px * px + py * py);

    final double t = math.max(0.0, math.min(1.0, (px * bx + py * by) / abSq));
    final double projX = t * bx;
    final double projY = t * by;

    final double dx = px - projX;
    final double dy = py - projY;

    return math.sqrt(dx * dx + dy * dy);
  }

  /// Ramer-Douglas-Peucker (RDP) algorithm on an open path
  static List<GeoPoint> simplifyPath(
      List<GeoPoint> points, double toleranceMeters) {
    if (points.length <= 2) return points;

    double maxDistance = 0.0;
    int maxIndex = 0;
    final GeoPoint start = points.first;
    final GeoPoint end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final double d = _perpendicularDistanceMeters(points[i], start, end);
      if (d > maxDistance) {
        maxDistance = d;
        maxIndex = i;
      }
    }

    if (maxDistance > toleranceMeters) {
      final List<GeoPoint> left =
          simplifyPath(points.sublist(0, maxIndex + 1), toleranceMeters);
      final List<GeoPoint> right =
          simplifyPath(points.sublist(maxIndex), toleranceMeters);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [start, end];
    }
  }

  /// Simplifies a closed polygon while preserving shape and loop integrity
  static List<GeoPoint> simplifyPolygon(
      List<GeoPoint> points, double toleranceMeters) {
    if (points.length <= 4) return points;

    double maxDist = 0.0;
    int splitIndex = points.length ~/ 2;

    for (int i = 1; i < points.length; i++) {
      final double d = GeodesicCalculator.distanceMeters(points[0], points[i]);
      if (d > maxDist) {
        maxDist = d;
        splitIndex = i;
      }
    }

    final path1 = points.sublist(0, splitIndex + 1);
    final path2 = [...points.sublist(splitIndex), points[0]];

    final s1 = simplifyPath(path1, toleranceMeters);
    final s2 = simplifyPath(path2, toleranceMeters);

    final combined = [...s1.sublist(0, s1.length - 1), ...s2.sublist(0, s2.length - 1)];

    return combined.length >= 3 ? combined : points;
  }
}
