import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/geo_point.dart';
import '../lib/drawing/freehand_drawing_controller.dart';
import '../lib/polygon_editor/polygon_editor_controller.dart';
import '../lib/gis/geodesic_calculator.dart';
import '../lib/gis/path_simplifier.dart';
import '../lib/gis/polygon_validator.dart';

void main() {
  group('Touch Drawing Tests & Section 38', () {
    test('Simulate finger path P1 -> P2 -> P3 -> P4 -> P1 to Boundary Editor', () {
      final drawingController = FreehandDrawingController();
      drawingController.startDrawing();

      // P1, P2, P3, P4 closed loop
      const p1 = GeoPoint(latitude: 30.000, longitude: 78.000, timestamp: 0);
      const p2 = GeoPoint(latitude: 30.000, longitude: 78.001, timestamp: 100);
      const p3 = GeoPoint(latitude: 30.001, longitude: 78.001, timestamp: 200);
      const p4 = GeoPoint(latitude: 30.001, longitude: 78.000, timestamp: 300);

      // Interpolate points along the path
      final fingerPath = [
        p1,
        const GeoPoint(latitude: 30.000, longitude: 78.0005, timestamp: 50),
        p2,
        const GeoPoint(latitude: 30.0005, longitude: 78.001, timestamp: 150),
        p3,
        const GeoPoint(latitude: 30.001, longitude: 78.0005, timestamp: 250),
        p4,
        const GeoPoint(latitude: 30.0005, longitude: 78.000, timestamp: 350),
        p1,
      ];

      for (final pt in fingerPath) {
        drawingController.addGeographicPoint(pt);
      }

      final simplified = drawingController.finishDrawing(toleranceMeters: 1.0);

      // Verify polygon created
      expect(simplified, isNotNull);
      // Verify at least 3 points
      expect(simplified!.length, greaterThanOrEqualTo(3));
      // Verify area > 0
      final double area = GeodesicCalculator.areaSqMeters(simplified);
      expect(area, greaterThan(0.0));

      // Verify Boundary Editor receives exactly this polygon
      final editorController = PolygonEditorController(initialPoints: simplified);
      expect(editorController.points.length, equals(simplified.length));
      expect(editorController.liveAreaSqMeters, closeTo(area, 0.001));
    });

    test('Rejection of fewer than 5 raw touch coordinates', () {
      final controller = FreehandDrawingController();
      controller.startDrawing();
      controller.addGeographicPoint(const GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0));
      controller.addGeographicPoint(const GeoPoint(latitude: 30.01, longitude: 78.01, timestamp: 10));

      final result = controller.finishDrawing();
      expect(result, isNull);
    });
  });

  group('Polygon Editor Controller Lifecycle', () {
    test('Vertex move, live area update, and single-step undo/redo', () {
      const double lat0 = 30.0;
      const double lon0 = 78.0;
      const double dLat50m = 50.0 / 111132.95;
      final double dLon100m = 100.0 / (111132.95 * math.cos(30.0 * math.pi / 180.0));

      final initialPoints = [
        const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
        GeoPoint(latitude: lat0, longitude: lon0 + dLon100m, timestamp: 0),
        GeoPoint(latitude: lat0 + dLat50m, longitude: lon0 + dLon100m, timestamp: 0),
        GeoPoint(latitude: lat0 + dLat50m, longitude: lon0, timestamp: 0),
      ];

      final editor = PolygonEditorController(initialPoints: initialPoints);
      final double originalArea = editor.liveAreaSqMeters;
      expect(originalArea, closeTo(5000.0, 30.0));

      // Drag vertex 2 northward
      final movedPoint = GeoPoint(
        latitude: lat0 + dLat50m * 2,
        longitude: lon0 + dLon100m,
        timestamp: 1000,
      );
      editor.beginMovingVertex(2);
      editor.moveVertex(2, movedPoint);
      editor.finishMovingVertex();

      final double newArea = editor.liveAreaSqMeters;
      expect(newArea, greaterThan(originalArea));

      // Undo
      editor.undo();
      expect(editor.liveAreaSqMeters, closeTo(originalArea, 1.0));

      // Redo
      editor.redo();
      expect(editor.liveAreaSqMeters, closeTo(newArea, 1.0));
    });

    test('Insert vertex via midpoint handle and delete vertex guard', () {
      final initialPoints = [
        const GeoPoint(latitude: 30.0, longitude: 78.0, timestamp: 0),
        const GeoPoint(latitude: 30.0, longitude: 78.001, timestamp: 0),
        const GeoPoint(latitude: 30.001, longitude: 78.0, timestamp: 0),
      ];

      final editor = PolygonEditorController(initialPoints: initialPoints);
      expect(editor.points.length, equals(3));

      // Insert midpoint
      final mid = GeodesicCalculator.midpoint(initialPoints[0], initialPoints[1]);
      editor.insertVertexAt(1, mid);
      expect(editor.points.length, equals(4));

      // Delete point 1
      editor.selectVertex(1);
      final deleted = editor.deleteSelectedVertex();
      expect(deleted, isTrue);
      expect(editor.points.length, equals(3));

      // Guard: Attempting to delete when only 3 points remain must be rejected
      editor.selectVertex(0);
      final deletedAgain = editor.deleteSelectedVertex();
      expect(deletedAgain, isFalse);
      expect(editor.points.length, equals(3));
      expect(editor.validationError, equals('At least 3 boundary points are required.'));
    });
  });
}
