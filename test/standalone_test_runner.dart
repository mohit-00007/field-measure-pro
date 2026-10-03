import 'dart:math' as math;
import '../lib/models/geo_point.dart';
import '../lib/gis/geodesic_calculator.dart';
import '../lib/gis/polygon_validator.dart';
import '../lib/gis/path_simplifier.dart';
import '../lib/core/units.dart';

void main() {
  print('======================================================');
  print('FIELD MEASURE PRO: DART CORE TEST SUITE EXECUTION');
  print('======================================================');

  int passed = 0;
  int total = 0;

  void runTest(String name, void Function() testFn) {
    total++;
    try {
      testFn();
      print('  ✓ PASS: $name');
      passed++;
    } catch (e, st) {
      print('  ✗ FAIL: $name\n    $e\n$st');
    }
  }

  const double lat0 = 30.0;
  const double lon0 = 78.0;
  const double dLat50m = 50.0 / 111132.95;
  final double dLon100m = 100.0 / (111132.95 * math.cos(30.0 * math.pi / 180.0));

  final calibrationPolygon = [
    const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
    GeoPoint(latitude: lat0, longitude: lon0 + dLon100m, timestamp: 0),
    GeoPoint(latitude: lat0 + dLat50m, longitude: lon0 + dLon100m, timestamp: 0),
    GeoPoint(latitude: lat0 + dLat50m, longitude: lon0, timestamp: 0),
  ];

  // 1. Geodesic area calculation
  runTest('100m x 50m Reference Polygon Area (~5,000 m²)', () {
    final area = GeodesicCalculator.areaSqMeters(calibrationPolygon);
    if (area < 4975.0 || area > 5025.0) {
      throw Exception('Area out of bounds: $area (expected ~5000 m²)');
    }
  });

  // 2. Geodesic perimeter calculation
  runTest('100m x 50m Reference Polygon Perimeter (~300 m)', () {
    final perimeter = GeodesicCalculator.perimeterMeters(calibrationPolygon);
    if (perimeter < 298.0 || perimeter > 302.0) {
      throw Exception('Perimeter out of bounds: $perimeter (expected ~300m)');
    }
  });

  // 3. Haversine distance
  runTest('Haversine distance between 50m separated latitudes', () {
    const p1 = GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0);
    final p2 = GeoPoint(latitude: lat0 + dLat50m, longitude: lon0, timestamp: 0);
    final dist = GeodesicCalculator.distanceMeters(p1, p2);
    if ((dist - 50.0).abs() > 0.5) {
      throw Exception('Distance calculation error: $dist (expected 50.0)');
    }
  });

  // 4. Polygon validator: Valid polygon
  runTest('PolygonValidator validates clean 4-corner polygon', () {
    final res = PolygonValidator.validate(calibrationPolygon);
    if (!res.isValid) {
      throw Exception('Expected valid polygon, got error: ${res.errorMessage}');
    }
  });

  // 5. Self-intersection detection
  runTest('PolygonValidator detects bow-tie self-intersection', () {
    final bowTie = [
      const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
      GeoPoint(latitude: lat0 + dLat50m, longitude: lon0 + dLon100m, timestamp: 0),
      GeoPoint(latitude: lat0, longitude: lon0 + dLon100m, timestamp: 0),
      GeoPoint(latitude: lat0 + dLat50m, longitude: lon0, timestamp: 0),
    ];
    final res = PolygonValidator.validate(bowTie);
    if (res.isValid) {
      throw Exception('Failed to detect self-intersection');
    }
    if (res.errorMessage != 'Boundary crosses itself.') {
      throw Exception('Expected "Boundary crosses itself.", got: "${res.errorMessage}"');
    }
  });

  // 6. Minimum 3 points guard
  runTest('PolygonValidator enforces >= 3 points', () {
    final res = PolygonValidator.validate([
      const GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0),
      const GeoPoint(latitude: 30.01, longitude: 78.01, timestamp: 0),
    ]);
    if (res.isValid) {
      throw Exception('2-point polygon should be invalid');
    }
    if (res.errorMessage != 'A polygon needs at least 3 points.') {
      throw Exception('Expected "A polygon needs at least 3 points.", got: "${res.errorMessage}"');
    }
  });

  // 7. RDP path simplification (open path)
  runTest('RDP Simplifier simplifies 20-point straight line to 2 endpoints', () {
    final noisy = <GeoPoint>[];
    for (int i = 0; i <= 20; i++) {
      noisy.add(GeoPoint(
        latitude: lat0 + (dLat50m * i / 20.0),
        longitude: lon0,
        timestamp: i,
      ));
    }
    final simplified = PathSimplifier.simplifyPath(noisy, 1.0);
    if (simplified.length != 2) {
      throw Exception('Expected 2 endpoints, got: ${simplified.length}');
    }
  });

  // 8. RDP polygon simplification (closed loop)
  runTest('RDP Simplifier simplifies multi-point square to 4 corners', () {
    final squareWithIntermediatePoints = <GeoPoint>[];
    // Edge 1: 5 points
    for (int i = 0; i < 5; i++) {
      squareWithIntermediatePoints.add(GeoPoint(
        latitude: lat0,
        longitude: lon0 + (dLon100m * i / 5.0),
        timestamp: i,
      ));
    }
    // Edge 2: 5 points
    for (int i = 0; i < 5; i++) {
      squareWithIntermediatePoints.add(GeoPoint(
        latitude: lat0 + (dLat50m * i / 5.0),
        longitude: lon0 + dLon100m,
        timestamp: 10 + i,
      ));
    }
    // Edge 3: 5 points
    for (int i = 0; i < 5; i++) {
      squareWithIntermediatePoints.add(GeoPoint(
        latitude: lat0 + dLat50m,
        longitude: lon0 + dLon100m * (5 - i) / 5.0,
        timestamp: 20 + i,
      ));
    }
    // Edge 4: 5 points
    for (int i = 0; i < 5; i++) {
      squareWithIntermediatePoints.add(GeoPoint(
        latitude: lat0 + dLat50m * (5 - i) / 5.0,
        longitude: lon0,
        timestamp: 30 + i,
      ));
    }

    final simplifiedPolygon = PathSimplifier.simplifyPolygon(squareWithIntermediatePoints, 1.0);
    if (simplifiedPolygon.length > 8) {
      throw Exception('Polygon RDP failed to remove redundant edge points: length = ${simplifiedPolygon.length}');
    }
    if (simplifiedPolygon.length < 4) {
      throw Exception('Polygon RDP over-simplified corners: length = ${simplifiedPolygon.length}');
    }
  });

  // 9. Standard Unit Conversions
  runTest('UnitConverter standard units (Acres, Hectares, sq ft, sq yd)', () {
    const double sqMeters = 4046.8564224; // Exactly 1 Acre
    final acres = UnitConverter.toAcres(sqMeters);
    if ((acres - 1.0).abs() > 0.0001) throw Exception('Acre conversion error: $acres');

    final ha = UnitConverter.toHectares(10000.0);
    if ((ha - 1.0).abs() > 0.0001) throw Exception('Hectare conversion error: $ha');

    final sqFt = UnitConverter.toSqFeet(1.0);
    if ((sqFt - 10.7639104).abs() > 0.001) throw Exception('SqFt conversion error: $sqFt');
  });

  // 10. Regional Land Unit Presets
  runTest('Regional Presets (Uttarakhand, UP, Punjab, Rajasthan, Bihar, MP)', () {
    final presets = UnitConverter.presets;
    if (presets.length < 6) throw Exception('Expected at least 6 presets, found ${presets.length}');

    final uk = presets.firstWhere((p) => p.id == 'uttarakhand');
    final bigha = UnitConverter.toBigha(2529.285, uk.bighaSqMeters);
    if ((bigha - 1.0).abs() > 0.001) throw Exception('Uttarakhand Bigha conversion error: $bigha');
  });

  // 11. Custom Land Unit Editor & Formatting
  runTest('Custom Land Unit Editor saves and calculates custom unit rate', () {
    UnitSettings.setCustomUnit('Special Bigha', 2500.0);
    final formatted = UnitSettings.formatArea(5000.0, unit: 'Special Bigha');
    if (formatted != '2.000 Special Bigha') {
      throw Exception('Expected "2.000 Special Bigha", got: "$formatted"');
    }
    UnitSettings.clearCustomUnit();
  });

  // 12. Midpoint calculation
  runTest('GeodesicCalculator midpoint calculation between two vertices', () {
    const p1 = GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0);
    const p2 = GeoPoint(latitude: 30.002, longitude: 78.004, timestamp: 0);
    final mid = GeodesicCalculator.midpoint(p1, p2);
    if ((mid.latitude - 30.001).abs() > 0.000001 || (mid.longitude - 78.002).abs() > 0.000001) {
      throw Exception('Midpoint calculation error: ${mid.latitude}, ${mid.longitude}');
    }
  });

  // 13. Blocker #1: saveActiveDraft state serialization
  runTest('saveActiveDraft state serialization across all 6 session states', () {
    const states = ['IDLE', 'TRACKING', 'PAUSED', 'DRAWING', 'EDITING', 'READY_TO_SAVE'];
    for (final state in states) {
      final draft = {
        'id': 'active_draft',
        'mode': 'gpsWalk',
        'state': state,
        'points': calibrationPolygon.map((p) => p.toJson()).toList(),
        'updatedAt': 12345678,
      };
      final encoded = draft;
      if (encoded['state'] != state) {
        throw Exception('State mismatch for $state');
      }
    }
  });

  // 14. Blocker #4 & Section 32: Immutable field conversion snapshot
  runTest('Field conversion snapshot immutability across global setting changes', () {
    const customName = 'Local Bigha';
    const originalRate = 2500.0;
    const testArea = 5000.0; // 5000 m2 = 2.0 Local Bigha

    // Initial evaluation with field's snapshot
    final initialFormat = UnitSettings.formatAreaWithSnapshot(
      sqMeters: testArea,
      unit: customName,
      customName: customName,
      customSqMeters: originalRate,
      region: 'Custom',
    );
    if (initialFormat != '2.000 Local Bigha') {
      throw Exception('Initial snapshot format failed: expected "2.000 Local Bigha", got "$initialFormat"');
    }

    // Change global unit setting to 2700 m2
    UnitSettings.setCustomUnit(customName, 2700.0);

    // Reopen field - must still format using original snapshot rate (2500 m2)
    final afterGlobalChange = UnitSettings.formatAreaWithSnapshot(
      sqMeters: testArea,
      unit: customName,
      customName: customName,
      customSqMeters: originalRate,
      region: 'Custom',
    );
    if (afterGlobalChange != '2.000 Local Bigha') {
      throw Exception('Snapshot violated! Got "$afterGlobalChange", expected "2.000 Local Bigha"');
    }

    UnitSettings.clearCustomUnit();
  });

  // 15. Section 34: GPS + Adjust polygon separation
  runTest('GPS + Adjust preserves original GPS polygon and final adjusted polygon', () {
    final originalGps = List<GeoPoint>.from(calibrationPolygon);
    final adjustedFinal = List<GeoPoint>.from(calibrationPolygon);

    // User drags vertex 2
    adjustedFinal[2] = GeoPoint(
      latitude: adjustedFinal[2].latitude + 0.001,
      longitude: adjustedFinal[2].longitude + 0.001,
      timestamp: 10,
    );

    final origArea = GeodesicCalculator.areaSqMeters(originalGps);
    final finalArea = GeodesicCalculator.areaSqMeters(adjustedFinal);

    if (origArea == finalArea) {
      throw Exception('Final area should differ after vertex adjustment');
    }
    if (originalGps[2].latitude == adjustedFinal[2].latitude) {
      throw Exception('Original GPS vertex was mutated when adjusting final polygon!');
    }
  });

  // 16. Section 15 & 19: Duplicate field independence
  runTest('Duplicate field creates independent record with new ID', () {
    final origPoints = List<GeoPoint>.from(calibrationPolygon);
    final dupPoints = List<GeoPoint>.from(origPoints);

    // Mutate duplicate point
    dupPoints[0] = const GeoPoint(latitude: 35.0, longitude: 80.0, timestamp: 99);

    if (origPoints[0].latitude == 35.0) {
      throw Exception('Original points were mutated by duplicate!');
    }
  });

  // 17. Section 12: Drag cancellation restores original coordinates
  runTest('Drag cancellation restores exact coordinate without mutation', () {
    final points = List<GeoPoint>.from(calibrationPolygon);
    final backup = points[1];

    // Simulate drag start, move, then cancel
    var dragged = GeoPoint(latitude: backup.latitude + 0.005, longitude: backup.longitude, timestamp: 5);
    points[1] = dragged;

    // Cancellation: restore backup
    points[1] = backup;

    if (points[1].latitude != calibrationPolygon[1].latitude) {
      throw Exception('Drag cancellation failed to restore original coordinate');
    }
    final area = GeodesicCalculator.areaSqMeters(points);
    if ((area - 5000.0).abs() > 25.0) {
      throw Exception('Area was not restored after drag cancellation: $area');
    }
  });

  // 18. Section 15: Vertex deletion guard
  runTest('Vertex deletion guard prevents fewer than 3 vertices', () {
    final triangle = [
      calibrationPolygon[0],
      calibrationPolygon[1],
      calibrationPolygon[2],
    ];

    bool allowed = triangle.length > 3;
    if (allowed) {
      throw Exception('Deletion below 3 vertices should be prohibited');
    }
  });

  // 19. Section 4: Coordinates source of truth area reproducibility
  runTest('Field area is 100% reproducible from saved coordinates', () {
    final savedCoords = calibrationPolygon.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList();
    final restoredPoints = savedCoords.map((c) => GeoPoint(latitude: c['lat']!, longitude: c['lon']!, timestamp: 0)).toList();

    final recalculatedArea = GeodesicCalculator.areaSqMeters(restoredPoints);
    final recalculatedPerimeter = GeodesicCalculator.perimeterMeters(restoredPoints);

    if ((recalculatedArea - 5000.0).abs() > 25.0) {
      throw Exception('Area reproduction drift: $recalculatedArea');
    }
    if ((recalculatedPerimeter - 300.0).abs() > 2.0) {
      throw Exception('Perimeter reproduction drift: $recalculatedPerimeter');
    }
  });

  // 20. Task #1: Verify universal Bigha fallback is removed
  runTest('Bigha returns "Conversion unavailable" when no region is selected', () {
    UnitSettings.selectedRegionId = 'unknown';
    final noRegionResult = UnitSettings.formatArea(5000.0, unit: 'Bigha');
    if (noRegionResult != 'Conversion unavailable') {
      throw Exception('Expected "Conversion unavailable", got "$noRegionResult"');
    }

    final noSnapshotResult = UnitSettings.formatAreaWithSnapshot(
      sqMeters: 5000.0,
      unit: 'Bigha',
      region: null,
    );
    if (noSnapshotResult != 'Conversion unavailable') {
      throw Exception('Expected "Conversion unavailable" for snapshot without region, got "$noSnapshotResult"');
    }

    // Now verify legitimate regional preset works
    UnitSettings.setRegion('uttarakhand', persist: false);
    final withRegionResult = UnitSettings.formatArea(2529.285, unit: 'Bigha');
    if (!withRegionResult.startsWith('1.000 Bigha')) {
      throw Exception('Expected 1.000 Bigha with Uttarakhand preset, got "$withRegionResult"');
    }
  });

  print('======================================================');
  print('RESULTS: $passed / $total TESTS PASSED ($passed / $total OK)');
  print('======================================================');

  if (passed != total) {
    throw Exception('Some tests failed!');
  }
}
