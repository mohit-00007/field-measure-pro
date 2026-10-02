class GeoPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final int timestamp;
  final double? accuracy; // in meters (null if unknown/imported, never fake)
  final double? speed;
  final double? heading;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.heading,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'timestamp': timestamp,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
        timestamp: json['timestamp'] as int,
        accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
        speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
        heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      );

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    int? timestamp,
    double? accuracy,
    double? speed,
    double? heading,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }
}
