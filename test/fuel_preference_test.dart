import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/fuel_type.dart';
import 'package:mon_carburant_app/providers/filters_provider.dart';
import 'package:mon_carburant_app/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _container(
  Map<String, Object> saved,
) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  // Comme la racine de l'app.
  container.listen(fuelPreferenceSyncProvider, (_, _) {});
  return (container, prefs);
}

void main() {
  test('la carte s’ouvre sur le Gazole par défaut', () async {
    final (container, _) = await _container({});

    expect(container.read(selectedFuelProvider), FuelType.gazole);
  });

  test('le carburant choisi est retenu pour le prochain lancement', () async {
    final (container, prefs) = await _container({});

    container.read(selectedFuelProvider.notifier).state = FuelType.e10;
    await pumpEventQueue();

    final (next, _) = await _container({
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    });
    expect(next.read(selectedFuelProvider), FuelType.e10);
  });

  group('ancien écran « Mon véhicule »', () {
    test('son carburant devient le carburant préféré', () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_fuel': FuelType.sp98.code,
        'vehicle_consumption_l100': 8.0,
        'vehicle_fill_liters': 55.0,
        'vehicle_electric': false,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateVehiclePreferences(prefs);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(selectedFuelProvider), FuelType.sp98);
      // Le reste ne sert plus à rien : effacé.
      expect(prefs.getKeys().where((k) => k.startsWith('vehicle_')), isEmpty);
    });

    test('un carburant choisi depuis ne se fait pas écraser', () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_fuel': FuelType.sp98.code,
        'preferred_fuel': FuelType.e85.code,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateVehiclePreferences(prefs);

      expect(prefs.getString('preferred_fuel'), FuelType.e85.code);
    });
  });
}
