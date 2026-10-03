class RegionalUnitPreset {
  final String id;
  final String name;
  final String stateOrRegion;
  final double bighaSqMeters;
  final double biswaSqMeters;
  final double kanalSqMeters;
  final double marlaSqMeters;
  final double gunthaSqMeters;
  final double centSqMeters;
  final double dhurSqMeters;
  final double decimalSqMeters;

  const RegionalUnitPreset({
    required this.id,
    required this.name,
    required this.stateOrRegion,
    required this.bighaSqMeters,
    required this.biswaSqMeters,
    required this.kanalSqMeters,
    required this.marlaSqMeters,
    required this.gunthaSqMeters,
    required this.centSqMeters,
    required this.dhurSqMeters,
    required this.decimalSqMeters,
  });
}

class CustomLandUnit {
  final String name;
  final double sqMeters;

  const CustomLandUnit({required this.name, required this.sqMeters});

  Map<String, dynamic> toJson() => {
        'name': name,
        'sqMeters': sqMeters,
      };

  factory CustomLandUnit.fromJson(Map<String, dynamic> json) => CustomLandUnit(
        name: json['name'] as String,
        sqMeters: (json['sqMeters'] as num).toDouble(),
      );
}

class UnitConverter {
  static const List<RegionalUnitPreset> presets = [
    RegionalUnitPreset(
      id: 'uttarakhand',
      name: 'Uttarakhand',
      stateOrRegion: 'Uttarakhand',
      bighaSqMeters: 2529.285, // 20 Nali = 2,529.285 m²
      biswaSqMeters: 126.464,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 12.65,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'up_pucca',
      name: 'Uttar Pradesh (Pucca)',
      stateOrRegion: 'Uttar Pradesh',
      bighaSqMeters: 2529.285,
      biswaSqMeters: 126.464,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 6.32,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'up_kaccha',
      name: 'Uttar Pradesh (Kaccha)',
      stateOrRegion: 'Uttar Pradesh',
      bighaSqMeters: 843.095, // 1/3 Pucca Bigha
      biswaSqMeters: 42.155,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 2.11,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'punjab_haryana',
      name: 'Punjab & Haryana',
      stateOrRegion: 'Punjab & Haryana',
      bighaSqMeters: 1011.714,
      biswaSqMeters: 50.586,
      kanalSqMeters: 505.857, // 8 Kanals = 1 Acre
      marlaSqMeters: 25.293, // 20 Marlas = 1 Kanal
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 12.65,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'bihar',
      name: 'Bihar',
      stateOrRegion: 'Bihar',
      bighaSqMeters: 2529.285,
      biswaSqMeters: 126.464,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 6.32,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'rajasthan_pucca',
      name: 'Rajasthan (Pucca)',
      stateOrRegion: 'Rajasthan',
      bighaSqMeters: 2500.0,
      biswaSqMeters: 125.0,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 6.25,
      decimalSqMeters: 40.469,
    ),
    RegionalUnitPreset(
      id: 'mp',
      name: 'Madhya Pradesh',
      stateOrRegion: 'Madhya Pradesh',
      bighaSqMeters: 1337.8,
      biswaSqMeters: 66.89,
      kanalSqMeters: 505.857,
      marlaSqMeters: 25.293,
      gunthaSqMeters: 101.171,
      centSqMeters: 40.469,
      dhurSqMeters: 3.34,
      decimalSqMeters: 40.469,
    ),
  ];

  static double toAcres(double sqMeters) => sqMeters / 4046.8564224;
  static double toHectares(double sqMeters) => sqMeters / 10000.0;
  static double toSqFeet(double sqMeters) => sqMeters * 10.7639104;
  static double toSqYards(double sqMeters) => sqMeters * 1.19599005;

  static double toBigha(double sqMeters, double bighaSqMeters) =>
      sqMeters / bighaSqMeters;

  static double toBiswa(double sqMeters, double biswaSqMeters) =>
      sqMeters / biswaSqMeters;

  static double toKanal(double sqMeters, double kanalSqMeters) =>
      sqMeters / kanalSqMeters;

  static double toMarla(double sqMeters, double marlaSqMeters) =>
      sqMeters / marlaSqMeters;

  static double toGuntha(double sqMeters, double gunthaSqMeters) =>
      sqMeters / gunthaSqMeters;

