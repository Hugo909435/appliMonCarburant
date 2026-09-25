import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
  final filter = ref.watch(evFilterProvider);
  if (layer != MapLayer.bornes || bounds == null) return const [];

  // The map moving on rebuilds this provider: drop the request it no longer
  // needs instead of letting it hold the connection and the parser.
  final client = http.Client();
  ref.onDispose(client.close);

  return ref
      .watch(irveServiceProvider)
      .fetchInBounds(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
        filter: filter,
        client: client,
      );
});

/// The sheet-only details of the charger with this id, loaded when its
/// sheet opens (the map's fetch leaves them out).
final evStationDetailsProvider = FutureProvider.autoDispose
    .family<EvStationDetails, String>(
      (ref, id) => ref.watch(irveServiceProvider).fetchDetails(id),
    );

/// Every charging operator in France, for the operator filter. Kept once
/// loaded: the list barely changes.
final evOperatorsProvider = FutureProvider<List<EvOperator>>(
  (ref) => ref.watch(irveServiceProvider).fetchOperators(),
);
