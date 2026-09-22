import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fuel_type.dart';

final selectedFuelProvider = StateProvider<FuelType>((ref) => FuelType.gazole);

/// What the map is currently showing markers for. Null until the user
/// picks one — neither is selected by default.
enum MapLayer { stations, bornes }

final mapLayerProvider = StateProvider<MapLayer?>((ref) => null);

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

/// Restrict EV chargers to a single plug type (e.g. "Combo CCS"), or null
/// for no filter.
final plugTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Restrict EV chargers to fast-charging ones (>= 50 kW) only.
final fastChargeOnlyProvider = StateProvider<bool>((ref) => false);

/// Restrict EV chargers to free-to-use ones only.
final evFreeOnlyProvider = StateProvider<bool>((ref) => false);

/// Restrict EV chargers to a single network/operator (e.g. "TESLA
/// SUPERCHARGER"), or null for no filter.
final evNetworkFilterProvider = StateProvider<String?>((ref) => null);
