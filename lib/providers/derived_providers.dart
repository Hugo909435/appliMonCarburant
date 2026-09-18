import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ev_station.dart';
import '../data/models/station.dart';
import '../data/models/station_with_distance.dart';
import 'ev_stations_provider.dart';
import 'favorites_provider.dart';
import 'filters_provider.dart';
import 'location_provider.dart';
import 'stations_provider.dart';

/// Fuel stations after every non-map-viewport filter (fuel type, highway,
/// département, favorites-only, service). Shared by the map markers layer
/// and the list view so the two stay in sync and the filtering logic lives
/// in one place.
final filteredStationsProvider = Provider<List<Station>>((ref) {
  final allStations =
      ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
  final fuel = ref.watch(selectedFuelProvider);
  final highwayFilter = ref.watch(highwayFilterProvider);
  final dep = ref.watch(departmentFilterProvider);
  final favoritesOnly = ref.watch(favoritesOnlyProvider);
  final selectedService = ref.watch(selectedServiceProvider);
  final favoriteIds =
      ref.watch(favoritesProvider).valueOrNull ?? const <String>{};

  var stations =
      allStations.where((s) => s.prices.containsKey(fuel.code)).toList();
  if (highwayFilter == kAnyHighway) {
    stations = stations.where((s) => s.isAutoroute).toList();
  } else if (highwayFilter != null) {
    stations = stations.where((s) => s.highway == highwayFilter).toList();
  }
  if (dep != null) stations = stations.where((s) => s.dep == dep).toList();
  if (favoritesOnly) {
    stations = stations.where((s) => favoriteIds.contains(s.id)).toList();
  }
  if (selectedService != null) {
    stations =
        stations.where((s) => s.services.contains(selectedService)).toList();
  }
  return stations;
});

/// EV chargers after every filter (plug type, network, fast-charge-only,
/// free-only). Shared by the map markers layer and the list view.
final filteredEvStationsProvider = Provider<List<EvStation>>((ref) {
  var evStations =
      ref.watch(evStationsProvider).valueOrNull ?? const <EvStation>[];
  final plugType = ref.watch(plugTypeFilterProvider);
  final network = ref.watch(evNetworkFilterProvider);
  final fastChargeOnly = ref.watch(fastChargeOnlyProvider);
  final freeOnly = ref.watch(evFreeOnlyProvider);

  if (plugType != null) {
    evStations =
        evStations.where((e) => e.plugTypes.contains(plugType)).toList();
  }
  if (network != null) {
    evStations = evStations.where((e) => e.network == network).toList();
  }
  if (fastChargeOnly) {
    evStations = evStations.where((e) => e.maxPowerKw >= 50).toList();
  }
  if (freeOnly) {
    evStations = evStations.where((e) => e.free).toList();
  }
  return evStations;
});

/// Stations sorted by distance to the user, closest first. Empty until
/// location has been requested.
final nearbyStationsProvider = Provider<List<StationWithDistance>>((ref) {
  final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
  final position = ref.watch(userLocationProvider).valueOrNull;
  if (position == null) return const [];

  final withDistance =
      stations
          .map(
            (s) => StationWithDistance(
              s,
              s.distanceKmTo(position.latitude, position.longitude),
            ),
          )
          .toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return withDistance;
});

class HighwaySummary {
  const HighwaySummary(this.code, this.count);
  final String code;
  final int count;
}

/// Every highway code seen in the data, sorted numerically (A1, A2, ... A75).
final autoroutesListProvider = Provider<List<HighwaySummary>>((ref) {
  final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
  final counts = <String, int>{};
  for (final s in stations) {
    final code = s.highway;
    if (code == null) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }
  final list =
      counts.entries
          .where((e) => e.value >= 3)
          .map((e) => HighwaySummary(e.key, e.value))
          .toList()
        ..sort((a, b) {
          final na = int.tryParse(a.code.substring(1)) ?? 0;
          final nb = int.tryParse(b.code.substring(1)) ?? 0;
          return na.compareTo(nb);
        });
  return list;
});

/// Free-text search over city name / postal code, mirroring the website's
/// search box behaviour.
final searchResultsProvider = Provider.autoDispose
    .family<List<Station>, String>((ref, query) {
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty) return const [];
      final stations =
          ref.watch(stationsProvider).valueOrNull ?? const <Station>[];

      final isPostal = RegExp(r'^\d{2,5}$').hasMatch(trimmed);
      if (isPostal) {
        return stations.where((s) => s.cp.startsWith(trimmed)).toList();
      }
      return stations
          .where((s) => s.ville.toLowerCase().contains(trimmed))
          .toList();
    });
