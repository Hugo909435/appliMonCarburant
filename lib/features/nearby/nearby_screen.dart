import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/derived_providers.dart';
import '../../shared/widgets/station_list_screen.dart';

class NearbyScreen extends ConsumerWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyStationsProvider);
    return StationListScreen(
      title: 'Stations près de moi',
      stations: [for (final n in nearby) n.station],
      distances: {for (final n in nearby) n.station.id: n.distanceKm},
      defaultSort: StationSort.distance,
      emptyMessage: 'Aucune station trouvée à proximité.',
    );
  }
}
