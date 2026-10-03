import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/geo_point.dart';
import '../models/field_model.dart';
import '../gis/geodesic_calculator.dart';
import '../core/units.dart';
import '../core/constants.dart';
import '../database/app_database.dart';
import '../export/export_service.dart';
import '../payments/entitlement_service.dart';
import 'boundary_editor_screen.dart';

class FieldResultScreen extends StatefulWidget {
  final List<GeoPoint> points;
  final List<GeoPoint>? originalGpsPoints;
  final MeasurementMode mode;
  final GpsAccuracyStats? gpsStats;
  final FieldModel? existingField;

  const FieldResultScreen({
    super.key,
    required this.points,
    this.originalGpsPoints,
    required this.mode,
    this.gpsStats,
    this.existingField,
  });

  @override
  State<FieldResultScreen> createState() => _FieldResultScreenState();
}

class _FieldResultScreenState extends State<FieldResultScreen> {
  late double _area;
  late double _perimeter;
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _area = GeodesicCalculator.areaSqMeters(widget.points);
    _perimeter = GeodesicCalculator.perimeterMeters(widget.points);

    _nameController = TextEditingController(
      text: widget.existingField?.name ??
          'Field ${DateTime.now().day}/${DateTime.now().month}',
    );
    _notesController =
        TextEditingController(text: widget.existingField?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  FieldModel _buildFieldModel() {
    final existing = widget.existingField;

    return FieldModel(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Field'
          : _nameController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      measurementMode: widget.mode,
      originalGpsPolygon: widget.originalGpsPoints,
      finalPolygon: widget.points,
      areaSqMeters: _area,
      perimeterMeters: _perimeter,
      primaryAreaUnit: existing?.primaryAreaUnit ?? UnitSettings.primaryAreaUnit,
      primaryDistanceUnit: existing?.primaryDistanceUnit ?? UnitSettings.primaryDistanceUnit,
      region: existing?.region ?? UnitSettings.selectedRegionName,
      gpsStats: widget.gpsStats,
      notes: _notesController.text.trim(),
      customAreaUnitName: existing?.customAreaUnitName ?? UnitSettings.customUnit?.name,
      customAreaUnitSqMeters: existing?.customAreaUnitSqMeters ?? UnitSettings.customUnit?.sqMeters,
      conversionSnapshot: existing?.conversionSnapshot ?? {
        'primaryAreaUnit': UnitSettings.primaryAreaUnit,
        'primaryDistanceUnit': UnitSettings.primaryDistanceUnit,
        'region': UnitSettings.selectedRegionName,
        'customUnitName': UnitSettings.customUnit?.name,
        'customUnitSqMeters': UnitSettings.customUnit?.sqMeters,
        'bighaSqMeters': UnitSettings.activePreset?.bighaSqMeters,
        'biswaSqMeters': UnitSettings.activePreset?.biswaSqMeters,
        'kanalSqMeters': UnitSettings.activePreset?.kanalSqMeters,
        'marlaSqMeters': UnitSettings.activePreset?.marlaSqMeters,
      },
    );
  }

  void _saveField() async {
    final field = _buildFieldModel();
    await AppDatabase.insertOrUpdateField(field);

    // Consume the one-time free measurement only after a successful save.
    // Editing an existing field does not count as a new measurement.
    if (widget.existingField == null && !await EntitlementService.trialUsed()) {
      await EntitlementService.consumeTrial();
    }

    // Section 30: Clear active draft after successful save
    await AppDatabase.clearActiveDraft();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Field saved successfully to SQLite database.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _editBoundaryAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BoundaryEditorScreen(
          initialPoints: widget.points,
          originalGpsPoints: widget.originalGpsPoints,
          mode: widget.mode,
          gpsStats: widget.gpsStats,
          existingField: widget.existingField,
        ),
      ),
    );
  }

  void _exportShare() async {
    final field = _buildFieldModel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('EXPORT & SHARE MEASUREMENT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('Export PDF Report',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Includes field overview, perimeter & map table',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.generatePdfReport(field);
                  await Share.shareXFiles([file],
                      text: 'Field Measure Pro - ${field.name} PDF');
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.greenAccent),
                title: const Text('Export GeoJSON',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportGeoJson(field);
                  await Share.shareXFiles([file],
                      text: 'Field Measure Pro - ${field.name} GeoJSON');
                },
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.amberAccent),
                title: const Text('Export KML (Google Earth)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportKml(field);
                  await Share.shareXFiles([file],
                      text: 'Field Measure Pro - ${field.name} KML');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.blueAccent),
                title: const Text('Export CSV (Coordinates)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportCsv(field);
                  await Share.shareXFiles([file],
                      text: 'Field Measure Pro - ${field.name} CSV');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double? originalArea;
    if (widget.originalGpsPoints != null &&
        widget.originalGpsPoints!.length >= 3) {
      originalArea = GeodesicCalculator.areaSqMeters(widget.originalGpsPoints!);
    }

    final activePreset = UnitSettings.activePreset;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('FIELD MEASURED',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.amberAccent),
            tooltip: 'Edit Boundary',
            onPressed: _editBoundaryAgain,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export & Share',
            onPressed: _exportShare,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name Input
            TextField(
              controller: _nameController,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'FIELD NAME',
                labelStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Metric Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  const Text('CALCULATED AREA',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    widget.existingField != null
                        ? UnitSettings.formatAreaWithSnapshot(
                            sqMeters: _area,
                            unit: widget.existingField!.primaryAreaUnit,
                            customName: widget.existingField!.customAreaUnitName,
                            customSqMeters: widget.existingField!.customAreaUnitSqMeters,
                            region: widget.existingField!.region,
                          )
                        : UnitSettings.formatArea(_area),
                    style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('PERIMETER',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            UnitSettings.formatPerimeter(_perimeter),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('POINTS',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.points.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('MODE',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            widget.mode.name.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 16: GPS + Adjust Baseline Comparison Card
            if (originalArea != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD97706)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune, color: Color(0xFFFBBF24), size: 18),
                        SizedBox(width: 8),
                        Text('GPS + ADJUST ANALYSIS',
                            style: TextStyle(
                                color: Color(0xFFFBBF24),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Original GPS Walk Area:',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(UnitSettings.formatArea(originalArea),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Final Adjusted Area:',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(UnitSettings.formatArea(_area),
                            style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Adjustment Difference:',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          '${_area >= originalArea ? "+" : ""}${((_area - originalArea) / 4046.856).toStringAsFixed(3)} ac (${(_area - originalArea).toStringAsFixed(1)} m²)',
                          style: TextStyle(
                              color: _area >= originalArea
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section 23: Regional Land-Unit Definition Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local land-unit definitions may vary by district or local revenue practice. '
                      'Verify the applicable conversion before legal, financial, or property transactions.',
                      style: TextStyle(color: Colors.amber, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Regional Equivalences
            if (activePreset != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGIONAL EQUIVALENCES (${activePreset.name.toUpperCase()})',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildRow('Bigha',
                        '${(_area / activePreset.bighaSqMeters).toStringAsFixed(3)} Bigha'),
                    _buildRow('Biswa',
                        '${(_area / activePreset.biswaSqMeters).toStringAsFixed(2)} Biswa'),
                    _buildRow('Kanal',
                        '${(_area / activePreset.kanalSqMeters).toStringAsFixed(3)} Kanal'),
                    _buildRow('Marla',
                        '${(_area / activePreset.marlaSqMeters).toStringAsFixed(2)} Marla'),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Notes Input
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'NOTES & REMARKS (OPTIONAL)',
                labelStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _saveField,
              icon: const Icon(Icons.save, size: 24),
              label: const Text(
                'SAVE FIELD MEASUREMENT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                AppConstants.surveyDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
