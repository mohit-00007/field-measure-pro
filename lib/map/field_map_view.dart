import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/units.dart';
import '../gis/geodesic_calculator.dart';
import '../gis/path_simplifier.dart';
import '../models/geo_point.dart';
import '../platform/place_search.dart'
    if (dart.library.html) '../platform/place_search_web.dart';

enum MapInteractionMode { normal, drawing, pointByPoint, editing, gpsWalk }

enum MapLayerType { satellite, street, terrain }

class MapLayerInfo {
  final MapLayerType type;
  final String name;
  final MapType googleType;

  const MapLayerInfo({
    required this.type,
    required this.name,
    required this.googleType,
  });
}

class MapProviders {
  static const MapLayerInfo satellite = MapLayerInfo(
    type: MapLayerType.satellite,
    name: 'Satellite',
    googleType: MapType.satellite,
  );

  static const MapLayerInfo street = MapLayerInfo(
    type: MapLayerType.street,
    name: 'Street',
    googleType: MapType.normal,
  );

  static const MapLayerInfo terrain = MapLayerInfo(
    type: MapLayerType.terrain,
    name: 'Terrain',
    googleType: MapType.terrain,
  );

  static const List<MapLayerInfo> allLayers = [satellite, street, terrain];

  static MapLayerInfo getLayerByName(String name) {
    switch (name.toLowerCase()) {
      case 'street':
        return street;
      case 'terrain':
        return terrain;
      case 'satellite':
      default:
        return satellite;
    }
  }
}

class FieldMapView extends StatefulWidget {
  final List<GeoPoint> points;
  final List<GeoPoint>? originalGpsPoints;
  final GeoPoint? currentGpsPoint;
  final MapInteractionMode mode;
  final int? selectedVertexIndex;
  final String? customModeTitle;

  final void Function(int index)? onVertexDragStart;
  final void Function(int index, GeoPoint newPoint)? onVertexDrag;
  final void Function(int index)? onVertexDragEnd;
  final VoidCallback? onVertexDragCancel;
  final void Function(int index, GeoPoint midpoint)? onMidpointInsert;
  final void Function(int index)? onVertexSelected;
  final void Function(List<GeoPoint>)? onDrawingFinished;
  final void Function(GeoPoint point)? onMapTapPoint;

  const FieldMapView({
    super.key,
    required this.points,
    this.originalGpsPoints,
    this.currentGpsPoint,
    required this.mode,
    this.selectedVertexIndex,
    this.customModeTitle,
    this.onVertexDragStart,
    this.onVertexDrag,
    this.onVertexDragEnd,
    this.onVertexDragCancel,
    this.onMidpointInsert,
    this.onVertexSelected,
    this.onDrawingFinished,
    this.onMapTapPoint,
  });

  @override
  State<FieldMapView> createState() => _FieldMapViewState();
}

