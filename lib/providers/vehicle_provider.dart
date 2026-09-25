import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/fuel_type.dart';

/// What the app needs to know about the user's car: which fuel to show
/// first, and the two numbers that turn a price per liter into the real
/// cost of a fill-up — how much the user usually puts in, and how much the
/// car burns getting to the station.
class VehicleProfile {
  const VehicleProfile({
    required this.fuel,
    required this.consumptionL100,
    required this.fillLiters,
  });

  static const defaults = VehicleProfile(
    fuel: FuelType.gazole,
    consumptionL100: 6.5,
    fillLiters: 40,
  );

  final FuelType fuel;
  final double consumptionL100;
  final double fillLiters;

  VehicleProfile copyWith({
    FuelType? fuel,
    double? consumptionL100,
    double? fillLiters,
  }) => VehicleProfile(
    fuel: fuel ?? this.fuel,
    consumptionL100: consumptionL100 ?? this.consumptionL100,
    fillLiters: fillLiters ?? this.fillLiters,
  );
}

class VehicleNotifier extends AsyncNotifier<VehicleProfile> {
  static const _consumptionKey = 'vehicle_consumption_l100';
  static const _fillKey = 'vehicle_fill_liters';
  static const _fuelKey = 'vehicle_fuel';

  /// The saved fuel, readable synchronously so the map opens on it.
  static FuelType? savedFuel(SharedPreferences? prefs) =>
      FuelType.fromCode(prefs?.getString(_fuelKey) ?? '');

  @override
  Future<VehicleProfile> build() async {
    final prefs = await SharedPreferences.getInstance();
    return VehicleProfile(
      fuel: savedFuel(prefs) ?? VehicleProfile.defaults.fuel,
      consumptionL100:
          prefs.getDouble(_consumptionKey) ??
          VehicleProfile.defaults.consumptionL100,
      fillLiters:
          prefs.getDouble(_fillKey) ?? VehicleProfile.defaults.fillLiters,
    );
  }

  Future<void> save(VehicleProfile profile) async {
    state = AsyncData(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fuelKey, profile.fuel.code);
    await prefs.setDouble(_consumptionKey, profile.consumptionL100);
    await prefs.setDouble(_fillKey, profile.fillLiters);
  }
}

final vehicleProvider = AsyncNotifierProvider<VehicleNotifier, VehicleProfile>(
  VehicleNotifier.new,
);

/// Synchronous access for widgets that just need numbers to compute with:
/// falls back to the defaults while the saved profile loads.
final vehicleProfileProvider = Provider<VehicleProfile>(
  (ref) => ref.watch(vehicleProvider).valueOrNull ?? VehicleProfile.defaults,
);
