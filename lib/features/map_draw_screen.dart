import 'package:flutter/material.dart';
import '../models/geo_point.dart';
import '../models/field_model.dart';
import '../map/field_map_view.dart';
import '../gis/geodesic_calculator.dart';
import '../core/units.dart';
import '../database/app_database.dart';
import 'boundary_editor_screen.dart';

enum ManualDrawType { freehand, pointByPoint }

class MapDrawScreen extends StatefulWidget {
  const MapDrawScreen({super.key});

  @override
  State<MapDrawScreen> createState() => _MapDrawScreenState();
}

class _MapDrawScreenState extends State<MapDrawScreen> {
  ManualDrawType _drawType = ManualDrawType.freehand;
  bool _isFreehandDrawActive = true; // Toggle between Draw and Pan/Zoom (Section 15)
  List<GeoPoint> _points = [];

  void _onDrawingFinished(List<GeoPoint> points) {
    setState(() {
      _points = points;
    });

    // Save active draft
    AppDatabase.saveActiveDraft(
      id: 'active_draft',
      mode: MeasurementMode.mapDraw.name,
      state: 'DRAWING',
      points: points,
    );

    // Prompt confirmation sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final double area = GeodesicCalculator.areaSqMeters(points);
        final double perimeter = GeodesicCalculator.perimeterMeters(points);

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'BOUNDARY CREATED',
                style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Recorded ${points.length} boundary points with RDP simplification.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated Area: ${UnitSettings.formatArea(area)}  ·  Perimeter: ${UnitSettings.formatPerimeter(perimeter)}',
                style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        AppDatabase.clearActiveDraft();
                        setState(() {
                          _points.clear();
                        });
                      },
                      child: const Text('REDRAW'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BoundaryEditorScreen(
                              initialPoints: points,
                              mode: MeasurementMode.mapDraw,
                            ),
                          ),
                        );
                      },
                      child: const Text('ACCEPT & EDIT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onMapTapPoint(GeoPoint point) {
    if (_drawType != ManualDrawType.pointByPoint) return;
    setState(() {
      _points.add(point);
    });

    AppDatabase.saveActiveDraft(
      id: 'active_draft',
      mode: MeasurementMode.mapDraw.name,
      state: 'DRAWING',
      points: _points,
    );
  }

  void _undoPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
      AppDatabase.saveActiveDraft(
        id: 'active_draft',
        mode: MeasurementMode.mapDraw.name,
        state: 'DRAWING',
        points: _points,
      );
    }
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
    });
    AppDatabase.clearActiveDraft();
  }

  void _finishPointByPoint() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 3 points are required to form a closed field.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BoundaryEditorScreen(
          initialPoints: _points,
          mode: MeasurementMode.mapDraw,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MapInteractionMode interactionMode;
    if (_drawType == ManualDrawType.pointByPoint) {
      interactionMode = MapInteractionMode.pointByPoint;
    } else {
      interactionMode = _isFreehandDrawActive
          ? MapInteractionMode.drawing
          : MapInteractionMode.normal;
    }

    final double currentPerimeter = _points.length >= 2
        ? (_points.length >= 3
            ? GeodesicCalculator.perimeterMeters(_points)
            : GeodesicCalculator.pathLengthMeters(_points))
        : 0.0;

    final double currentArea = _points.length >= 3
        ? GeodesicCalculator.areaSqMeters(_points)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('DRAW ON MAP',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          // Clear button in point-by-point mode
          if (_drawType == ManualDrawType.pointByPoint && _points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear Points',
              onPressed: _clearPoints,
            ),
        ],
      ),
      body: Stack(
        children: [
          FieldMapView(
            points: _points,
            mode: interactionMode,
            customModeTitle: _drawType == ManualDrawType.pointByPoint
                ? 'POINT-BY-POINT TAP'
                : (_isFreehandDrawActive ? 'FREEHAND TRACE' : 'PAN & ZOOM'),
            onDrawingFinished: _onDrawingFinished,
            onMapTapPoint: _onMapTapPoint,
          ),

          // Top Mode Switcher Bar (Section 13)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xF20F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _drawType = ManualDrawType.freehand;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _drawType == ManualDrawType.freehand
                              ? const Color(0xFF16A34A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gesture, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('FREEHAND DRAW',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _drawType = ManualDrawType.pointByPoint;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _drawType == ManualDrawType.pointByPoint
                              ? const Color(0xFF16A34A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.place, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('POINT-BY-POINT',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions Banner & Mode Controls
          if (_drawType == ManualDrawType.freehand)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xF20F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFreehandDrawActive ? Icons.touch_app : Icons.pan_tool,
                      color: const Color(0xFF4ADE80),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isFreehandDrawActive
                            ? 'Draw field perimeter in one smooth stroke.'
                            : 'Pan & zoom to position map, then switch back to Draw.',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Draw / Pan toggle (Section 15)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: _isFreehandDrawActive
                            ? const Color(0xFF4ADE80)
                            : Colors.amberAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFreehandDrawActive = !_isFreehandDrawActive;
                        });
                      },
                      icon: Icon(
                        _isFreehandDrawActive ? Icons.pan_tool : Icons.edit,
                        size: 14,
                      ),
                      label: Text(
                        _isFreehandDrawActive ? 'PAN MAP' : 'DRAW',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Bar for Point-by-Point Mode
          if (_drawType == ManualDrawType.pointByPoint)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xF20F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POINTS PLACED: ${_points.length}',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _points.length >= 3
                                  ? UnitSettings.formatArea(currentArea)
                                  : 'Tap map to add corners',
                              style: const TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (_points.length >= 2)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PERIMETER',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                UnitSettings.formatPerimeter(currentPerimeter),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF475569)),
                            ),
                            onPressed: _points.isNotEmpty ? _undoPoint : null,
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('UNDO POINT'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _points.length >= 3
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _points.length >= 3 ? _finishPointByPoint : null,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('FINISH POLYGON',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
