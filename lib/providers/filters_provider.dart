import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/ev_station.dart';
import '../data/models/fuel_type.dart';
import 'preferences_provider.dart';

/// Carburant affiché sur la carte, par défaut tant que l'utilisateur n'en a
/// pas choisi d'autre.
const kDefaultFuel = FuelType.gazole;

const _fuelKey = 'preferred_fuel';

/// Réglages de l'ancien écran « Mon véhicule », retiré de l'app.
const _legacyFuelKey = 'vehicle_fuel';
const _legacyVehicleKeys = [
  _legacyFuelKey,
  'vehicle_consumption_l100',
  'vehicle_fill_liters',
  'vehicle_electric',
];

/// À appeler au lancement : reprend le carburant de l'ancien écran « Mon
/// véhicule » comme carburant préféré, puis efface ses réglages.
Future<void> migrateVehiclePreferences(SharedPreferences prefs) async {
  final legacyFuel = prefs.getString(_legacyFuelKey);
  if (legacyFuel != null && !prefs.containsKey(_fuelKey)) {
    await prefs.setString(_fuelKey, legacyFuel);
  }
  for (final key in _legacyVehicleKeys) {
    if (prefs.containsKey(key)) await prefs.remove(key);
  }
}

/// Fuel the map shows prices for. Opens on the last one picked (see
/// [fuelPreferenceSyncProvider]).
final selectedFuelProvider = StateProvider<FuelType>(
  (ref) =>
      FuelType.fromCode(
        ref.read(sharedPreferencesProvider)?.getString(_fuelKey) ?? '',
      ) ??
      kDefaultFuel,
);

/// Retient le carburant choisi, pour rouvrir la carte dessus. À surveiller
/// depuis la racine de l'app.
final fuelPreferenceSyncProvider = Provider<void>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs == null) return;
  ref.listen(selectedFuelProvider, (_, fuel) {
    unawaited(prefs.setString(_fuelKey, fuel.code));
  });
});

/// What the map is currently showing markers for. Fuel stations by
/// default, so the home screen opens straight onto prices and the list of
/// stations in view; null is kept for "nothing picked".
enum MapLayer { stations, bornes }

final mapLayerProvider = StateProvider<MapLayer?>((ref) => MapLayer.stations);

/// How the home screen's station list is ordered.
enum StationSort { cheapest, nearest }

/// Cheapest first by default: it's the question the app answers. Nearest
/// needs the user's position and falls back to cheapest until it's known.
final stationSortProvider = StateProvider<StationSort>(
  (ref) => StationSort.cheapest,
);

/// How the home screen's EV charger list is ordered.
enum EvSort { fastest, nearest }

/// Most powerful first by default: chargers have no price to rank on.
/// Nearest falls back to fastest until the user's position is known.
final evSortProvider = StateProvider<EvSort>((ref) => EvSort.fastest);

/// Sentinel value of [highwayFilterProvider] meaning "any motorway
/// station", as opposed to a specific highway code (e.g. "A6").
const kAnyHighway = '*';

/// Restrict fuel stations to a single highway (e.g. "A6"), to any
/// motorway station ([kAnyHighway]), or null for no filter.
final highwayFilterProvider = StateProvider<String?>((ref) => null);

/// Restrict fuel stations to a single département (num, e.g. "75").
final departmentFilterProvider = StateProvider<String?>((ref) => null);

/// A single brand key (see brand_rules.dart) to filter markers to, or
/// null for all.
final selectedBrandProvider = StateProvider<String?>((ref) => null);

/// Show only stations already saved as favorites.
final favoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Restrict fuel stations to those offering a given service (e.g.
/// "Lavage"), or null for no filter.
final selectedServiceProvider = StateProvider<String?>((ref) => null);

/// Restrict EV chargers to a single connector (a key of [evPlugFields],
/// e.g. "Combo CCS"), or null for no filter.
final plugTypeFilterProvider = StateProvider<String?>((ref) => null);

/// The minimum powers the chargers filter offers, in kW.
const evPowerSteps = [3, 7, 22, 50, 100, 350];

/// Restrict EV chargers to those reaching this power (one of
/// [evPowerSteps], in kW), or null for no filter.
final evMinPowerProvider = StateProvider<int?>((ref) => null);

/// Restrict EV chargers to a single operator, or null for no filter.
final evOperatorFilterProvider = StateProvider<EvOperator?>((ref) => null);

/// Every chargers filter at once, as the API gets it.
final evFilterProvider = Provider<EvFilter>(
  (ref) => EvFilter(
    plug: ref.watch(plugTypeFilterProvider),
    evOperator: ref.watch(evOperatorFilterProvider),
    minPowerKw: ref.watch(evMinPowerProvider),
  ),
);

const _favoriteOperatorsKey = 'favorite_ev_operators';

/// The operators starred in the operator filter, listed first there. Kept
/// on the device, as lowercased names ([EvOperator] merges spellings that
/// differ only in case).
class FavoriteEvOperatorsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {
    ...?ref
        .read(sharedPreferencesProvider)
        ?.getStringList(_favoriteOperatorsKey),
  };

  static String _key(EvOperator operator) => operator.name.toLowerCase();

  bool isFavorite(EvOperator operator) => state.contains(_key(operator));

  void toggle(EvOperator operator) {
    final key = _key(operator);
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      unawaited(prefs.setStringList(_favoriteOperatorsKey, state.toList()));
    }
  }
}

final favoriteEvOperatorsProvider =
    NotifierProvider<FavoriteEvOperatorsNotifier, Set<String>>(
      FavoriteEvOperatorsNotifier.new,
    );
