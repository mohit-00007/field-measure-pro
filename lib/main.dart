import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants.dart';
import 'core/units.dart';
import 'models/field_model.dart';
import 'models/geo_point.dart';
import 'database/app_database.dart';
import 'features/gps_walk_screen.dart';
import 'features/map_draw_screen.dart';
import 'features/boundary_editor_screen.dart';
import 'features/field_result_screen.dart';
import 'features/my_fields_screen.dart';
import 'features/settings_screen.dart';
import 'import/import_service.dart';
import 'payments/entitlement_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  UnitSettings.onSettingChanged = AppDatabase.saveSetting;
  UnitSettings.settingsLoader = AppDatabase.getAllSettings;
  await UnitSettings.loadFromDatabase();
  runApp(const FieldMeasureProApp());
}

class FieldMeasureProApp extends StatelessWidget {
  const FieldMeasureProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Measure Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorSchemeSeed: const Color(0xFF16A34A),
        useMaterial3: true,
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MyFieldsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // Windows Desktop Layout: LEFT SIDEBAR + CONTENT
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: const Color(0xFF0F172A),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _selectedIndex = idx;
                });
              },
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.terrain, color: Color(0xFF4ADE80), size: 32),
                    SizedBox(height: 4),
                    Text('FMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: Color(0xFF4ADE80)),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers, color: Color(0xFF4ADE80)),
                  label: Text('My Fields'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: Color(0xFF4ADE80)),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF334155)),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    }

    // Android Mobile Layout: BOTTOM NAVIGATION BAR
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF4ADE80),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'My Fields'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FieldModel> _recentFields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _checkCrashRecovery();
  }

  void _loadRecent() async {
    final all = await AppDatabase.getAllFields();
    if (mounted) {
      setState(() {
        _recentFields = all.take(3).toList();
        _isLoading = false;
      });
    }
  }

  // Section 28 & 29: State-specific session recovery
  void _checkCrashRecovery() async {
    final draft = await AppDatabase.getActiveDraft();
    if (!mounted || draft == null) return;

    final rawPoints = draft['points'] as List?;
    if (rawPoints == null || rawPoints.isEmpty) return;

    final points = rawPoints
        .map((p) => GeoPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    List<GeoPoint>? originalGpsPoints;
    if (draft['originalGpsPoints'] != null) {
      originalGpsPoints = (draft['originalGpsPoints'] as List)
          .map((p) => GeoPoint.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    final modeString = draft['mode'] as String? ?? 'mapDraw';
    final mode = MeasurementMode.values.byName(modeString);
    final sessionState = draft['state'] as String? ?? 'EDITING';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Color(0xFF4ADE80)),
            SizedBox(width: 8),
            Text('Unfinished measurement found',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'An unfinished session ($sessionState) with ${points.length} points was found. Would you like to resume it?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppDatabase.clearActiveDraft();
            },
            child: const Text('DISCARD', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);

              // Route correctly according to Session State (Section 29)
              Widget destination;
              if (sessionState == 'TRACKING') {
                destination = GpsWalkScreen(
                  initialPoints: points,
                  isGpsAdjustMode: mode == MeasurementMode.gpsAdjust,
                );
              } else if (sessionState == 'PAUSED') {
                destination = GpsWalkScreen(
                  initialPoints: points,
                  isGpsAdjustMode: mode == MeasurementMode.gpsAdjust,
                  resumeAsPaused: true,
                );
              } else if (sessionState == 'READY_TO_SAVE') {
                destination = FieldResultScreen(
                  points: points,
                  originalGpsPoints: originalGpsPoints,
                  mode: mode,
                );
              } else {
                destination = BoundaryEditorScreen(
                  initialPoints: points,
                  originalGpsPoints: originalGpsPoints,
                  mode: mode,
                );
              }

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              ).then((_) => _loadRecent());
            },
            child: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Section 42: Real File Picker Workflow for Import
  void _pickAndImportFile() async {
    final result = await ImportService.pickAndImportFile();
    if (!mounted) return;

    if (result.success && result.points.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BoundaryEditorScreen(
            initialPoints: result.points,
            mode: MeasurementMode.imported,
          ),
        ),
      ).then((_) => _loadRecent());
    } else if (result.errorMessage != null && result.errorMessage != 'File selection cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'IMPORT FIELD BOUNDARY',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a file from your device storage (KML, GeoJSON, CSV, or JSON).',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickAndImportFile();
                },
                icon: const Icon(Icons.folder_open, size: 20),
                label: const Text('SELECT FILE FROM STORAGE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showTextPasteDialog();
                },
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('PASTE COORDINATE TEXT MANUALLY'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTextPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Paste Boundary Data', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          maxLines: 6,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Paste GeoJSON, KML, or CSV lines here...',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              Navigator.pop(ctx);
              final input = textController.text.trim();
              final ImportResult result;
              if (input.startsWith('{')) {
                result = ImportService.parseGeoJson(input);
              } else if (input.contains('<kml') || input.contains('<coordinates>')) {
                result = ImportService.parseKml(input);
              } else {
                result = ImportService.parseCsv(input);
              }

              if (result.success && result.points.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BoundaryEditorScreen(
                      initialPoints: result.points,
                      mode: MeasurementMode.imported,
                    ),
                  ),
                ).then((_) => _loadRecent());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? 'Invalid format.')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                AppConstants.appTagline,
                style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // 1. GPS WALK
              _buildLargeButton(
                context,
                title: 'GPS WALK',
                subtitle: 'Walk field perimeter with real-time GPS tracking',
                color: const Color(0xFF16A34A),
                icon: Icons.directions_walk,
                onPressed: () async {
                  if (!await EntitlementService.ensureAccess(context)) return;
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const GpsWalkScreen())).then((_) => _loadRecent());
                },
              ),
              const SizedBox(height: 14),

              // 2. DRAW ON MAP
              _buildLargeButton(
                context,
                title: 'DRAW ON MAP',
                subtitle: 'Freehand finger trace or point-by-point tap',
                color: const Color(0xFF1E293B),
                icon: Icons.gesture,
                onPressed: () async {
                  if (!await EntitlementService.ensureAccess(context)) return;
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MapDrawScreen())).then((_) => _loadRecent());
                },
              ),
              const SizedBox(height: 14),

              // 3. GPS + ADJUST
              _buildLargeButton(
                context,
                title: 'GPS + ADJUST',
                subtitle: 'Walk with GPS then drag & fine-tune vertices',
                color: const Color(0xFFD97706),
                icon: Icons.tune,
                onPressed: () async {
                  if (!await EntitlementService.ensureAccess(context)) return;
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const GpsWalkScreen(isGpsAdjustMode: true))).then((_) => _loadRecent());
                },
              ),
              const SizedBox(height: 14),

              // 4. MY FIELDS
              _buildLargeButton(
                context,
                title: 'MY FIELDS',
                subtitle: 'View saved field boundaries & export reports',
                color: const Color(0xFF0F172A),
                icon: Icons.layers,
                isSecondary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyFieldsScreen()),
                  ).then((_) => _loadRecent());
                },
              ),
              const SizedBox(height: 16),

              // Secondary: Import (Section 42)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_upload, size: 18),
                label: const Text('IMPORT FILE (KML / GEOJSON / CSV)'),
              ),
              const SizedBox(height: 24),

              // Recent Measurements
              const Text(
                'RECENT MEASUREMENTS',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_recentFields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155), style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Text('No measurements yet.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ..._recentFields.map((field) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: InkWell(
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
                        ).then((_) => _loadRecent());
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(
                                '${UnitSettings.formatArea(field.areaSqMeters, unit: field.primaryAreaUnit)}  ·  ${field.finalPolygon.length} pts',
                                style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 12),
                              ),
                            ],
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
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
      ),
    );
  }

  Widget _buildLargeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSecondary ? const BorderSide(color: Color(0xFF334155)) : BorderSide.none,
        ),
        elevation: isSecondary ? 0 : 3,
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }
}
