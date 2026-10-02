import 'package:flutter_test/flutter_test.dart';
import '../lib/core/units.dart';

void main() {
  group('Regional Unit Conversion Tests (Requirement #20)', () {
    test('Standard Unit Conversions (1 Acre & 1 Hectare)', () {
      const double oneAcreSqM = 4046.8564224;
      const double oneHectareSqM = 10000.0;

      expect(UnitConverter.toAcres(oneAcreSqM), closeTo(1.0, 0.0001));
      expect(UnitConverter.toHectares(oneHectareSqM), closeTo(1.0, 0.0001));
    });

    test('Uttarakhand Pucca Bigha (20 Nali = 2,529.285 m²)', () {
      final preset = UnitConverter.presets.firstWhere((p) => p.id == 'uttarakhand');
      const double sampleArea = 2529.285;

      expect(UnitConverter.toBigha(sampleArea, preset.bighaSqMeters), closeTo(1.0, 0.001));
      expect(UnitConverter.toBiswa(sampleArea, preset.biswaSqMeters), closeTo(20.0, 0.01));
    });

    test('Punjab & Haryana (8 Kanals = 1 Acre = 4046.86 m²)', () {
      final preset = UnitConverter.presets.firstWhere((p) => p.id == 'punjab_haryana');
      const double oneAcre = 4046.8564;

      // 8 Kanals per Acre
      expect(UnitConverter.toKanal(oneAcre, preset.kanalSqMeters), closeTo(8.0, 0.01));
      // 160 Marlas per Acre (20 Marla per Kanal)
      expect(UnitConverter.toMarla(oneAcre, preset.marlaSqMeters), closeTo(160.0, 0.1));
    });
  });
}
