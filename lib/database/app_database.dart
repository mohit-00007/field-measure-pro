import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/field_model.dart';
import '../models/geo_point.dart';

/// Cross-platform persistence layer.
/// Uses SharedPreferences so the same storage API works on Android, Windows,
/// and Flutter Web without dart:io or SQLite-only dependencies.
class AppDatabase {
  static const String _fieldsKey = 'field_measure_pro.fields.v2';
  static const String _draftKeyPrefix = 'field_measure_pro.draft.';
  static const String _settingsKey = 'field_measure_pro.settings.v1';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<List<FieldModel>> getAllFields() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_fieldsKey) ?? <String>[];
    final fields = <FieldModel>[];
    for (final item in raw) {
      try {
        fields.add(FieldModel.fromJson(
          jsonDecode(item) as Map<String, dynamic>,
        ));
      } catch (_) {
        // Ignore one corrupt record instead of preventing the library from loading.
      }
    }
    fields.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return fields;
  }

  static Future<FieldModel?> getFieldById(String id) async {
    final fields = await getAllFields();
    for (final field in fields) {
      if (field.id == id) return field;
    }
    return null;
  }

  static Future<void> insertOrUpdateField(FieldModel field) async {
    final prefs = await _prefs;
    final fields = await getAllFields();
    final index = fields.indexWhere((item) => item.id == field.id);
    if (index >= 0) {
      fields[index] = field;
    } else {
      fields.add(field);
    }
    fields.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await prefs.setStringList(
      _fieldsKey,
      fields.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> deleteField(String id) async {
    final prefs = await _prefs;
    final fields = await getAllFields();
    fields.removeWhere((field) => field.id == id);
    await prefs.setStringList(
      _fieldsKey,
      fields.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> saveActiveDraft({
    required String id,
    required String mode,
    String state = 'EDITING',
    required List<GeoPoint> points,
    List<GeoPoint>? originalGpsPoints,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final prefs = await _prefs;
      final draftData = <String, dynamic>{
        'id': id,
        'mode': mode,
        'state': state,
        'points': points.map((p) => p.toJson()).toList(),
        'originalGpsPoints': originalGpsPoints?.map((p) => p.toJson()).toList(),
        'extra': extra,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('$_draftKeyPrefix$id', jsonEncode(draftData));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getActiveDraft([
    String id = 'active_draft',
  ]) async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString('$_draftKeyPrefix$id');
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActiveDraft([
    String id = 'active_draft',
  ]) async {
    try {
      final prefs = await _prefs;
      await prefs.remove('$_draftKeyPrefix$id');
    } catch (_) {}
  }

  static Future<void> saveSetting(String key, String value) async {
    try {
      final prefs = await _prefs;
      final settings = <String, String>{
        ...(prefs.getString(_settingsKey) == null
            ? <String, String>{}
            : Map<String, String>.from(
                jsonDecode(prefs.getString(_settingsKey)!) as Map,
              )),
      };
      settings[key] = value;
      await prefs.setString(_settingsKey, jsonEncode(settings));
    } catch (_) {}
  }

  static Future<String?> getSetting(String key) async {
    final settings = await getAllSettings();
    return settings[key];
  }

  static Future<Map<String, String>> getAllSettings() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_settingsKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw) as Map;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }
}
