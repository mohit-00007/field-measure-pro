import 'package:flutter/foundation.dart';
import '../models/geo_point.dart';
import '../gis/path_simplifier.dart';
import '../gis/polygon_validator.dart';

/// FreehandDrawingController as required by Section 42.
/// Responsibilities: start drawing, collect screen coordinates,
/// convert screen coordinates to geographic coordinates, simplify path,
/// remove duplicate points, close polygon, validate polygon, send polygon to geometry engine.
class FreehandDrawingController extends ChangeNotifier {
  final List<GeoPoint> _rawPoints = [];
  bool _isDrawing = false;

  bool get isDrawing => _isDrawing;
  List<GeoPoint> get rawPoints => List.unmodifiable(_rawPoints);

  void startDrawing() {
    _rawPoints.clear();
    _isDrawing = true;
    notifyListeners();
  }

  void addGeographicPoint(GeoPoint point) {
    if (!_isDrawing) return;
    _rawPoints.add(point);
    notifyListeners();
  }

  List<GeoPoint>? finishDrawing({double toleranceMeters = 1.5}) {
    _isDrawing = false;
    if (_rawPoints.length < 5) {
      _rawPoints.clear();
      notifyListeners();
      return null;
    }

    // Simplify path using Ramer-Douglas-Peucker
    final simplified =
        PathSimplifier.simplifyPolygon(_rawPoints, toleranceMeters);

    // Validate
    final val = PolygonValidator.validate(simplified);
    if (!val.isValid) {
      _rawPoints.clear();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return simplified;
  }
}
