import 'package:flutter/foundation.dart';
import '../models/geo_point.dart';
import '../gis/geodesic_calculator.dart';
import '../gis/polygon_validator.dart';
import '../gis/path_simplifier.dart';

/// Authoritative PolygonEditorController.
///
/// Responsibilities:
/// - Sole source of truth for the edited polygon (`points`).
/// - Live area and perimeter calculation during vertex drags.
/// - Explicit drag lifecycle: `beginMovingVertex`, `moveVertex`, `finishMovingVertex`.
/// - Exactly ONE undo history entry per complete drag gesture.
/// - Midpoint insertion and vertex deletion with minimum-3-point safety guard.
/// - Real-time self-intersection and coordinate validation.
class PolygonEditorController extends ChangeNotifier {
  List<GeoPoint> _points;
  final List<List<GeoPoint>> _history = [];
  int _historyIndex = 0;

  int? _selectedVertexIndex;
  int? _activeDragIndex;
  bool _isDragging = false;
  List<GeoPoint>? _dragStartSnapshot;
  String? _validationError;

  PolygonEditorController({required List<GeoPoint> initialPoints})
      : _points = List.from(initialPoints) {
    _history.add(List.from(_points));
    _validateCurrent();
  }

  /// Authoritative edited polygon points
  List<GeoPoint> get points => List.unmodifiable(_points);

  /// Index of currently selected vertex (if any)
  int? get selectedVertexIndex => _selectedVertexIndex;

  /// Index of vertex actively being dragged (if any)
  int? get activeDragIndex => _activeDragIndex;

  /// Whether a drag gesture is currently underway
  bool get isDragging => _isDragging;

  /// Real-time validation error (e.g., self-intersection)
  String? get validationError => _validationError;

  /// True if polygon has at least 3 points and no self-intersections
  bool get isValid => _validationError == null && _points.length >= 3;

  /// Undo / Redo availability
  bool get canUndo => _historyIndex > 0 && !_isDragging;
  bool get canRedo => _historyIndex < _history.length - 1 && !_isDragging;

  /// Live Geodesic Area in square meters (recalculated on every move tick)
  double get liveAreaSqMeters =>
      _points.length >= 3 ? GeodesicCalculator.areaSqMeters(_points) : 0.0;

  /// Live Geodesic Perimeter in meters (recalculated on every move tick)
  double get livePerimeterMeters =>
      _points.length >= 3 ? GeodesicCalculator.perimeterMeters(_points) : 0.0;

  /// Select a vertex
  void selectVertex(int? index) {
    _selectedVertexIndex = index;
    notifyListeners();
  }

  /// Begin moving a vertex.
  /// Records the pre-drag snapshot for undo history and active drag state.
  /// Does NOT push history yet — prevents generating 100 history entries during drag.
  void beginMovingVertex(int index) {
    if (index < 0 || index >= _points.length) return;
    _activeDragIndex = index;
    _selectedVertexIndex = index;
    _isDragging = true;
    _dragStartSnapshot = List.from(_points);
    notifyListeners();
  }

  /// Move vertex to a new geographic position during drag gesture.
  /// Immediately updates polygon, recalculates live area & perimeter, validates.
  void moveVertex(int index, GeoPoint newPoint) {
    if (index < 0 || index >= _points.length) return;
    _points[index] = newPoint;
    _validateCurrent();
    notifyListeners();
  }

  /// Finish moving vertex when pointer / finger releases.
  /// Creates exactly ONE history entry for the entire drag gesture.
  void finishMovingVertex([int? index, GeoPoint? finalPoint]) {
    if (index != null && finalPoint != null && index >= 0 && index < _points.length) {
      _points[index] = finalPoint;
    }

    _isDragging = false;
    _activeDragIndex = null;

    // Check if points actually changed from pre-drag snapshot
    if (_dragStartSnapshot != null && !_arePointListsEqual(_dragStartSnapshot!, _points)) {
      _pushHistory();
    }
    _dragStartSnapshot = null;

    _validateCurrent();
    notifyListeners();
  }

  /// Cancel an in-progress drag and revert to the pre-drag snapshot
  void cancelMovingVertex() {
    if (_isDragging && _dragStartSnapshot != null) {
      _points = List.from(_dragStartSnapshot!);
      _isDragging = false;
      _activeDragIndex = null;
      _dragStartSnapshot = null;
      _validateCurrent();
      notifyListeners();
    }
  }

  /// Insert a midpoint or new vertex at a specific index.
  /// Immediately becomes part of the authoritative polygon.
  void insertVertexAt(int index, GeoPoint point) {
    if (index < 0 || index > _points.length) return;
    _points.insert(index, point);
    _selectedVertexIndex = index;
    _pushHistory();
  }

  /// Delete vertex at specific index.
  /// Guard: Enforces minimum of 3 boundary points.
  bool deleteVertexAt(int index) {
    if (index < 0 || index >= _points.length) return false;

    if (_points.length <= 3) {
      _validationError = 'At least 3 boundary points are required.';
      notifyListeners();
      return false;
    }

    _points.removeAt(index);
    _selectedVertexIndex = null;
    _pushHistory();
    return true;
  }

  /// Delete currently selected vertex.
  bool deleteSelectedVertex() {
    if (_selectedVertexIndex == null) return false;
    return deleteVertexAt(_selectedVertexIndex!);
  }

  /// Set points directly (e.g. from Drawing or GPS import)
  void setPoints(List<GeoPoint> newPoints) {
    _points = List.from(newPoints);
    _selectedVertexIndex = null;
    _activeDragIndex = null;
    _isDragging = false;
    _pushHistory();
  }

  /// Simplify boundary using RDP
  void simplifyBoundary(double toleranceMeters) {
    final simplified = PathSimplifier.simplifyPolygon(_points, toleranceMeters);
    if (simplified.length >= 3) {
      _points = simplified;
      _selectedVertexIndex = null;
      _pushHistory();
    }
  }

  /// Undo last change (drag, insert, delete)
  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    _points = List.from(_history[_historyIndex]);
    _selectedVertexIndex = null;
    _activeDragIndex = null;
    _isDragging = false;
    _validateCurrent();
    notifyListeners();
  }

  /// Redo previously undone change
  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    _points = List.from(_history[_historyIndex]);
    _selectedVertexIndex = null;
    _activeDragIndex = null;
    _isDragging = false;
    _validateCurrent();
    notifyListeners();
  }

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.from(_points));
    _historyIndex = _history.length - 1;
    _validateCurrent();
    notifyListeners();
  }

  void _validateCurrent() {
    final val = PolygonValidator.validate(_points);
    _validationError = val.isValid ? null : val.errorMessage;
  }

  bool _arePointListsEqual(List<GeoPoint> a, List<GeoPoint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }
}
