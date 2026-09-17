import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/fuel_stat.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/filters_provider.dart';
import 'fuel_selector.dart';
import 'station_list_tile.dart';
import 'stats_summary_card.dart';

enum StationSort { price, distance, none }

/// Generic "list of stations" screen: fuel selector + optional stats +
/// sortable list. Backs the search results, "near me", department/region/
/// autoroute and favorites screens alike.
class StationListScreen extends ConsumerWidget {
  const StationListScreen({
    super.key,
    required this.title,
    required this.stations,
    this.distances,
    this.stats,
    this.defaultSort = StationSort.price,
    this.emptyMessage = 'Aucune station trouvée.',
    this.appBarActions,
  });

  final String title;
  final List<Station> stations;
  final List<Widget>? appBarActions;

  /// Optional station.id -> distance in km, enables sort-by-distance and
  /// shows the distance in each row.
  final Map<String, double>? distances;

  final Map<FuelType, FuelStat?>? stats;
  final StationSort defaultSort;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(selectedFuelProvider);

    final sorted = [...stations];
    if (defaultSort == StationSort.distance && distances != null) {
      sorted.sort(
        (a, b) => (distances![a.id] ?? double.infinity).compareTo(
          distances![b.id] ?? double.infinity,
        ),
      );
    } else {
      sorted.sort((a, b) {
        final pa = a.prices[fuel.code];
        final pb = b.prices[fuel.code];
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: appBarActions),
      body: Column(
        children: [
          const SizedBox(height: 12),
          const FuelSelector(),
          const SizedBox(height: 14),
          if (stats != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StatsSummaryCard(stats: stats!),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(emptyMessage, textAlign: TextAlign.center),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final station = sorted[index];
                      return StationListTile(
                        station: station,
                        fuel: fuel,
                        distanceKm: distances?[station.id],
                        onTap: () => context.push('/station/${station.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