  static double toCent(double sqMeters, double centSqMeters) =>
      sqMeters / centSqMeters;
}

/// Blocker #3 & #9: Persistent user settings backed by SQLite
class UnitSettings {
  static String primaryAreaUnit = 'Acres';
  static String primaryDistanceUnit = 'Meters';
  static String selectedRegionId = 'unknown';
  static String selectedRegionName = 'Unknown / Not specified';
  static CustomLandUnit? customUnit;
  static String selectedMapLayer = 'satellite';

  static bool _initialized = false;

  /// Optional persistence handler (e.g. connected to SQLite AppDatabase.saveSetting)
  static Future<void> Function(String key, String value)? onSettingChanged;

  /// Optional database settings loader
  static Future<Map<String, String>> Function()? settingsLoader;

  static void _persist(String key, String value) {
    if (onSettingChanged != null) {
      onSettingChanged!(key, value);
    }
  }

  static Future<void> loadFromDatabase() async {
    if (_initialized) return;
    try {
      if (settingsLoader != null) {
        final settings = await settingsLoader!();
        loadFromMap(settings);
      }
      _initialized = true;
    } catch (_) {}
  }

  static void loadFromMap(Map<String, String> settings) {
    if (settings.containsKey('primaryAreaUnit')) {
      primaryAreaUnit = settings['primaryAreaUnit']!;
    }
    if (settings.containsKey('primaryDistanceUnit')) {
      primaryDistanceUnit = settings['primaryDistanceUnit']!;
    }
    if (settings.containsKey('selectedRegionId')) {
      setRegion(settings['selectedRegionId']!, persist: false);
    }
    if (settings.containsKey('customUnitName') && settings.containsKey('customUnitSqMeters')) {
      final name = settings['customUnitName']!;
      final sqM = double.tryParse(settings['customUnitSqMeters']!);
      if (sqM != null && sqM > 0) {
        customUnit = CustomLandUnit(name: name, sqMeters: sqM);
      }
    }
    if (settings.containsKey('selectedMapLayer')) {
      selectedMapLayer = settings['selectedMapLayer']!;
    }
    _initialized = true;
  }

  static List<String> get availableAreaUnits {
    final list = [
      'Acres',
      'Hectares',
      'Square Meters',
      'Square Feet',
      'Square Yards',
      'Bigha',
    ];
    if (customUnit != null && !list.contains(customUnit!.name)) {
      list.add(customUnit!.name);
    }
    return list;
  }

  static const List<String> availableDistanceUnits = [
    'Meters',
    'Kilometers',
    'Feet',
    'Yards',
  ];

  static RegionalUnitPreset? get activePreset {
    try {
      return UnitConverter.presets.firstWhere((p) => p.id == selectedRegionId);
    } catch (_) {
      return null;
    }
  }

  static void setRegion(String regionId, {bool persist = true}) {
    selectedRegionId = regionId;
    if (regionId == 'unknown') {
      selectedRegionName = 'Unknown / Not specified';
    } else {
      final p = activePreset;
      if (p != null) {
        selectedRegionName = p.name;
      }
    }
    if (persist) {
      _persist('selectedRegionId', regionId);
    }
  }

  static void setPrimaryAreaUnit(String unit) {
    primaryAreaUnit = unit;
    _persist('primaryAreaUnit', unit);
  }

  static void setPrimaryDistanceUnit(String unit) {
    primaryDistanceUnit = unit;
    _persist('primaryDistanceUnit', unit);
  }

  static void setMapLayer(String layer) {
    selectedMapLayer = layer;
    _persist('selectedMapLayer', layer);
  }

  static void setCustomUnit(String name, double sqMeters) {
    customUnit = CustomLandUnit(name: name, sqMeters: sqMeters);
    _persist('customUnitName', name);
    _persist('customUnitSqMeters', sqMeters.toString());
  }

  static void clearCustomUnit() {
    customUnit = null;
    _persist('customUnitName', '');
    _persist('customUnitSqMeters', '');
  }

