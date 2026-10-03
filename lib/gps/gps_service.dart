import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/geo_point.dart';
import '../models/field_model.dart';
import '../gis/geodesic_calculator.dart';
import '../core/constants.dart';

enum GpsQualityStatus { excellent, good, fair, poor, unavailable }

class GpsFilter {
  static const double minDistanceMeters = AppConstants.minPointMovementMeters;
  static const double maxRealisticSpeedMps = AppConstants.maxWalkingSpeedMps;
  static const double maxAllowedAccuracyMeters = 30.0;

  static ({bool accepted, String? reason}) evaluatePoint(
    GeoPoint point,
    GeoPoint? previousPoint, {
    bool allowLowAccuracy = false,
  }) {
    if (point.accuracy != null) {
      if (!allowLowAccuracy && point.accuracy! > maxAllowedAccuracyMeters) {
        return (
          accepted: false,
          reason: 'Accuracy poor (±${point.accuracy!.toStringAsFixed(1)}m > ${maxAllowedAccuracyMeters}m)',
        );
      }
    }

    if (previousPoint == null) {
      return (accepted: true, reason: null);
    }

    final double distance = GeodesicCalculator.distanceMeters(previousPoint, point);
    if (distance < minDistanceMeters) {
      return (accepted: false, reason: 'Duplicate/micro-jitter coordinate');
    }

    final double timeDeltaSeconds =
        ((point.timestamp - previousPoint.timestamp) / 1000.0).clamp(0.1, 10000.0);
    final double calculatedSpeedMps = distance / timeDeltaSeconds;

    if (calculatedSpeedMps > maxRealisticSpeedMps) {
      return (
        accepted: false,
        reason: 'GPS jump detected: speed ${calculatedSpeedMps.toStringAsFixed(1)} m/s exceeds threshold',
      );
    }

    return (accepted: true, reason: null);
  }

  static GpsQualityStatus getQualityStatus(double? accuracy) {
    if (accuracy == null || accuracy.isNaN) return GpsQualityStatus.unavailable;
    if (accuracy <= AppConstants.accuracyExcellentMeters) return GpsQualityStatus.excellent;
    if (accuracy <= AppConstants.accuracyGoodMeters) return GpsQualityStatus.good;
    if (accuracy <= AppConstants.accuracyFairMeters) return GpsQualityStatus.fair;
    return GpsQualityStatus.poor;
  }
}

class GpsService {
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  bool allowLowAccuracy = false;
  bool isSimulating = false;
  Timer? _simulatorTimer;

  int _acceptedCount = 0;
  int _rejectedCount = 0;
  double _accuracySum = 0.0;
  double? _bestAccuracy;
  double? _worstAccuracy;

  bool get isTracking => _isTracking;

  GpsAccuracyStats get stats => GpsAccuracyStats(
        averageAccuracy: _acceptedCount > 0 ? _accuracySum / _acceptedCount : null,
        bestAccuracy: _bestAccuracy,
        worstAccuracy: _worstAccuracy,
        acceptedPoints: _acceptedCount,
        rejectedPoints: _rejectedCount,
      );

  void resetStats() {
    _acceptedCount = 0;
    _rejectedCount = 0;
    _accuracySum = 0.0;
    _bestAccuracy = null;
    _worstAccuracy = null;
  }

  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void startTracking({
    required Function(GeoPoint point, GpsAccuracyStats stats) onPoint,
    required Function(String error) onError,
    GeoPoint? lastPoint,
  }) async {
    stopTracking();

    if (isSimulating) {
      _startSimulator(onPoint, lastPoint);
      return;
    }

    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      onError('Location permission denied or location services disabled.');
      return;
    }

    _isTracking = true;
    GeoPoint? previousPoint = lastPoint;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // 1 meter filter at OS level
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final point = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          timestamp: position.timestamp.millisecondsSinceEpoch,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
        );

        final eval = GpsFilter.evaluatePoint(point, previousPoint, allowLowAccuracy: allowLowAccuracy);

        if (eval.accepted) {
          _acceptedCount++;
          if (point.accuracy != null) {
            _accuracySum += point.accuracy!;
            if (_bestAccuracy == null || point.accuracy! < _bestAccuracy!) {
              _bestAccuracy = point.accuracy;
            }
            if (_worstAccuracy == null || point.accuracy! > _worstAccuracy!) {
              _worstAccuracy = point.accuracy;
            }
          }
          previousPoint = point;
          onPoint(point, stats);
        } else {
          _rejectedCount++;
        }
      },
      onError: (e) {
        onError(e.toString());
      },
    );
  }

  void stopTracking() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
  }

  void _startSimulator(
    Function(GeoPoint point, GpsAccuracyStats stats) onPoint,
    GeoPoint? lastPoint,
  ) {
    _isTracking = true;
    const double centerLat = 30.0668;
    const double centerLon = 78.1642;
    const double dLat = 0.0009; // ~100m
    const double dLon = 0.0008; // ~80m

    final waypoints = [
      [centerLat, centerLon],
      [centerLat + dLat * 0.4, centerLon + dLon * 0.05],
      [centerLat + dLat * 0.8, centerLon + dLon * 0.1],
      [centerLat + dLat, centerLon + dLon * 0.15],
      [centerLat + dLat * 1.05, centerLon + dLon * 0.5],
      [centerLat + dLat, centerLon + dLon],
      [centerLat + dLat * 0.6, centerLon + dLon * 0.95],
      [centerLat + dLat * 0.2, centerLon + dLon * 0.9],
      [centerLat, centerLon + dLon * 0.8],
      [centerLat - dLat * 0.05, centerLon + dLon * 0.4],
      [centerLat, centerLon + 0.00003], // near start
    ];

    int legIndex = 0;
    int stepInLeg = 0;
    const int stepsPerLeg = 4;
    GeoPoint? prev = lastPoint;

    _simulatorTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (legIndex >= waypoints.length - 1) {
        timer.cancel();
        return;
      }

      final p1 = waypoints[legIndex];
      final p2 = waypoints[legIndex + 1];
      final double t = stepInLeg / stepsPerLeg;

      final lat = p1[0] + (p2[0] - p1[0]) * t;
      final lon = p1[1] + (p2[1] - p1[1]) * t;
      final acc = 3.5;

      final point = GeoPoint(
        latitude: lat,
        longitude: lon,
        altitude: 430.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accuracy: acc,
        speed: 1.2,
        heading: 45.0,
      );

      final eval = GpsFilter.evaluatePoint(point, prev, allowLowAccuracy: allowLowAccuracy);
      if (eval.accepted) {
        _acceptedCount++;
        _accuracySum += acc;
        _bestAccuracy = _bestAccuracy == null ? acc : (_bestAccuracy! > acc ? acc : _bestAccuracy);
        _worstAccuracy = _worstAccuracy == null ? acc : (_worstAccuracy! < acc ? acc : _worstAccuracy);
        prev = point;
        onPoint(point, stats);
      } else {
        _rejectedCount++;
      }

      stepInLeg++;
      if (stepInLeg > stepsPerLeg) {
        stepInLeg = 0;
        legIndex++;
      }
    });
  }
}
