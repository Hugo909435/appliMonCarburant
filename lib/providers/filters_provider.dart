import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fuel_type.dart';

final selectedFuelProvider = StateProvider<FuelType>((ref) => FuelType.gazole);

/// What the map is currently showing markers for. Null until the user
/// picks one — neither is selected by default.
enum MapLayer { stations, bornes }

final mapLayerProvider = StateProvider<MapLayer?>((ref) => null);

/// Restrict fuel stations to motorway (autoroute) ones only.
final autorouteOnlyProvider = StateProvider<bool>((ref) => false);

/// Restrict fuel stations to a single département (num, e.g. "75").
final departmentFilterProvider = StateProvider<String?>((ref) => null);

/// Whether brand badges (fetched from OpenStreetMap) are shown/used to
/// filter markers on the map.
final brandFilterEnabledProvider = StateProvider<bool>((ref) => false);

/// A single brand name selected to filter markers to, or null for all.
final selectedBrandProvider = StateProvider<String?>((ref) => null);

/// Show only stations already saved as favorites.
final favoritesOnlyProvider = StateProvider<bool>((ref) => false);
