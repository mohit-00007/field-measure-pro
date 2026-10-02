import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/geo_point.dart';
import '../lib/models/field_model.dart';
import '../lib/polygon_editor/polygon_editor_controller.dart';
import '../lib/gis/geodesic_calculator.dart';
import '../lib/gis/polygon_validator.dart';

void main() {
  group('Critical Boundary Editor Tests (TEST 1 to TEST 8)', () {
    const double lat0 = 30.0;
    const double lon0 = 78.0;
    const double dLat = 0.001; // ~111m
    const double dLon = 0.001; // ~96m

    List<GeoPoint> createSquarePolygon() {
      return [
        const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
        const GeoPoint(latitude: lat0, longitude: lon0 + dLon, timestamp: 0),
        const GeoPoint(latitude: lat0 + dLat, longitude: lon0 + dLon, timestamp: 0),
        const GeoPoint(latitude: lat0 + dLat, longitude: lon0, timestamp: 0),
      ];
    }

    // TEST 1: Create polygon. Move vertex. Verify controller point changed.
    test('TEST 1: Move vertex updates PolygonEditorController.points', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);

      expect(controller.points[2].latitude, equals(lat0 + dLat));
      expect(controller.points[2].longitude, equals(lon0 + dLon));

      controller.beginMovingVertex(2);
      const newPoint = GeoPoint(latitude: lat0 + dLat * 1.5, longitude: lon0 + dLon * 1.5, timestamp: 1);
      controller.moveVertex(2, newPoint);

      // Verify controller point changed immediately
      expect(controller.points[2].latitude, equals(lat0 + dLat * 1.5));
      expect(controller.points[2].longitude, equals(lon0 + dLon * 1.5));

      controller.finishMovingVertex();
      expect(controller.points[2].latitude, equals(lat0 + dLat * 1.5));
    });

    // TEST 2: Move vertex. Verify area changed.
    test('TEST 2: Move vertex causes liveAreaSqMeters to update live', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);

      final double initialArea = controller.liveAreaSqMeters;
      expect(initialArea, greaterThan(0.0));

      // Move vertex 2 outward
      controller.beginMovingVertex(2);
      final expandedPoint = GeoPoint(latitude: lat0 + dLat * 2.0, longitude: lon0 + dLon * 2.0, timestamp: 1);
      controller.moveVertex(2, expandedPoint);

      final double liveAreaDuringDrag = controller.liveAreaSqMeters;
      expect(liveAreaDuringDrag, greaterThan(initialArea));

      controller.finishMovingVertex();
      expect(controller.liveAreaSqMeters, equals(liveAreaDuringDrag));
    });

    // TEST 3: Move vertex. Finish drag. Undo. Verify exact original coordinate restored.
    test('TEST 3: Finish drag then undo restores exact original coordinate', () {
      final initial = createSquarePolygon();
      final originalV1 = initial[1];
      final controller = PolygonEditorController(initialPoints: initial);

      // Perform multiple moveVertex events inside ONE drag gesture
      controller.beginMovingVertex(1);
      controller.moveVertex(1, GeoPoint(latitude: lat0, longitude: lon0 + dLon + 0.0001, timestamp: 10));
      controller.moveVertex(1, GeoPoint(latitude: lat0, longitude: lon0 + dLon + 0.0002, timestamp: 20));
      controller.moveVertex(1, GeoPoint(latitude: lat0, longitude: lon0 + dLon + 0.0005, timestamp: 30));
      controller.finishMovingVertex();

      expect(controller.points[1].longitude, equals(lon0 + dLon + 0.0005));

      // Undo: exactly ONE undo operation should restore the pre-drag position
      expect(controller.canUndo, isTrue);
      controller.undo();

      expect(controller.points[1].latitude, equals(originalV1.latitude));
      expect(controller.points[1].longitude, equals(originalV1.longitude));
    });

    // TEST 4: Undo. Redo. Verify moved coordinate restored.
    test('TEST 4: Redo restores the moved coordinate and area', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);

      controller.beginMovingVertex(3);
      final moved = GeoPoint(latitude: lat0 + dLat + 0.0005, longitude: lon0 - 0.0005, timestamp: 1);
      controller.moveVertex(3, moved);
      controller.finishMovingVertex();

      final double areaAfterMove = controller.liveAreaSqMeters;

      // Undo
      controller.undo();
      expect(controller.points[3].latitude, equals(lat0 + dLat));

      // Redo
      expect(controller.canRedo, isTrue);
      controller.redo();
      expect(controller.points[3].latitude, equals(moved.latitude));
      expect(controller.points[3].longitude, equals(moved.longitude));
      expect(controller.liveAreaSqMeters, closeTo(areaAfterMove, 0.001));
    });

    // TEST 5: Insert midpoint. Verify point count increases by 1.
    test('TEST 5: Insert midpoint increases point count by 1 and is draggable', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);
      expect(controller.points.length, equals(4));

      final mid = GeodesicCalculator.midpoint(initial[0], initial[1]);
      controller.insertVertexAt(1, mid);

      expect(controller.points.length, equals(5));
      expect(controller.points[1].latitude, equals(mid.latitude));
      expect(controller.points[1].longitude, equals(mid.longitude));
      expect(controller.selectedVertexIndex, equals(1));

      // Newly inserted midpoint must immediately be draggable
      controller.beginMovingVertex(1);
      final newPos = GeoPoint(latitude: mid.latitude - 0.0002, longitude: mid.longitude, timestamp: 2);
      controller.moveVertex(1, newPos);
      controller.finishMovingVertex();

      expect(controller.points[1].latitude, equals(newPos.latitude));
    });

    // TEST 6: Delete point. Verify point count decreases by 1.
    test('TEST 6: Delete point decreases point count by 1', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);
      expect(controller.points.length, equals(4));

      final bool deleted = controller.deleteVertexAt(1);
      expect(deleted, isTrue);
      expect(controller.points.length, equals(3));
    });

    // TEST 7: Attempt delete when 3 points remain. Verify deletion rejected.
    test('TEST 7: Attempt delete when 3 points remain is rejected', () {
      final triangle = [
        const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
        const GeoPoint(latitude: lat0, longitude: lon0 + dLon, timestamp: 0),
        const GeoPoint(latitude: lat0 + dLat, longitude: lon0, timestamp: 0),
      ];
      final controller = PolygonEditorController(initialPoints: triangle);
      expect(controller.points.length, equals(3));

      controller.selectVertex(0);
      final bool deleted = controller.deleteSelectedVertex();

      expect(deleted, isFalse);
      expect(controller.points.length, equals(3));
      expect(controller.validationError, equals('At least 3 boundary points are required.'));
    });

    // TEST 8: Move vertex to create self-intersection. Verify validation catches it.
    test('TEST 8: Move vertex creating self-intersection is caught by validation', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);
      expect(controller.isValid, isTrue);

      // Drag vertex 0 across vertex 2 diagonally to form a bow-tie shape (self-intersecting)
      controller.beginMovingVertex(0);
      final crossed = GeoPoint(latitude: lat0 + dLat * 1.5, longitude: lon0 + dLon * 1.5, timestamp: 1);
      controller.moveVertex(0, crossed);

      expect(controller.isValid, isFalse);
      expect(controller.validationError, equals('Boundary crosses itself.'));

      // Undo or move back restores valid status
      controller.finishMovingVertex();
      controller.undo();
      expect(controller.isValid, isTrue);
      expect(controller.validationError, isNull);
    });

    // Section 14: Multiple Drags undo/redo test
    test('Multiple independent drags create separate undo history entries', () {
      final initial = createSquarePolygon();
      final controller = PolygonEditorController(initialPoints: initial);

      // Drag vertex 1
      controller.beginMovingVertex(1);
      controller.moveVertex(1, GeoPoint(latitude: lat0 - 0.0001, longitude: lon0 + dLon, timestamp: 1));
      controller.finishMovingVertex();

      // Drag vertex 2
      controller.beginMovingVertex(2);
      controller.moveVertex(2, GeoPoint(latitude: lat0 + dLat + 0.0001, longitude: lon0 + dLon, timestamp: 2));
      controller.finishMovingVertex();

      // Drag vertex 3
      controller.beginMovingVertex(3);
      controller.moveVertex(3, GeoPoint(latitude: lat0 + dLat + 0.0002, longitude: lon0, timestamp: 3));
      controller.finishMovingVertex();

      // First undo: reverts vertex 3 only
      controller.undo();
      expect(controller.points[3].latitude, equals(lat0 + dLat));
      expect(controller.points[2].latitude, equals(lat0 + dLat + 0.0001));
      expect(controller.points[1].latitude, equals(lat0 - 0.0001));

      // Second undo: reverts vertex 2 only
      controller.undo();
      expect(controller.points[2].latitude, equals(lat0 + dLat));
      expect(controller.points[1].latitude, equals(lat0 - 0.0001));

      // Third undo: reverts vertex 1 only
      controller.undo();
      expect(controller.points[1].latitude, equals(lat0));
    });
  });

  group('GPS + Adjust Separation Test (Section 39)', () {
    test('Original GPS polygon remains unchanged when final polygon is adjusted', () {
      const double lat0 = 30.0;
      const double lon0 = 78.0;
      final originalGps = [
        const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
        const GeoPoint(latitude: lat0, longitude: lon0 + 0.001, timestamp: 0),
        const GeoPoint(latitude: lat0 + 0.001, longitude: lon0 + 0.001, timestamp: 0),
        const GeoPoint(latitude: lat0 + 0.001, longitude: lon0, timestamp: 0),
      ];

      final double originalGpsArea = GeodesicCalculator.areaSqMeters(originalGps);

      // Load into editor
      final editor = PolygonEditorController(initialPoints: originalGps);

      // User drags vertex 2
      editor.beginMovingVertex(2);
      editor.moveVertex(2, const GeoPoint(latitude: lat0 + 0.002, longitude: lon0 + 0.002, timestamp: 1));
      editor.finishMovingVertex();

      final double finalArea = editor.liveAreaSqMeters;

      // Verify original GPS polygon is completely unchanged
      expect(originalGps[2].latitude, equals(lat0 + 0.001));
      expect(GeodesicCalculator.areaSqMeters(originalGps), equals(originalGpsArea));

      // Verify final polygon is changed
      expect(editor.points[2].latitude, equals(lat0 + 0.002));
      expect(finalArea, greaterThan(originalGpsArea));
    });
  });
}