  /// Format an area given in square meters using either the specified unit or the user-selected unit
  static String formatArea(double sqMeters, {String? unit, double? customSqMeters}) {
    final targetUnit = unit ?? primaryAreaUnit;

    if (customUnit != null && (targetUnit == customUnit!.name || targetUnit == 'Custom')) {
      final rate = customSqMeters ?? customUnit!.sqMeters;
      final val = sqMeters / rate;
      return '${val.toStringAsFixed(3)} ${customUnit!.name}';
    }

    switch (targetUnit.toLowerCase()) {
      case 'hectares':
      case 'ha':
        final ha = UnitConverter.toHectares(sqMeters);
        return '${ha.toStringAsFixed(ha >= 10 ? 2 : 3)} Hectares';
      case 'square meters':
      case 'm²':
      case 'sqm':
        return '${sqMeters.toStringAsFixed(1)} m²';
      case 'square feet':
      case 'sq ft':
      case 'sqft':
        return '${UnitConverter.toSqFeet(sqMeters).toStringAsFixed(0)} sq ft';
      case 'square yards':
      case 'sq yd':
        return '${UnitConverter.toSqYards(sqMeters).toStringAsFixed(1)} sq yd';
      case 'bigha':
        final preset = activePreset;
        if (preset == null) {
          return 'Conversion unavailable';
        }
        final bigha = UnitConverter.toBigha(sqMeters, preset.bighaSqMeters);
        return '${bigha.toStringAsFixed(3)} Bigha';
      case 'acres':
      default:
        final ac = UnitConverter.toAcres(sqMeters);
        return '${ac.toStringAsFixed(2)} Acres';
    }
  }

  /// Blocker #4: Format area using immutable conversion snapshot from saved field
  static String formatAreaWithSnapshot({
    required double sqMeters,
    required String unit,
    String? customName,
    double? customSqMeters,
    String? region,
  }) {
    if (customName != null && customSqMeters != null && customSqMeters > 0 && unit == customName) {
      final val = sqMeters / customSqMeters;
      return '${val.toStringAsFixed(3)} $customName';
    }

    switch (unit.toLowerCase()) {
      case 'hectares':
      case 'ha':
        final ha = UnitConverter.toHectares(sqMeters);
        return '${ha.toStringAsFixed(ha >= 10 ? 2 : 3)} Hectares';
      case 'square meters':
      case 'm²':
      case 'sqm':
        return '${sqMeters.toStringAsFixed(1)} m²';
      case 'square feet':
      case 'sq ft':
      case 'sqft':
        return '${UnitConverter.toSqFeet(sqMeters).toStringAsFixed(0)} sq ft';
      case 'square yards':
      case 'sq yd':
        return '${UnitConverter.toSqYards(sqMeters).toStringAsFixed(1)} sq yd';
      case 'bigha':
        double? rate;
        if (customSqMeters != null && customSqMeters > 0) {
          rate = customSqMeters;
        } else if (region != null && region.isNotEmpty && region.toLowerCase() != 'unknown / not specified') {
          final matched = UnitConverter.presets.where((p) =>
              p.name.toLowerCase() == region.toLowerCase() ||
              p.stateOrRegion.toLowerCase() == region.toLowerCase() ||
              p.id.toLowerCase() == region.toLowerCase());
          if (matched.isNotEmpty) {
            rate = matched.first.bighaSqMeters;
          }
        }
        if (rate == null || rate <= 0) {
          return 'Conversion unavailable';
        }
        final bigha = UnitConverter.toBigha(sqMeters, rate);
        return '${bigha.toStringAsFixed(3)} Bigha';
      case 'acres':
      default:
        final ac = UnitConverter.toAcres(sqMeters);
        return '${ac.toStringAsFixed(2)} Acres';
    }
  }

  /// Format a perimeter given in meters
  static String formatPerimeter(double meters, {String? unit}) {
    final targetUnit = unit ?? primaryDistanceUnit;
    switch (targetUnit.toLowerCase()) {
      case 'kilometers':
      case 'km':
        return '${(meters / 1000.0).toStringAsFixed(2)} km';
      case 'feet':
      case 'ft':
        return '${(meters * 3.28084).toStringAsFixed(1)} ft';
      case 'yards':
      case 'yd':
        return '${(meters * 1.09361).toStringAsFixed(1)} yd';
      case 'meters':
      default:
        return meters >= 1000
            ? '${(meters / 1000.0).toStringAsFixed(2)} km (${meters.toStringAsFixed(0)} m)'
            : '${meters.toStringAsFixed(1)} m';
    }
  }
}
