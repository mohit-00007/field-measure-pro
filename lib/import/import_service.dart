import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/geo_point.dart';
import '../gis/polygon_validator.dart';

class ImportResult {
  final bool success;
  final List<GeoPoint> points;
  final String? name;
  final String? errorMessage;

  const ImportResult({
    required this.success,
    required this.points,
    this.name,
    this.errorMessage,
  });
}

class ImportService {
  /// Real system file picker to select KML, GeoJSON, CSV, or JSON (Section 42)
  static Future<ImportResult> pickAndImportFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['geojson', 'kml', 'csv', 'json', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return const ImportResult(success: false, points: [], errorMessage: 'File selection cancelled');
      }

      final file = result.files.first;
      String content = '';

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        return const ImportResult(
          success: false,
          points: [],
          errorMessage: 'Could not read file data. Please select the file again.',
        );
      }

      final ext = file.extension?.toLowerCase() ?? '';
      final fileName = file.name.replaceAll('.$ext', '');

      if (ext == 'geojson' || content.trim().startsWith('{')) {
        final res = parseGeoJson(content);
        return ImportResult(
          success: res.success,
          points: res.points,
          name: res.name ?? fileName,
          errorMessage: res.errorMessage,
        );
      } else if (ext == 'kml' || content.contains('<kml') || content.contains('<coordinates>')) {
        final res = parseKml(content);
        return ImportResult(
          success: res.success,
          points: res.points,
          name: res.name ?? fileName,
          errorMessage: res.errorMessage,
        );
      } else {
        final res = parseCsv(content);
        return ImportResult(
          success: res.success,
          points: res.points,
          name: res.name ?? fileName,
          errorMessage: res.errorMessage,
        );
      }
    } catch (e) {
      return ImportResult(success: false, points: [], errorMessage: 'Import failed: $e');
    }
  }

  static ImportResult parseGeoJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      List<dynamic> coords = [];
      String name = 'Imported Field';

      if (data['type'] == 'FeatureCollection' && data['features'] is List && data['features'].isNotEmpty) {
        final f = data['features'][0];
        name = f['properties']?['name'] ?? name;
        if (f['geometry']?['type'] == 'Polygon') {
          coords = f['geometry']['coordinates'][0];
        }
      } else if (data['type'] == 'Feature') {
        name = data['properties']?['name'] ?? name;
        if (data['geometry']?['type'] == 'Polygon') {
          coords = data['geometry']['coordinates'][0];
        }
      } else if (data['type'] == 'Polygon') {
        coords = data['coordinates'][0];
      }

      if (coords.length < 3) {
        return const ImportResult(success: false, points: [], errorMessage: 'Fewer than 3 coordinates found in polygon');
      }

      final points = coords.map<GeoPoint>((c) {
        return GeoPoint(
          longitude: (c[0] as num).toDouble(),
          latitude: (c[1] as num).toDouble(),
          altitude: c.length > 2 ? (c[2] as num).toDouble() : null,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          accuracy: null, // Unknown! Never fabricate fake accuracy (Section 44).
        );
      }).toList();

      if (points.length > 3 &&
          points.first.latitude == points.last.latitude &&
          points.first.longitude == points.last.longitude) {
        points.removeLast();
      }

      final val = PolygonValidator.validate(points);
      if (!val.isValid) {
        return ImportResult(success: false, points: [], errorMessage: val.errorMessage);
      }

      return ImportResult(success: true, points: points, name: name);
    } catch (e) {
      return ImportResult(success: false, points: [], errorMessage: 'Invalid GeoJSON: $e');
    }
  }

  static ImportResult parseKml(String kmlString) {
    try {
      final coordMatch = RegExp(r'<coordinates>([\s\S]*?)<\/coordinates>', caseSensitive: false).firstMatch(kmlString);
      if (coordMatch == null) {
        return const ImportResult(success: false, points: [], errorMessage: 'No <coordinates> tag found in KML');
      }

      String name = 'Imported KML Field';
      final nameMatch = RegExp(r'<name>([\s\S]*?)<\/name>', caseSensitive: false).firstMatch(kmlString);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim() ?? name;
      }

      final rawCoords = coordMatch.group(1)!.trim().split(RegExp(r'\s+'));
      final List<GeoPoint> points = [];

      for (final chunk in rawCoords) {
        final parts = chunk.split(',');
        if (parts.length >= 2) {
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          final alt = parts.length > 2 ? double.tryParse(parts[2]) : null;

          if (lat != null && lon != null) {
            points.add(GeoPoint(
              latitude: lat,
              longitude: lon,
              altitude: alt,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              accuracy: null, // Never fabricate fake accuracy
            ));
          }
        }
      }

      if (points.length > 3 &&
          points.first.latitude == points.last.latitude &&
          points.first.longitude == points.last.longitude) {
        points.removeLast();
      }

      if (points.length < 3) {
        return const ImportResult(success: false, points: [], errorMessage: 'Fewer than 3 valid coordinates in KML');
      }

      final val = PolygonValidator.validate(points);
      if (!val.isValid) {
        return ImportResult(success: false, points: [], errorMessage: val.errorMessage);
      }

      return ImportResult(success: true, points: points, name: name);
    } catch (e) {
      return ImportResult(success: false, points: [], errorMessage: 'Invalid KML: $e');
    }
  }

  static ImportResult parseCsv(String csvString) {
    try {
      final lines = csvString
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();

      if (lines.length < 3) {
        return const ImportResult(success: false, points: [], errorMessage: 'Fewer than 3 lines in CSV');
      }

      int startIdx = 0;
      final header = lines[0].toLowerCase();
      if (header.contains('lat') || header.contains('lon')) {
        startIdx = 1;
      }

      final List<GeoPoint> points = [];
      for (int i = startIdx; i < lines.length; i++) {
        final parts = lines[i].split(',').map((p) => p.trim()).toList();
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[parts.length >= 3 ? 1 : 0]);
          final lon = double.tryParse(parts[parts.length >= 3 ? 2 : 1]);
          if (lat != null && lon != null) {
            points.add(GeoPoint(
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              accuracy: null,
            ));
          }
        }
      }

      if (points.length < 3) {
        return const ImportResult(success: false, points: [], errorMessage: 'Fewer than 3 valid coordinates in CSV');
      }

      final val = PolygonValidator.validate(points);
      if (!val.isValid) {
        return ImportResult(success: false, points: [], errorMessage: val.errorMessage);
      }

      return ImportResult(success: true, points: points, name: 'Imported CSV Field');
    } catch (e) {
      return ImportResult(success: false, points: [], errorMessage: 'Invalid CSV: $e');
    }
  }
}
