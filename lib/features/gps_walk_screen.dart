import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/geo_point.dart';
import '../models/field_model.dart';
import '../gps/gps_service.dart';
import '../gis/geodesic_calculator.dart';
import '../core/units.dart';
import '../map/field_map_view.dart';
import '../database/app_database.dart';
import 'boundary_editor_screen.dart';
import 'field_result_screen.dart';

enum GpsWalkTrackingState { idle, tracking, paused, finished }

class GpsWalkScreen extends StatefulWidget {
  final bool isGpsAdjustMode;
  final List<GeoPoint>? initialPoints;
  final bool resumeAsPaused;

  const GpsWalkScreen({
    super.key,
    this.isGpsAdjustMode = false,
    this.initialPoints,
    this.resumeAsPaused = false,
  });

  @override
  State<GpsWalkScreen> createState() => _GpsWalkScreenState();
}

class _GpsWalkScreenState extends State<GpsWalkScreen> {
  final GpsService _gpsService = GpsService();
  final List<GeoPoint> _points = [];
  GeoPoint? _currentGpsPoint;
  GpsAccuracyStats? _stats;
  String? _statusMessage;
  bool _isNearStart = false;
  double? _distanceToStart;

  GpsWalkTrackingState _trackingState = GpsWalkTrackingState.idle;

