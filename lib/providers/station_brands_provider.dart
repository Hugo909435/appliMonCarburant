import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/station.dart';
import '../data/services/osm_brand_service.dart';
import 'filters_provider.dart';
import 'map_viewport_provider.dart';
import 'stations_provider.dart';

final osmBrandServiceProvider = Provider<OsmBrandService>(
  (ref) => OsmBrandService(),
);

/// Fuel station brands (from OpenStreetMap) for the current viewport, only
/// fetched while the "par enseigne" filter is enabled and the map is
/// showing fuel stations.
final stationBrandsProvider = FutureProvider.autoDispose<List<OsmFuelBrand>>((
  ref,
) async {
  final layer = ref.watch(mapLayerProvider);
  final enabled = ref.watch(brandFilterEnabledProvider);
  final bounds = ref.watch(mapBoundsProvider);
  if (layer != MapLayer.stations || !enabled || bounds == null) {
    return const [];
  }

  return ref
      .watch(osmBrandServiceProvider)
      .fetchInBounds(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      );
});

/// Nearest OSM brand (within 70m) for each fuel station inside the current
/// map bounds, keyed by station id. A `Provider` (not inline in the widget's
/// build()) so it's only recomputed when the station list, bounds, or
/// fetched brands actually change — not on every unrelated filter toggle
/// (fuel type, highway, favorites, ...) that also triggers a marker rebuild.
final stationBrandMatchesProvider = Provider.autoDispose<Map<String, String>>(
  (ref) {
    final bounds = ref.watch(mapBoundsProvider);
    final brands = ref.watch(stationBrandsProvider).valueOrNull ?? const [];
    if (bounds == null || brands.isEmpty) return const {};

    final allStations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final inBounds = allStations.where(
      (s) =>
          s.lat >= bounds.south &&
          s.lat <= bounds.north &&
          s.lng >= bounds.west &&
          s.lng <= bounds.east,
    );

    final matches = <String, String>{};
    for (final s in inBounds) {
      OsmFuelBrand? nearest;
      var best = double.infinity;
      for (final b in brands) {
        final d = s.distanceKmTo(b.lat, b.lng);
        if (d < best) {
          best = d;
          nearest = b;
        }
      }
      if (nearest != null && best <= 0.07) matches[s.id] = nearest.brand;
    }
    return matches;
  },
);
