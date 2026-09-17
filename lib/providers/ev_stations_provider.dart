import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ev_station.dart';
import '../data/services/irve_service.dart';
import 'filters_provider.dart';
import 'map_viewport_provider.dart';

final irveServiceProvider = Provider<IrveService>((ref) => IrveService());

/// EV chargers for the current viewport. Only fetches when the map layer is
/// set to `bornes` — autoDispose keeps it from lingering once the user
/// switches back to fuel stations.
final evStationsProvider = FutureProvider.autoDispose<List<EvStation>>((
  ref,
) async {
  final layer = ref.watch(mapLayerProvider);
  final bounds = ref.watch(mapBoundsProvider);
  if (layer != MapLayer.bornes || bounds == null) return const [];

  return ref
      .watch(irveServiceProvider)
      .fetchInBounds(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      );
});
