import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/osm_brand_service.dart';
import 'filters_provider.dart';
import 'map_viewport_provider.dart';

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