  // Active duration calculation (Section 24)
  DateTime? _startedAt;
  DateTime? _pausedAt;
  Duration _totalPausedDuration = Duration.zero;
  Timer? _durationTimer;
  Duration _activeDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.initialPoints != null && widget.initialPoints!.isNotEmpty) {
      _points.addAll(widget.initialPoints!);
    }

    if (widget.resumeAsPaused) {
      _trackingState = GpsWalkTrackingState.paused;
    } else {
      _startGps();
    }

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateActiveDuration();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _gpsService.stopTracking();
    super.dispose();
  }

  void _updateActiveDuration() {
    if (_trackingState == GpsWalkTrackingState.tracking && _startedAt != null) {
      final now = DateTime.now();
      setState(() {
        _activeDuration = now.difference(_startedAt!) - _totalPausedDuration;
      });
    }
  }

  void _startGps() async {
    final hasPermission = await _gpsService.checkAndRequestPermissions();
    if (!hasPermission) {
      setState(() {
        _statusMessage = 'Location permission is required for GPS Walk.';
      });
      return;
    }

    setState(() {
      _trackingState = GpsWalkTrackingState.tracking;
      _startedAt ??= DateTime.now();
    });

    _gpsService.startTracking(
      onPoint: (point, stats) {
        if (_trackingState != GpsWalkTrackingState.tracking) return;

        setState(() {
          _currentGpsPoint = point;
          _stats = stats;
          _points.add(point);

          if (_points.length > 5) {
            final start = _points.first;
            final dist = GeodesicCalculator.distanceMeters(point, start);
            _distanceToStart = dist;
            _isNearStart = dist <= 12.0;
          }
        });

        // Persist draft after meaningful points update (Section 28 & 29)
        AppDatabase.saveActiveDraft(
          id: 'active_draft',
          mode: widget.isGpsAdjustMode
              ? MeasurementMode.gpsAdjust.name
              : MeasurementMode.gpsWalk.name,
          state: 'TRACKING',
          points: _points,
          originalGpsPoints: widget.isGpsAdjustMode ? List.from(_points) : null,
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statusMessage = error;
        });
      },
    );
  }

  void _pauseGps() {
    _gpsService.stopTracking();
    setState(() {
      _trackingState = GpsWalkTrackingState.paused;
      _pausedAt = DateTime.now();
    });

    AppDatabase.saveActiveDraft(
      id: 'active_draft',
      mode: widget.isGpsAdjustMode
          ? MeasurementMode.gpsAdjust.name
          : MeasurementMode.gpsWalk.name,
      state: 'PAUSED',
      points: _points,
      originalGpsPoints: widget.isGpsAdjustMode ? List.from(_points) : null,
    );
  }

  void _resumeGps() {
    if (_pausedAt != null) {
      _totalPausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
    _startGps();
  }

  void _finishField() {
    _gpsService.stopTracking();
    _durationTimer?.cancel();
    setState(() {
      _trackingState = GpsWalkTrackingState.finished;
    });

    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('At least 3 GPS points required to close boundary.')),
      );
      return;
    }

    if (widget.isGpsAdjustMode) {
      AppDatabase.saveActiveDraft(
        id: 'active_draft',
        mode: MeasurementMode.gpsAdjust.name,
        state: 'EDITING',
        points: _points,
        originalGpsPoints: List.from(_points),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BoundaryEditorScreen(
            initialPoints: _points,
            originalGpsPoints: List.from(_points),
            mode: MeasurementMode.gpsAdjust,
            gpsStats: _stats,
          ),
        ),
      );
    } else {
      AppDatabase.clearActiveDraft();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FieldResultScreen(
            points: _points,
            mode: MeasurementMode.gpsWalk,
            gpsStats: _stats,
          ),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double area =
        _points.length >= 3 ? GeodesicCalculator.areaSqMeters(_points) : 0.0;
    final double perimeter = _points.length >= 3
        ? GeodesicCalculator.perimeterMeters(_points)
        : GeodesicCalculator.pathLengthMeters(_points);

    final quality = GpsFilter.getQualityStatus(_currentGpsPoint?.accuracy);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.isGpsAdjustMode ? 'GPS + ADJUST' : 'GPS WALK',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          // GPS Simulator gated to kDebugMode only (Section 30)
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _gpsService.isSimulating ? Icons.smart_toy : Icons.smart_toy_outlined,
                color: _gpsService.isSimulating ? Colors.green : Colors.grey,
              ),
              tooltip: 'Toggle GPS Simulator (Dev Only)',
              onPressed: () {
                setState(() {
                  _gpsService.isSimulating = !_gpsService.isSimulating;
                });
                if (_trackingState == GpsWalkTrackingState.tracking) {
                  _startGps();
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          FieldMapView(
            points: _points,
            currentGpsPoint: _currentGpsPoint,
            mode: MapInteractionMode.gpsWalk,
            customModeTitle: _trackingState == GpsWalkTrackingState.paused
                ? 'GPS WALK (PAUSED)'
                : 'GPS WALK (RECORDING)',
          ),

          // Live Metrics HUD Overlay (Section 23 & 57)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xF20F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LIVE AREA',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            _points.length >= 3
                                ? UnitSettings.formatArea(area)
                                : '-- (Walking...)',
                            style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 22,
                                fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Perimeter: ${UnitSettings.formatPerimeter(perimeter)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Section 21: "GPS reported accuracy"
                          const Text('GPS REPORTED ACCURACY',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            _currentGpsPoint?.accuracy != null
                                ? '±${_currentGpsPoint!.accuracy!.toStringAsFixed(1)} m'
                                : 'Acquiring...',
                            style: TextStyle(
                              color: _currentGpsPoint?.accuracy != null &&
                                      _currentGpsPoint!.accuracy! <= 10.0
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: quality == GpsQualityStatus.excellent
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quality.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: quality == GpsQualityStatus.excellent
                                    ? Colors.green
                                    : Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Points: ${_points.length}  ·  Duration: ${_formatDuration(_activeDuration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        _trackingState == GpsWalkTrackingState.paused
                            ? 'STATUS: PAUSED'
                            : 'STATUS: RECORDING',
                        style: TextStyle(
                          color: _trackingState == GpsWalkTrackingState.paused
                              ? Colors.amberAccent
                              : Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Near start prompt (Section 23: user must confirm closing)
          if (_isNearStart)
            Positioned(
              bottom: 95,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'NEAR START (${_distanceToStart?.toStringAsFixed(1)} m)',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black),
                      onPressed: _finishField,
                      child: const Text('CLOSE FIELD',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Error / status message
          if (_statusMessage != null)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center),
              ),
            ),

          // Bottom Action Control Bar: START, PAUSE, RESUME, FINISH (Section 23 & 24)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Row(
              children: [
                if (_trackingState == GpsWalkTrackingState.tracking) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _pauseGps,
                      icon: const Icon(Icons.pause, size: 20),
                      label: const Text('PAUSE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _finishField,
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('FINISH FIELD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ] else if (_trackingState == GpsWalkTrackingState.paused) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _resumeGps,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _finishField,
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('FINISH FIELD', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _startGps,
                      icon: const Icon(Icons.play_arrow, size: 26),
                      label: const Text('START GPS RECORDING',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