class _FieldMapViewState extends State<FieldMapView> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final GlobalKey _mapKey = GlobalKey();
  final List<Offset> _touchScreenPoints = [];
  bool _isFreehandDrawing = false;
  bool _showLayerMenu = false;
  late MapLayerInfo _currentLayer;
  late final PlaceSearchBridge _placeSearchBridge;
  GeoPoint? _searchedPlace;
  String? _searchedPlaceName;

  @override
  void initState() {
    super.initState();
    _currentLayer = MapProviders.getLayerByName(UnitSettings.selectedMapLayer);
    _placeSearchBridge = PlaceSearchBridge((latitude, longitude, name, address) {
      if (!mounted) return;
      final point = GeoPoint(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      setState(() {
        _searchedPlace = point;
        _searchedPlaceName = address.isEmpty ? name : '$name\n$address';
      });
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(latitude, longitude), zoom: 17),
          ),
        );
      });
    });
    _placeSearchBridge.initialize();
  }

  @override
  void dispose() {
    _placeSearchBridge.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FieldMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && widget.mode != MapInteractionMode.drawing) {
      _touchScreenPoints.clear();
      _isFreehandDrawing = false;
    }
  }

  LatLng _latLngFor(GeoPoint p) => LatLng(p.latitude, p.longitude);

  Set<Polygon> _buildPolygons() {
    final polygons = <Polygon>{};

    if (widget.originalGpsPoints != null && widget.originalGpsPoints!.length >= 3) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('original_gps'),
          points: widget.originalGpsPoints!.map(_latLngFor).toList(),
          fillColor: const Color(0x33FACC15),
          strokeColor: const Color(0xFFEAB308),
          strokeWidth: 2,
          geodesic: true,
        ),
      );
    }

    if (widget.points.length >= 3 && widget.mode != MapInteractionMode.gpsWalk) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('main_field'),
          points: widget.points.map(_latLngFor).toList(),
          fillColor: const Color(0x4422C55E),
          strokeColor: const Color(0xFF16A34A),
          strokeWidth: 3,
          geodesic: true,
        ),
      );
    }

    return polygons;
  }

  Set<Polyline> _buildPolylines() {
    if ((widget.mode == MapInteractionMode.gpsWalk || widget.mode == MapInteractionMode.pointByPoint) &&
        widget.points.length >= 2) {
      return {
        Polyline(
          polylineId: const PolylineId('active_path'),
          points: widget.points.map(_latLngFor).toList(),
          color: widget.mode == MapInteractionMode.pointByPoint
              ? const Color(0xFF4ADE80)
              : const Color(0xFF3B82F6),
          width: 4,
          geodesic: true,
        ),
      };
    }
    return <Polyline>{};
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.mode == MapInteractionMode.pointByPoint) {
      for (int i = 0; i < widget.points.length; i++) {
        final point = widget.points[i];
        markers.add(
          Marker(
            markerId: MarkerId('point_$i'),
            position: _latLngFor(point),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Point ${i + 1}'),
          ),
        );
      }
    }

    if (widget.mode == MapInteractionMode.editing) {
      for (int i = 0; i < widget.points.length; i++) {
        final point = widget.points[i];
        final selected = widget.selectedVertexIndex == i;
        markers.add(
          Marker(
            markerId: MarkerId('vertex_$i'),
            position: _latLngFor(point),
            draggable: true,
            consumeTapEvents: true,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              selected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(title: 'Vertex ${i + 1}'),
            onTap: () => widget.onVertexSelected?.call(i),
            onDragStart: (_) => widget.onVertexDragStart?.call(i),
            onDrag: (latLng) => widget.onVertexDrag?.call(
              i,
              GeoPoint(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
            onDragEnd: (_) => widget.onVertexDragEnd?.call(i),
          ),
        );

        if (widget.points.length >= 3) {
          final next = widget.points[(i + 1) % widget.points.length];
          final mid = GeodesicCalculator.midpoint(point, next);
          markers.add(
            Marker(
              markerId: MarkerId('midpoint_$i'),
              position: _latLngFor(mid),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
              consumeTapEvents: true,
              infoWindow: const InfoWindow(title: 'Insert point'),
              onTap: () {
                widget.onMidpointInsert?.call(i + 1, mid);
                widget.onVertexSelected?.call(i + 1);
              },
            ),
          );
        }
      }
    }

    if (_searchedPlace != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('searched_place'),
          position: _latLngFor(_searchedPlace!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Searched place',
            snippet: _searchedPlaceName,
          ),
          zIndexInt: 1100,
        ),
      );
    }

    if (widget.currentGpsPoint != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_gps'),
          position: _latLngFor(widget.currentGpsPoint!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Current GPS position'),
          zIndexInt: 1000,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = const LatLng(29.9457, 78.1642);
    if (widget.points.isNotEmpty) {
      center = _latLngFor(widget.points.first);
    } else if (widget.currentGpsPoint != null) {
      center = _latLngFor(widget.currentGpsPoint!);
    }

    String modeLabel = widget.customModeTitle ?? '';
    if (modeLabel.isEmpty) {
      switch (widget.mode) {
        case MapInteractionMode.drawing:
          modeLabel = 'DRAWING (FREEHAND)';
          break;
        case MapInteractionMode.pointByPoint:
          modeLabel = 'DRAWING (POINT-BY-POINT)';
          break;
        case MapInteractionMode.editing:
          modeLabel = 'EDITING BOUNDARY';
          break;
        case MapInteractionMode.gpsWalk:
          modeLabel = 'GPS WALK ACTIVE';
          break;
        case MapInteractionMode.normal:
          modeLabel = 'MAP VIEW';
          break;
      }
    }

    final drawing = widget.mode == MapInteractionMode.drawing;
    final editing = widget.mode == MapInteractionMode.editing;

    return Stack(
      key: _mapKey,
      children: [
        GoogleMap(
          key: const ValueKey('field_measure_google_map'),
          initialCameraPosition: CameraPosition(target: center, zoom: 17),
          mapType: _currentLayer.googleType,
          onMapCreated: (controller) {
            if (!_controller.isCompleted) _controller.complete(controller);
          },
          onTap: (latLng) {
            if (widget.mode == MapInteractionMode.pointByPoint) {
              widget.onMapTapPoint?.call(
                GeoPoint(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
          },
          polygons: _buildPolygons(),
          polylines: _buildPolylines(),
          markers: _buildMarkers(),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: true,
          rotateGesturesEnabled: !drawing,
          scrollGesturesEnabled: !drawing,
          tiltGesturesEnabled: !drawing,
          zoomGesturesEnabled: !drawing,
          mapTypeControlEnabled: false,
          fullscreenControlEnabled: false,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        ),

        if (drawing)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                setState(() {
                  _isFreehandDrawing = true;
                  _touchScreenPoints
                    ..clear()
                    ..add(details.localPosition);
                });
              },
              onPanUpdate: (details) {
                setState(() => _touchScreenPoints.add(details.localPosition));
              },
              onPanEnd: (_) => _finishFreehandDrawing(),
              onPanCancel: () {
                _touchScreenPoints.clear();
                if (mounted) setState(() => _isFreehandDrawing = false);
                widget.onVertexDragCancel?.call();
              },
              child: CustomPaint(
                painter: FreehandTouchPainter(points: _touchScreenPoints),
                size: Size.infinite,
              ),
            ),
          ),

        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xCC0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: editing ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  modeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'map_layer_toggle',
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 3,
                onPressed: () => setState(() => _showLayerMenu = !_showLayerMenu),
                child: const Icon(Icons.layers, size: 20),
              ),
              if (_showLayerMenu)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xF20F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                  ),
                  child: Column(
                    children: MapProviders.allLayers.map((layer) {
                      final selected = layer.type == _currentLayer.type;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _currentLayer = layer;
                            _showLayerMenu = false;
                          });
                          UnitSettings.setMapLayer(layer.name.toLowerCase());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF16A34A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            layer.name,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        if (_isFreehandDrawing)
          const Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xDD0F172A),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(
                    'Release to finish boundary',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _finishFreehandDrawing() async {
    if (_touchScreenPoints.length < 5) {
      _touchScreenPoints.clear();
      if (mounted) setState(() => _isFreehandDrawing = false);
      return;
    }

    final points = List<Offset>.from(_touchScreenPoints);
    _touchScreenPoints.clear();
    if (mounted) setState(() => _isFreehandDrawing = false);

    try {
      final controller = await _controller.future;
      final geoPoints = <GeoPoint>[];
      for (final offset in points) {
        final latLng = await controller.getLatLng(
          ScreenCoordinate(x: offset.dx.round(), y: offset.dy.round()),
        );
        geoPoints.add(
          GeoPoint(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            accuracy: null,
          ),
        );
      }

      final simplified = PathSimplifier.simplifyPolygon(geoPoints, 1.5);
      if (simplified.length >= 3) {
        widget.onDrawingFinished?.call(simplified);
      }
    } catch (_) {
      widget.onDrawingFinished?.call(const <GeoPoint>[]);
    }
  }
}

class FreehandTouchPainter extends CustomPainter {
  final List<Offset> points;
  FreehandTouchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ui.Path path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FreehandTouchPainter oldDelegate) => true;
}
