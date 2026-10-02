import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cross_file/cross_file.dart';
import '../models/field_model.dart';
import '../core/constants.dart';
import '../core/units.dart';
import '../gis/geodesic_calculator.dart';

class ExportService {
  static XFile exportGeoJson(FieldModel field) {
    final coordinates = field.finalPolygon.map((p) => [p.longitude, p.latitude]).toList();
    if (coordinates.isNotEmpty) {
      final first = coordinates.first;
      final last = coordinates.last;
      if (first[0] != last[0] || first[1] != last[1]) {
        coordinates.add([first[0], first[1]]);
      }
    }

    final features = <Map<String, dynamic>>[
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
        'properties': {
          'id': field.id,
          'name': field.name,
          'type': 'final_polygon',
          'createdAt': field.createdAt,
          'measurementMode': field.measurementMode.name,
          'areaSqMeters': field.areaSqMeters,
          'perimeterMeters': field.perimeterMeters,
          'primaryAreaUnit': field.primaryAreaUnit,
          'primaryDistanceUnit': field.primaryDistanceUnit,
          'region': field.region,
          'notes': field.notes ?? '',
        },
      }
    ];

    if (field.originalGpsPolygon != null && field.originalGpsPolygon!.length >= 3) {
      final origCoords = field.originalGpsPolygon!.map((p) => [p.longitude, p.latitude]).toList();
      if (origCoords.isNotEmpty) {
        origCoords.add([origCoords.first[0], origCoords.first[1]]);
      }
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [origCoords],
        },
        'properties': {
          'id': '${field.id}_original_gps',
          'name': '${field.name} (Original GPS)',
          'type': 'original_gps_polygon',
          'areaSqMeters': GeodesicCalculator.areaSqMeters(field.originalGpsPolygon!),
        },
      });
    }

    final data = {
      'type': 'FeatureCollection',
      'features': features,
    };
    final content = const JsonEncoder.withIndent('  ').convert(data);
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: _safeName(field.name, 'geojson'),
      mimeType: 'application/geo+json',
    );
  }

  static XFile exportJson(FieldModel field) {
    final content = const JsonEncoder.withIndent('  ').convert(field.toJson());
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: _safeName(field.name, 'json'),
      mimeType: 'application/json',
    );
  }

  static XFile exportKml(FieldModel field) {
    final finalCoordsBuffer = StringBuffer();
    for (final p in field.finalPolygon) {
      finalCoordsBuffer.writeln('${p.longitude},${p.latitude},${p.altitude ?? 0}');
    }
    if (field.finalPolygon.isNotEmpty) {
      final p0 = field.finalPolygon.first;
      finalCoordsBuffer.writeln('${p0.longitude},${p0.latitude},${p0.altitude ?? 0}');
    }

    String origSection = '';
    if (field.originalGpsPolygon != null && field.originalGpsPolygon!.length >= 3) {
      final origCoordsBuffer = StringBuffer();
      for (final p in field.originalGpsPolygon!) {
        origCoordsBuffer.writeln('${p.longitude},${p.latitude},${p.altitude ?? 0}');
      }
      origCoordsBuffer.writeln('${field.originalGpsPolygon!.first.longitude},${field.originalGpsPolygon!.first.latitude},0');

      origSection = '''
    <Placemark>
      <name>${field.name} (Original GPS)</name>
      <Style>
        <LineStyle>
          <color>ff00ffff</color>
          <width>2.5</width>
        </LineStyle>
        <PolyStyle>
          <color>3300ffff</color>
        </PolyStyle>
      </Style>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
$origCoordsBuffer
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>''';
    }

    final content = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>${field.name}</name>
    <description>Field boundary measured with Field Measure Pro.</description>
    <Placemark>
      <name>${field.name} (Final Adjusted Boundary)</name>
      <Style>
        <LineStyle>
          <color>ff00aa00</color>
          <width>3.5</width>
        </LineStyle>
        <PolyStyle>
          <color>5500ff00</color>
        </PolyStyle>
      </Style>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
$finalCoordsBuffer
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
$origSection
  </Document>
</kml>''';
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: _safeName(field.name, 'kml'),
      mimeType: 'application/vnd.google-earth.kml+xml',
    );
  }

  static XFile exportCsv(FieldModel field) {
    final buffer = StringBuffer();
    buffer.writeln('Index,Latitude,Longitude,Altitude,Accuracy_m,Segment_Dist_m');
    for (int i = 0; i < field.finalPolygon.length; i++) {
      final p = field.finalPolygon[i];
      double segDist = 0.0;
      if (i > 0) {
        segDist = GeodesicCalculator.distanceMeters(field.finalPolygon[i - 1], p);
      }
      buffer.writeln(
          '${i + 1},${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)},${p.altitude ?? ""},${p.accuracy?.toStringAsFixed(1) ?? "Unknown"},${segDist.toStringAsFixed(2)}');
    }
    buffer.writeln('# Total Area m2: ${field.areaSqMeters}');
    buffer.writeln('# Total Perimeter m: ${field.perimeterMeters}');
    buffer.writeln('# Primary Unit: ${field.primaryAreaUnit}');
    buffer.writeln('# Region: ${field.region}');
    buffer.writeln('# Notes: ${field.notes ?? ""}');
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      name: _safeName(field.name, 'csv'),
      mimeType: 'text/csv',
    );
  }

  static Future<XFile> generatePdfReport(FieldModel field) async {
    final pdf = pw.Document();

    double? originalArea;
    if (field.originalGpsPolygon != null && field.originalGpsPolygon!.length >= 3) {
      originalArea = GeodesicCalculator.areaSqMeters(field.originalGpsPolygon!);
    }

    // Compute bounding box for diagram scaling
    final pts = field.finalPolygon;
    double minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final double spanLat = (maxLat - minLat).abs();
    final double spanLon = (maxLon - minLon).abs();
    final double maxSpan = math.max(spanLat, spanLon);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          // Build conversion text from saved field's snapshot and custom unit without hard-coded fallbacks
          final List<String> convEquivs = [];
          final customName = field.customAreaUnitName ?? (field.conversionSnapshot?['customUnitName'] as String?);
          final customSqM = field.customAreaUnitSqMeters ?? ((field.conversionSnapshot?['customUnitSqMeters'] as num?)?.toDouble());
          if (customName != null && customSqM != null && customSqM > 0) {
            convEquivs.add('$customName: ${(field.areaSqMeters / customSqM).toStringAsFixed(3)} (1 unit = ${customSqM.toStringAsFixed(1)} m²)');
          }

          final snapshot = field.conversionSnapshot;
          final bighaSqM = (snapshot?['bighaSqMeters'] as num?)?.toDouble();
          if (bighaSqM != null && bighaSqM > 0) {
            convEquivs.add('Bigha: ${(field.areaSqMeters / bighaSqM).toStringAsFixed(3)} (1 Bigha = ${bighaSqM.toStringAsFixed(1)} m²)');
          }
          final biswaSqM = (snapshot?['biswaSqMeters'] as num?)?.toDouble();
          if (biswaSqM != null && biswaSqM > 0) {
            convEquivs.add('Biswa: ${(field.areaSqMeters / biswaSqM).toStringAsFixed(2)}');
          }
          final kanalSqM = (snapshot?['kanalSqMeters'] as num?)?.toDouble();
          if (kanalSqM != null && kanalSqM > 0) {
            convEquivs.add('Kanal: ${(field.areaSqMeters / kanalSqM).toStringAsFixed(3)}');
          }
          final marlaSqM = (snapshot?['marlaSqMeters'] as num?)?.toDouble();
          if (marlaSqM != null && marlaSqM > 0) {
            convEquivs.add('Marla: ${(field.areaSqMeters / marlaSqM).toStringAsFixed(2)}');
          }

          final String convDisplayText = convEquivs.isNotEmpty
              ? convEquivs.join('  ·  ')
              : 'Conversion unavailable for this historical record (no snapshot recorded).';

          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('166534'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              width: double.infinity,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        AppConstants.appName.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        AppConstants.appTagline,
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Text(
                    'FIELD REPORT',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('4ade80'),
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Field Meta
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Field: ${field.name}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'Date: ${DateTime.fromMillisecondsSinceEpoch(field.createdAt).toLocal().toString().split(".")[0]}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('f1f5f9'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Text(
                    'Mode: ${field.measurementMode.name.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Primary Metrics Grid
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  width: 155,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FINAL CALCULATED AREA',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        UnitSettings.formatArea(field.areaSqMeters, unit: field.primaryAreaUnit),
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('166534')),
                      ),
                      pw.Text('${(field.areaSqMeters / 10000.0).toStringAsFixed(3)} Hectares', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${field.areaSqMeters.toStringAsFixed(1)} m²', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  width: 155,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PERIMETER & VERTICES',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        UnitSettings.formatPerimeter(field.perimeterMeters, unit: field.primaryDistanceUnit),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('${field.finalPolygon.length} boundary points', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Model: WGS84 Authalic Sphere Estimate', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  width: 155,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GPS REPORTED ACCURACY',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        field.gpsStats?.averageAccuracy != null
                            ? '±${field.gpsStats!.averageAccuracy!.toStringAsFixed(1)} m'
                            : 'Unknown / Map Draw',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Accepted: ${field.gpsStats?.acceptedPoints ?? field.finalPolygon.length} pts',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Filtered: ${field.gpsStats?.rejectedPoints ?? 0} pts',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // GPS + Adjust Comparison Box if applicable
            if (originalArea != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('fef3c7'),
                  border: pw.Border.all(color: PdfColor.fromHex('f59e0b')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Original GPS Area: ${UnitSettings.formatArea(originalArea)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Adjusted Area: ${UnitSettings.formatArea(field.areaSqMeters)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'Diff: ${field.areaSqMeters >= originalArea ? "+" : ""}${((field.areaSqMeters - originalArea) / 4046.856).toStringAsFixed(2)} ac',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('b45309')),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Boundary Visualization Diagram (Section 46)
            pw.Text('BOUNDARY VISUALIZATION',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            pw.Container(
              height: 160,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('f8fafc'),
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.CustomPaint(
                painter: (canvas, size) {
                  if (pts.length < 3 || maxSpan <= 0) return;
                  final double pad = 24.0;
                  final double w = size.x - pad * 2;
                  final double h = size.y - pad * 2;

                  final normalizedPoints = pts.map((p) {
                    final double nx = pad + ((p.longitude - minLon) / maxSpan) * w;
                    // Invert latitude for vertical screen coordinate
                    final double ny = pad + ((maxLat - p.latitude) / maxSpan) * h;
                    return PdfPoint(nx, ny);
                  }).toList();

                  // Fill polygon
                  canvas.setFillColor(PdfColor.fromHex('dcfce7'));
                  canvas.moveTo(normalizedPoints.first.x, normalizedPoints.first.y);
                  for (int i = 1; i < normalizedPoints.length; i++) {
                    canvas.lineTo(normalizedPoints[i].x, normalizedPoints[i].y);
                  }
                  canvas.closePath();
                  canvas.fillPath();

                  // Stroke boundary
                  canvas.setStrokeColor(PdfColor.fromHex('16a34a'));
                  canvas.setLineWidth(2.0);
                  canvas.moveTo(normalizedPoints.first.x, normalizedPoints.first.y);
                  for (int i = 1; i < normalizedPoints.length; i++) {
                    canvas.lineTo(normalizedPoints[i].x, normalizedPoints[i].y);
                  }
                  canvas.closePath();
                  canvas.strokePath();

                  // Draw vertex dots
                  canvas.setFillColor(PdfColor.fromHex('15803d'));
                  for (final p in normalizedPoints) {
                    canvas.drawEllipse(p.x, p.y, 2.5, 2.5);
                    canvas.fillPath();
                  }
                },
              ),
            ),
            pw.SizedBox(height: 14),

            // Regional Equivalences Box (Section 22: read from saved field snapshot, no hard-coding)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('f1f5f9'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Regional Land Unit Equivalences (${field.region})',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    convDisplayText,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Notice: Local land-unit definitions may vary by district or local revenue practice. Verify the applicable conversion before legal, financial, or property transactions.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            if (field.notes != null && field.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Field Notes: ${field.notes}',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            ],
            pw.SizedBox(height: 14),

            // Coordinate Table (Sample up to 10 points)
            pw.Text('COORDINATE SAMPLES (WGS84)',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('e2e8f0')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('#', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Latitude', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Longitude', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Accuracy', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...field.finalPolygon.take(8).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pt = entry.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pt.latitude.toStringAsFixed(6), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pt.longitude.toStringAsFixed(6), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pt.accuracy != null ? '±${pt.accuracy!.toStringAsFixed(1)}m' : 'Unknown', style: const pw.TextStyle(fontSize: 7))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Mandatory Disclaimer (Section 23 & 47)
            pw.Divider(),
            pw.Text(
              'DISCLAIMER: GPS/map-based measurements are estimates and should not be treated as a legally certified land survey. This document is generated for informational and agricultural planning purposes only.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    return XFile.fromData(
      bytes,
      name: _safeName(field.name, 'pdf', suffix: '_report'),
      mimeType: 'application/pdf',
    );
  }

  static String _safeName(String value, String extension, {String suffix = ''}) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final base = sanitized.isEmpty ? 'field' : sanitized;
    return '$base$suffix.$extension';
  }
}
