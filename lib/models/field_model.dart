import 'geo_point.dart';

enum MeasurementMode {
  gpsWalk,
  mapDraw,
  gpsAdjust,
  imported,
}

class GpsAccuracyStats {
  final double? averageAccuracy;
  final double? bestAccuracy;
  final double? worstAccuracy;
  final int acceptedPoints;
  final int rejectedPoints;

  const GpsAccuracyStats({
    this.averageAccuracy,
    this.bestAccuracy,
    this.worstAccuracy,
    required this.acceptedPoints,
    required this.rejectedPoints,
  });

  Map<String, dynamic> toJson() => {
        'averageAccuracy': averageAccuracy,
        'bestAccuracy': bestAccuracy,
        'worstAccuracy': worstAccuracy,
        'acceptedPoints': acceptedPoints,
        'rejectedPoints': rejectedPoints,
      };

  factory GpsAccuracyStats.fromJson(Map<String, dynamic> json) =>
      GpsAccuracyStats(
        averageAccuracy: json['averageAccuracy'] != null
            ? (json['averageAccuracy'] as num).toDouble()
            : null,
        bestAccuracy: json['bestAccuracy'] != null
            ? (json['bestAccuracy'] as num).toDouble()
            : null,
        worstAccuracy: json['worstAccuracy'] != null
            ? (json['worstAccuracy'] as num).toDouble()
            : null,
        acceptedPoints: json['acceptedPoints'] as int,
        rejectedPoints: json['rejectedPoints'] as int,
      );
}

class FieldModel {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final MeasurementMode measurementMode;
  final List<GeoPoint>? originalGpsPolygon;
  final List<GeoPoint> finalPolygon;
  final double areaSqMeters;
  final double perimeterMeters;
  final String primaryAreaUnit;
  final String primaryDistanceUnit;
  final String region;
  final GpsAccuracyStats? gpsStats;
  final String? notes;
  final Map<String, dynamic>? metadata;

  // Blocker #4 & Section 11/12: Field-specific conversion snapshot
  final String? customAreaUnitName;
  final double? customAreaUnitSqMeters;
  final Map<String, dynamic>? conversionSnapshot;

  const FieldModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.measurementMode,
    this.originalGpsPolygon,
    required this.finalPolygon,
    required this.areaSqMeters,
    required this.perimeterMeters,
    required this.primaryAreaUnit,
    required this.primaryDistanceUnit,
    required this.region,
    this.gpsStats,
    this.notes,
    this.metadata,
    this.customAreaUnitName,
    this.customAreaUnitSqMeters,
    this.conversionSnapshot,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'measurementMode': measurementMode.name,
        'originalGpsPolygon':
            originalGpsPolygon?.map((p) => p.toJson()).toList(),
        'finalPolygon': finalPolygon.map((p) => p.toJson()).toList(),
        'areaSqMeters': areaSqMeters,
        'perimeterMeters': perimeterMeters,
        'primaryAreaUnit': primaryAreaUnit,
        'primaryDistanceUnit': primaryDistanceUnit,
        'region': region,
        'gpsStats': gpsStats?.toJson(),
        'notes': notes,
        'metadata': metadata,
        'customAreaUnitName': customAreaUnitName,
        'customAreaUnitSqMeters': customAreaUnitSqMeters,
        'conversionSnapshot': conversionSnapshot,
      };

  factory FieldModel.fromJson(Map<String, dynamic> json) => FieldModel(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        measurementMode: MeasurementMode.values.byName(
            json['measurementMode'] as String? ?? 'mapDraw'),
        originalGpsPolygon: json['originalGpsPolygon'] != null
            ? (json['originalGpsPolygon'] as List)
                .map((p) => GeoPoint.fromJson(p as Map<String, dynamic>))
                .toList()
            : null,
        finalPolygon: (json['finalPolygon'] as List)
            .map((p) => GeoPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        areaSqMeters: (json['areaSqMeters'] as num).toDouble(),
        perimeterMeters: (json['perimeterMeters'] as num).toDouble(),
        primaryAreaUnit: json['primaryAreaUnit'] as String? ?? 'Acres',
        primaryDistanceUnit:
            json['primaryDistanceUnit'] as String? ?? 'Meters',
        region: json['region'] as String? ?? 'Unknown / Not specified',
        gpsStats: json['gpsStats'] != null
            ? GpsAccuracyStats.fromJson(
                json['gpsStats'] as Map<String, dynamic>)
            : null,
        notes: json['notes'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        customAreaUnitName: json['customAreaUnitName'] as String?,
        customAreaUnitSqMeters: json['customAreaUnitSqMeters'] != null
            ? (json['customAreaUnitSqMeters'] as num).toDouble()
            : null,
        conversionSnapshot: json['conversionSnapshot'] as Map<String, dynamic>?,
      );
}
