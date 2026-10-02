import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/geo_point.dart';
import '../models/field_model.dart';
import '../gis/geodesic_calculator.dart';
import '../core/units.dart';
import '../polygon_editor/polygon_editor_controller.dart';
import '../map/field_map_view.dart';
import '../database/app_database.dart';
import 'field_result_screen.dart';

class BoundaryEditorScreen extends StatefulWidget {
  final List<GeoPoint> initialPoints;
  final List<GeoPoint>? originalGpsPoints;
  final MeasurementMode mode;
  final GpsAccuracyStats? gpsStats;
  final FieldModel? existingField;

  const BoundaryEditorScreen({
    super.key,
    required this.initialPoints,
    this.originalGpsPoints,
    required this.mode,
    this.gpsStats,
    this.existingField,
  });

  @override
  State<BoundaryEditorScreen> createState() => _BoundaryEditorScreenState();
}

class _BoundaryEditorScreenState extends State<BoundaryEditorScreen> {
  late final PolygonEditorController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = PolygonEditorController(initialPoints: widget.initialPoints);
    _controller.addListener(_onControllerChanged);
    _persistDraft();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _persistDraft() {
    AppDatabase.saveActiveDraft(
      id: 'active_draft',
      mode: widget.mode.name,
      state: 'EDITING',
      points: _controller.points,
      originalGpsPoints: widget.originalGpsPoints,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirmFinalBoundary() {
    if (!_controller.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.validationError ?? 'Invalid boundary.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Persist draft as READY_TO_SAVE for FieldResultScreen
    AppDatabase.saveActiveDraft(
      id: 'active_draft',
      mode: widget.mode.name,
      state: 'READY_TO_SAVE',
      points: _controller.points,
      originalGpsPoints: widget.originalGpsPoints,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FieldResultScreen(
          points: _controller.points,
          originalGpsPoints: widget.originalGpsPoints,
          mode: widget.mode,
          gpsStats: widget.gpsStats,
          existingField: widget.existingField,
        ),
      ),
    );
  }

  void _deleteSelectedVertex() {
    final success = _controller.deleteSelectedVertex();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.validationError ?? 'Cannot delete vertex.'),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _persistDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double area = _controller.liveAreaSqMeters;
    final double perimeter = _controller.livePerimeterMeters;

    double? originalArea;
    if (widget.originalGpsPoints != null && widget.originalGpsPoints!.length >= 3) {
      originalArea = GeodesicCalculator.areaSqMeters(widget.originalGpsPoints!);
    }

    // Windows Desktop & Web Keyboard Shortcuts Map
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
        if (_controller.canUndo) {
          _controller.undo();
          _persistDraft();
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
        if (_controller.canRedo) {
          _controller.redo();
          _persistDraft();
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
        if (_controller.canRedo) {
          _controller.redo();
          _persistDraft();
        }
      },
      const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedVertex,
      const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelectedVertex,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        _controller.selectVertex(null);
      },
      const SingleActivator(LogicalKeyboardKey.enter): _confirmFinalBoundary,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const Text('BOUNDARY EDITOR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: const Color(0xFF0F172A),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: _controller.canUndo
                    ? () {
                        _controller.undo();
                        _persistDraft();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo (Ctrl+Y)',
                onPressed: _controller.canRedo
                    ? () {
                        _controller.redo();
                        _persistDraft();
                      }
                    : null,
              ),
            ],
          ),
          body: Stack(
            children: [
              // Authoritative Map Rendering
              FieldMapView(
                points: _controller.points,
                originalGpsPoints: widget.originalGpsPoints,
                mode: MapInteractionMode.editing,
                selectedVertexIndex: _controller.selectedVertexIndex,
                onVertexDragStart: (idx) {
                  _controller.beginMovingVertex(idx);
                },
                onVertexDrag: (idx, newPt) {
                  _controller.moveVertex(idx, newPt);
                },
                onVertexDragEnd: (idx) {
                  _controller.finishMovingVertex();
                  _persistDraft();
                },
                onVertexDragCancel: () {
                  _controller.cancelMovingVertex();
                },
                onMidpointInsert: (idx, midpoint) {
                  _controller.insertVertexAt(idx, midpoint);
                  _persistDraft();
                },
                onVertexSelected: (idx) {
                  _controller.selectVertex(idx);
                },
              ),

              // Live Metrics HUD Overlay (Updates in real time during drag)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xF20F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _controller.validationError != null
                          ? Colors.redAccent
                          : const Color(0xFF334155),
                      width: _controller.validationError != null ? 1.5 : 1.0,
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ADJUSTED AREA (LIVE)',
                                  style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                UnitSettings.formatArea(area),
                                style: TextStyle(
                                  color: _controller.validationError != null
                                      ? Colors.redAccent
                                      : const Color(0xFF4ADE80),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Perimeter: ${UnitSettings.formatPerimeter(perimeter)}  ·  ${_controller.points.length} vertices',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          if (originalArea != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('ORIGINAL GPS',
                                    style: TextStyle(
                                        color: Color(0xFFFBBF24),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  UnitSettings.formatArea(originalArea),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Diff: ${area >= originalArea ? "+" : ""}${((area - originalArea) / 4046.856).toStringAsFixed(2)} ac',
                                  style: TextStyle(
                                    color: area >= originalArea
                                        ? Colors.greenAccent
                                        : Colors.amberAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (_controller.validationError != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _controller.validationError!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Selected Vertex Context Menu
              if (_controller.selectedVertexIndex != null)
                Positioned(
                  top: 130,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF475569)),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Vertex #${_controller.selectedVertexIndex! + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          onPressed: _deleteSelectedVertex,
                          icon: const Icon(Icons.delete, size: 14),
                          label: const Text('Delete', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          tooltip: 'Deselect',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _controller.selectVertex(null),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Confirmation Bar
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _controller.isValid
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _controller.isValid ? _confirmFinalBoundary : null,
                  icon: const Icon(Icons.check, size: 24),
                  label: const Text('CONFIRM FINAL BOUNDARY',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
