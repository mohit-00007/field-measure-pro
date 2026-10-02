import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/geo_point.dart';
import '../lib/gis/geodesic_calculator.dart';
import '../lib/gis/polygon_validator.dart';
import '../lib/gis/path_simplifier.dart';

void main() {
  group('Geodesic Calculator Tests', () {
    test('100m x 50m Deterministic Test Field Calibration (Requirement #55)', () {
      // 30° N, 78° E
      // 50m latitude difference
      const double lat0 = 30.0;
      const double lon0 = 78.0;
      const double dLat50m = 50.0 / 111132.95;
      final double dLon100m = 100.0 / (111132.95 * math.cos(30.0 * math.pi / 180.0));

      final testPolygon = [
        const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
        GeoPoint(latitude: lat0, longitude: lon0 + dLon100m, timestamp: 0),
        GeoPoint(latitude: lat0 + dLat50m, longitude: lon0 + dLon100m, timestamp: 0),
        GeoPoint(latitude: lat0 + dLat50m, longitude: lon0, timestamp: 0),
      ];

      final double area = GeodesicCalculator.areaSqMeters(testPolygon);
      final double perimeter = GeodesicCalculator.perimeterMeters(testPolygon);

      // Verify Area is ~5000 m² within 0.5% tolerance on WGS84 ellipsoid
      expect(area, greaterThan(4975.0));
      expect(area, lessThan(5025.0));

      // Verify Perimeter is ~300 m within 0.5% tolerance
      expect(perimeter, greaterThan(298.5));
      expect(perimeter, lessThan(301.5));
    });

    test('Self-Intersection Detection', () {
      // Bowtie / figure-8 crossing polygon
      final bowtie = [
        const GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0),
        const GeoPoint(latitude: 30.01, longitude: 78.01, timestamp: 0),
        const GeoPoint(latitude: 30.01, longitude: 78.0, timestamp: 0),
        const GeoPoint(latitude: 30.0, longitude: 78.01, timestamp: 0),
      ];

      expect(PolygonValidator.hasSelfIntersection(bowtie), isTrue);
      final val = PolygonValidator.validate(bowtie);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('crosses itself'));
    });

    test('Path Simplification (RDP) preserves vertices above tolerance', () {
      final line = [
        const GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0),
        const GeoPoint(latitude: 30.0000001, longitude: 78.00005, timestamp: 0), // micro jitter
        const GeoPoint(latitude: 30.0, longitude: 78.001, timestamp: 0),
      ];

      final simplified = PathSimplifier.simplifyPath(line, 1.0);
      expect(simplified.length, equals(2));
    });
  });
}
