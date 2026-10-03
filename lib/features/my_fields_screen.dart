import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/field_model.dart';
import '../models/geo_point.dart';
import '../database/app_database.dart';
import '../core/units.dart';
import '../export/export_service.dart';
import 'field_result_screen.dart';
import 'boundary_editor_screen.dart';
import 'map_draw_screen.dart';
import 'gps_walk_screen.dart';

enum FieldSortOption { newest, oldest, largest, smallest, recentlyModified }

class MyFieldsScreen extends StatefulWidget {
  const MyFieldsScreen({super.key});

  @override
  State<MyFieldsScreen> createState() => _MyFieldsScreenState();
}

class _MyFieldsScreenState extends State<MyFieldsScreen> {
  List<FieldModel> _fields = [];
  bool _isLoading = true;
  String _searchQuery = '';
  FieldSortOption _sortOption = FieldSortOption.newest;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  void _loadFields() async {
    final fields = await AppDatabase.getAllFields();
    if (mounted) {
      setState(() {
        _fields = fields;
        _isLoading = false;
      });
    }
  }

  void _deleteField(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Field', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$name"? This cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.deleteField(id);
      _loadFields();
    }
  }

  void _renameField(FieldModel field) async {
    final controller = TextEditingController(text: field.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Field', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Field Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != field.name) {
      final updated = FieldModel(
        id: field.id,
        name: newName,
        createdAt: field.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        measurementMode: field.measurementMode,
        originalGpsPolygon: field.originalGpsPolygon,
        finalPolygon: field.finalPolygon,
        areaSqMeters: field.areaSqMeters,
        perimeterMeters: field.perimeterMeters,
        primaryAreaUnit: field.primaryAreaUnit,
        primaryDistanceUnit: field.primaryDistanceUnit,
        region: field.region,
        gpsStats: field.gpsStats,
        notes: field.notes,
        metadata: field.metadata,
        customAreaUnitName: field.customAreaUnitName,
        customAreaUnitSqMeters: field.customAreaUnitSqMeters,
        conversionSnapshot: field.conversionSnapshot,
      );
      await AppDatabase.insertOrUpdateField(updated);
      _loadFields();
    }
  }

  void _duplicateField(FieldModel field) async {
    final duplicate = FieldModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${field.name} Copy',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      measurementMode: field.measurementMode,
      originalGpsPolygon: field.originalGpsPolygon != null ? List.from(field.originalGpsPolygon!) : null,
      finalPolygon: List.from(field.finalPolygon),
      areaSqMeters: field.areaSqMeters,
      perimeterMeters: field.perimeterMeters,
      primaryAreaUnit: field.primaryAreaUnit,
      primaryDistanceUnit: field.primaryDistanceUnit,
      region: field.region,
      gpsStats: field.gpsStats,
      notes: field.notes,
      metadata: field.metadata,
      customAreaUnitName: field.customAreaUnitName,
      customAreaUnitSqMeters: field.customAreaUnitSqMeters,
      conversionSnapshot: field.conversionSnapshot,
    );
    await AppDatabase.insertOrUpdateField(duplicate);
    _loadFields();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created duplicate: "${duplicate.name}"'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  void _exportField(FieldModel field) {
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
              Text('EXPORT "${field.name}"',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('Export PDF Report', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.generatePdfReport(field);
                  await Share.shareXFiles([file], text: '${field.name} PDF');
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.greenAccent),
                title: const Text('Export GeoJSON', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportGeoJson(field);
                  await Share.shareXFiles([file], text: '${field.name} GeoJSON');
                },
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.amberAccent),
                title: const Text('Export KML (Google Earth)', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportKml(field);
                  await Share.shareXFiles([file], text: '${field.name} KML');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.blueAccent),
                title: const Text('Export CSV (Coordinates)', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await ExportService.exportCsv(field);
                  await Share.shareXFiles([file], text: '${field.name} CSV');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<FieldModel> get _filteredAndSortedFields {
    List<FieldModel> list = List.from(_fields);

    // Search filter (Section 39)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q) || (f.notes?.toLowerCase().contains(q) ?? false)).toList();
    }

    // Sort (Section 39)
    switch (_sortOption) {
      case FieldSortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case FieldSortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case FieldSortOption.largest:
        list.sort((a, b) => b.areaSqMeters.compareTo(a.areaSqMeters));
        break;
      case FieldSortOption.smallest:
        list.sort((a, b) => a.areaSqMeters.compareTo(b.areaSqMeters));
        break;
      case FieldSortOption.recentlyModified:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayFields = _filteredAndSortedFields;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('MY FIELDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Column(
        children: [
          // Search & Sort Bar (Section 39)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search fields by name...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<FieldSortOption>(
                  icon: const Icon(Icons.sort, color: Color(0xFF4ADE80)),
                  tooltip: 'Sort Fields',
                  color: const Color(0xFF1E293B),
                  onSelected: (opt) => setState(() => _sortOption = opt),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: FieldSortOption.newest, child: Text('Newest First')),
                    const PopupMenuItem(value: FieldSortOption.oldest, child: Text('Oldest First')),
                    const PopupMenuItem(value: FieldSortOption.largest, child: Text('Largest Area')),
                    const PopupMenuItem(value: FieldSortOption.smallest, child: Text('Smallest Area')),
                    const PopupMenuItem(value: FieldSortOption.recentlyModified, child: Text('Recently Modified')),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayFields.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.layers_outlined, size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No measurements yet.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 20),
                            // Section 76: Empty state action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MapDrawScreen()))
                                        .then((_) => _loadFields());
                                  },
                                  icon: const Icon(Icons.gesture, size: 16),
                                  label: const Text('DRAW A FIELD'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GpsWalkScreen()))
                                        .then((_) => _loadFields());
                                  },
                                  icon: const Icon(Icons.directions_walk, size: 16),
                                  label: const Text('WALK A FIELD'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayFields.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final field = displayFields[index];
                          final date = DateTime.fromMillisecondsSinceEpoch(field.createdAt);

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              // Section 79: Lightweight polygon preview thumbnail
                              leading: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: CustomPaint(
                                  painter: MiniPolygonPreviewPainter(points: field.finalPolygon),
                                ),
                              ),
                              title: Text(
                                field.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(
                                    '${UnitSettings.formatAreaWithSnapshot(sqMeters: field.areaSqMeters, unit: field.primaryAreaUnit, customName: field.customAreaUnitName, customSqMeters: field.customAreaUnitSqMeters, region: field.region)}  ·  ${UnitSettings.formatPerimeter(field.perimeterMeters, unit: field.primaryDistanceUnit)}',
                                    style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${date.day}/${date.month}/${date.year}  ·  ${field.finalPolygon.length} pts  ·  ${field.measurementMode.name.toUpperCase()}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                                    tooltip: 'Edit Boundary',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BoundaryEditorScreen(
                                            initialPoints: field.finalPolygon,
                                            originalGpsPoints: field.originalGpsPolygon,
                                            mode: field.measurementMode,
                                            gpsStats: field.gpsStats,
                                            existingField: field,
                                          ),
                                        ),
                                      ).then((_) => _loadFields());
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                    color: const Color(0xFF1E293B),
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'rename':
                                          _renameField(field);
                                          break;
                                        case 'duplicate':
                                          _duplicateField(field);
                                          break;
                                        case 'export':
                                          _exportField(field);
                                          break;
                                        case 'delete':
                                          _deleteField(field.id, field.name);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                      const PopupMenuItem(value: 'export', child: Text('Export / Share')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FieldResultScreen(
                                      points: field.finalPolygon,
                                      originalGpsPoints: field.originalGpsPolygon,
                                      mode: field.measurementMode,
                                      gpsStats: field.gpsStats,
                                      existingField: field,
                                    ),
                                  ),
                                ).then((_) => _loadFields());
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Section 79: Lightweight Polygon Preview Painter for Saved Field Cards
class MiniPolygonPreviewPainter extends CustomPainter {
  final List<GeoPoint> points;
  MiniPolygonPreviewPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;

    double minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final double spanLat = (maxLat - minLat).abs();
    final double spanLon = (maxLon - minLon).abs();
    final double maxSpan = math.max(spanLat, spanLon);
    if (maxSpan <= 0) return;

    final double pad = 8.0;
    final double w = size.width - pad * 2;
    final double h = size.height - pad * 2;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final double x = pad + ((p.longitude - minLon) / maxSpan) * w;
      final double y = pad + ((maxLat - p.latitude) / maxSpan) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = const Color(0x3322C55E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant MiniPolygonPreviewPainter oldDelegate) => false;
}
