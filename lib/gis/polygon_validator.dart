import '../models/geo_point.dart';
import 'geodesic_calculator.dart';

class PolygonValidationResult {
  final bool isValid;
  final String? errorMessage;

  const PolygonValidationResult({required this.isValid, this.errorMessage});
}

class PolygonValidator {
  static double _ccw(List<double> p1, List<double> p2, List<double> p3) {
    return (p2[0] - p1[0]) * (p3[1] - p1[1]) -
        (p2[1] - p1[1]) * (p3[0] - p1[0]);
  }

  static bool _segmentsIntersect(List<double> a1, List<double> a2,
      List<double> b1, List<double> b2) {
    final double d1 = _ccw(a1, a2, b1);
    final double d2 = _ccw(a1, a2, b2);
    final double d3 = _ccw(b1, b2, a1);
    final double d4 = _ccw(b1, b2, a2);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static bool hasSelfIntersection(List<GeoPoint> points) {
    final int n = points.length;
    if (n < 4) return false;

    final coords =
        points.map((p) => [p.longitude, p.latitude]).toList(growable: false);

    for (int i = 0; i < n; i++) {
      final a1 = coords[i];
      final a2 = coords[(i + 1) % n];

      for (int j = i + 2; j < n; j++) {
        // Skip adjacent edges in circular polygon
        if (i == 0 && j == n - 1) continue;
        final b1 = coords[j];
        final b2 = coords[(j + 1) % n];

        if (_segmentsIntersect(a1, a2, b1, b2)) {
          return true;
        }
      }
    }
    return false;
  }

  static PolygonValidationResult validate(List<GeoPoint> points) {
    if (points.length < 3) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'A polygon needs at least 3 points.',
      );
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.latitude < -90 ||
          p.latitude > 90 ||
          p.longitude < -180 ||
          p.longitude > 180) {
        return PolygonValidationResult(
          isValid: false,
          errorMessage: 'Point ${i + 1} has invalid GPS coordinates.',
        );
      }
    }

    if (hasSelfIntersection(points)) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'Boundary crosses itself.',
      );
    }

    final double area = GeodesicCalculator.areaSqMeters(points);
    if (area < 0.1) {
      return const PolygonValidationResult(
        isValid: false,
        errorMessage: 'Area is zero or boundary points are collinear.',
      );
    }

    return const PolygonValidationResult(isValid: true);
  }
}
