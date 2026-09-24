import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ev_station.dart';
import '../data/models/station.dart';
import '../data/models/station_with_distance.dart';
import 'ev_stations_provider.dart';
import 'favorites_provider.dart';
import 'filters_provider.dart';
import 'location_provider.dart';
import 'map_viewport_provider.dart';
import 'station_brands_provider.dart';
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

  var stations = allStations
      .where((s) => s.prices.containsKey(fuel.code))
      .toList();
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
    stations = stations
        .where((s) => s.services.contains(selectedService))
        .toList();
  }
  return stations;
});

/// [filteredStationsProvider] narrowed to the selected brand, if any — what
/// the map actually shows. Kept apart from it because the brand picker
/// needs the brands of every station the other filters let through.
final brandFilteredStationsProvider = Provider<List<Station>>((ref) {
  final stations = ref.watch(filteredStationsProvider);
  final brand = ref.watch(selectedBrandProvider);
  if (brand == null) return stations;
  final brands = ref.watch(stationBrandsProvider).valueOrNull ?? const {};
  return stations.where((s) => brands[s.id]?.key == brand).toList();
});

/// A station of the home list, with its distance to the user when known.
typedef ListedStation = ({Station station, double? distanceKm});

/// The stations inside the map's visible area, in the order picked by
/// [stationSortProvider]: the home screen's list, kept in step with the
/// map as the user pans and zooms. Stations without a price for the
/// selected fuel are already filtered out upstream.
final viewportStationsProvider = Provider<List<ListedStation>>((ref) {
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return const [];
  final fuel = ref.watch(selectedFuelProvider);
  final sort = ref.watch(stationSortProvider);
  final position = ref.watch(userLocationProvider).valueOrNull;

  final listed = <ListedStation>[
    for (final s in ref.watch(brandFilteredStationsProvider))
      if (s.lat >= bounds.south &&
          s.lat <= bounds.north &&
          s.lng >= bounds.west &&
          s.lng <= bounds.east)
        (
          station: s,
          distanceKm: position == null
              ? null
              : s.distanceKmTo(position.latitude, position.longitude),
        ),
  ];

  int byPrice(ListedStation a, ListedStation b) =>
      a.station.prices[fuel.code]!.compareTo(b.station.prices[fuel.code]!);
  if (sort == StationSort.nearest && position != null) {
    listed.sort((a, b) {
      final d = a.distanceKm!.compareTo(b.distanceKm!);
      return d != 0 ? d : byPrice(a, b);
    });
  } else {
    listed.sort(byPrice);
  }
  return listed;
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
    evStations = evStations
        .where((e) => e.plugTypes.contains(plugType))
        .toList();
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

/// An EV charger of the home list, with its distance to the user when known.
typedef ListedEvStation = ({EvStation station, double? distanceKm});

/// The EV chargers inside the map's visible area, in the order picked by
/// [evSortProvider]: the home screen's list when the map shows chargers.
final viewportEvStationsProvider = Provider<List<ListedEvStation>>((ref) {
  final bounds = ref.watch(mapBoundsProvider);
  if (bounds == null) return const [];
  final sort = ref.watch(evSortProvider);
  final position = ref.watch(userLocationProvider).valueOrNull;

  final listed = <ListedEvStation>[
    for (final e in ref.watch(filteredEvStationsProvider))
      if (e.lat >= bounds.south &&
          e.lat <= bounds.north &&
          e.lng >= bounds.west &&
          e.lng <= bounds.east)
        (
          station: e,
          distanceKm: position == null
              ? null
              : e.distanceKmTo(position.latitude, position.longitude),
        ),
  ];

  int byPower(ListedEvStation a, ListedEvStation b) =>
      b.station.maxPowerKw.compareTo(a.station.maxPowerKw);
  if (sort == EvSort.nearest && position != null) {
    listed.sort((a, b) {
      final d = a.distanceKm!.compareTo(b.distanceKm!);
      return d != 0 ? d : byPower(a, b);
    });
  } else {
    listed.sort(byPower);
  }
  return listed;
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
