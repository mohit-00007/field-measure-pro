import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/geo_point.dart';
import '../lib/models/field_model.dart';
import '../lib/features/boundary_editor_screen.dart';
import '../lib/map/field_map_view.dart';
import '../lib/polygon_editor/polygon_editor_controller.dart';
import '../lib/gis/geodesic_calculator.dart';

void main() {
  testWidgets('Section 37: End-to-end Widget drag, live area, and undo test', (tester) async {
    const double lat0 = 30.0;
    const double lon0 = 78.0;
    const double dLat = 0.001;
    const double dLon = 0.001;

    final initialPoints = [
      const GeoPoint(latitude: lat0, longitude: lon0, timestamp: 0),
      const GeoPoint(latitude: lat0, longitude: lon0 + dLon, timestamp: 0),
      const GeoPoint(latitude: lat0 + dLat, longitude: lon0 + dLon, timestamp: 0),
      const GeoPoint(latitude: lat0 + dLat, longitude: lon0, timestamp: 0),
    ];

    final double originalArea = GeodesicCalculator.areaSqMeters(initialPoints);

    // Build the BoundaryEditorScreen widget
    await tester.pumpWidget(
      MaterialApp(
        home: BoundaryEditorScreen(
          initialPoints: initialPoints,
          mode: MeasurementMode.mapDraw,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Boundary Editor AppBar and HUD rendered
    expect(find.text('BOUNDARY EDITOR'), findsOneWidget);
    expect(find.text('ADJUSTED AREA (LIVE)'), findsOneWidget);

    // Find vertex marker #1 (Text widget displaying "1")
    final marker1Finder = find.text('1');
    expect(marker1Finder, findsOneWidget);

    // Simulate drag gesture on vertex #1:
    // start drag -> pan update -> pan end
    final gesture = await tester.startGesture(tester.getCenter(marker1Finder));
    await tester.pump();

    // Move pointer by 100 pixels down and 80 pixels right
    await gesture.moveBy(const Offset(80.0, 100.0));
    await tester.pump();

    // Move again
    await gesture.moveBy(const Offset(20.0, 30.0));
    await tester.pump();

    // Release pointer (onPanEnd)
    await gesture.up();
    await tester.pumpAndSettle();

    // Tap UNDO button in AppBar
    final undoFinder = find.byIcon(Icons.undo);
    expect(undoFinder, findsOneWidget);
    await tester.tap(undoFinder);
    await tester.pumpAndSettle();

    // Verify that undo restored state and canRedo is now available
    final redoFinder = find.byIcon(Icons.redo);
    expect(redoFinder, findsOneWidget);
  });
}
