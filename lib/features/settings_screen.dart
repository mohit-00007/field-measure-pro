import 'package:flutter/material.dart';
import '../core/units.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedRegionId = UnitSettings.selectedRegionId;
  String _primaryAreaUnit = UnitSettings.primaryAreaUnit;
  String _primaryDistanceUnit = UnitSettings.primaryDistanceUnit;

  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customSqMetersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (UnitSettings.customUnit != null) {
      _customNameController.text = UnitSettings.customUnit!.name;
      _customSqMetersController.text = UnitSettings.customUnit!.sqMeters.toString();
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _customSqMetersController.dispose();
    super.dispose();
  }

  void _saveCustomUnit() {
    final name = _customNameController.text.trim();
    final sqMeters = double.tryParse(_customSqMetersController.text.trim());

    if (name.isEmpty || sqMeters == null || sqMeters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid unit name and square meter value (> 0).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      UnitSettings.setCustomUnit(name, sqMeters);
      _primaryAreaUnit = name;
      UnitSettings.primaryAreaUnit = name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Custom unit "$name" (1 unit = $sqMeters m²) saved.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  void _clearCustomUnit() {
    setState(() {
      UnitSettings.clearCustomUnit();
      _customNameController.clear();
      _customSqMetersController.clear();
      _primaryAreaUnit = 'Acres';
      UnitSettings.primaryAreaUnit = 'Acres';
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = UnitSettings.activePreset;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('SETTINGS & PREFERENCES',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Primary Area Unit Selection
          const Text(
            'PRIMARY AREA DISPLAY UNIT',
            style: TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _primaryAreaUnit,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                isExpanded: true,
                items: UnitSettings.availableAreaUnits.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _primaryAreaUnit = val;
                      UnitSettings.primaryAreaUnit = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Distance Unit Selection
          const Text(
            'PRIMARY DISTANCE DISPLAY UNIT',
            style: TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _primaryDistanceUnit,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                isExpanded: true,
                items: UnitSettings.availableDistanceUnits.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _primaryDistanceUnit = val;
                      UnitSettings.primaryDistanceUnit = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 35: CUSTOM LAND UNIT EDITOR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CUSTOM LAND UNIT EDITOR',
                      style: TextStyle(
                          color: Color(0xFF4ADE80), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (UnitSettings.customUnit != null)
                      TextButton(
                        onPressed: _clearCustomUnit,
                        child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Custom Unit Name (e.g. Local Bigha, Guntas)',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customSqMetersController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: '1 Unit Equals (in m²)',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    suffixText: 'm²',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  onPressed: _saveCustomUnit,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('SAVE CUSTOM UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Regional Land Revenue Presets
          const Text(
            'REGIONAL LAND REVENUE PRESETS',
            style: TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegionId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 'unknown',
                    child: Text('Unknown / Not specified'),
                  ),
                  ...UnitConverter.presets.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.stateOrRegion})'),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRegionId = val;
                      UnitSettings.setRegion(val);
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Text(
              'Notice: Local land-unit conversions (Bigha, Biswa, Kanal, etc.) vary by district. Verify official revenue records for your exact area.',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ),

          if (activePreset != null) ...[
            const SizedBox(height: 20),
            Text(
              '${activePreset.name.toUpperCase()} REVENUE EQUIVALENCES',
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
                '1 Bigha', '${activePreset.bighaSqMeters.toStringAsFixed(1)} m²'),
            _buildInfoRow(
                '1 Biswa', '${activePreset.biswaSqMeters.toStringAsFixed(1)} m²'),
            _buildInfoRow(
                '1 Kanal', '${activePreset.kanalSqMeters.toStringAsFixed(1)} m²'),
            _buildInfoRow(
                '1 Marla', '${activePreset.marlaSqMeters.toStringAsFixed(1)} m²'),
            _buildInfoRow(
                '1 Guntha', '${activePreset.gunthaSqMeters.toStringAsFixed(1)} m²'),
            _buildInfoRow(
                '1 Cent', '${activePreset.centSqMeters.toStringAsFixed(1)} m²'),
          ],

          const SizedBox(height: 30),
          // Legal & Accuracy Disclaimer (Section 85)
          const Text(
            'LEGAL & SURVEY DISCLAIMER',
            style: TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'GPS-based measurements are estimates and should not be treated as a legally certified land survey. '
              'Field Measure Pro is designed for agricultural planning, field boundary mapping, and estimation purposes. '
              'For legal boundary or property deed measurements, always consult a licensed cadastral surveyor.',
              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
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
