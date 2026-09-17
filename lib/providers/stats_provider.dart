import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fuel_stat.dart';
import '../data/models/fuel_type.dart';
import '../data/models/station.dart';
import 'stations_provider.dart';

enum GroupType { department, region, autoroute }

class GroupQuery {
  const GroupQuery(this.type, this.key);

  final GroupType type;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is GroupQuery && other.type == type && other.key == key;

  @override
  int get hashCode => Object.hash(type, key);
}

Map<FuelType, FuelStat?> computeStats(List<Station> stations) => {
  for (final fuel in FuelType.values)
    fuel: FuelStat.fromPrices(
      stations.map((s) => s.prices[fuel.code]).whereType<double>(),
    ),
};

/// National average/min/max per fuel, computed client-side from the full
/// station list (there is no separately published stats endpoint to read).
final nationalStatsProvider = Provider<Map<FuelType, FuelStat?>>((ref) {
  final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
  return computeStats(stations);
});

final groupStationsProvider = Provider.autoDispose
    .family<List<Station>, GroupQuery>((ref, query) {
      final stations =
          ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
      return switch (query.type) {
        GroupType.department =>
          stations.where((s) => s.dep == query.key).toList(),
        GroupType.region =>
          stations.where((s) => _regionOf(ref, s) == query.key).toList(),
        GroupType.autoroute =>
          stations.where((s) => s.highway == query.key).toList(),
      };
    });

final groupStatsProvider = Provider.autoDispose
    .family<Map<FuelType, FuelStat?>, GroupQuery>((ref, query) {
      return computeStats(ref.watch(groupStationsProvider(query)));
    });

String? _regionOf(Ref ref, Station s) {
  final departments = ref.watch(departmentsDataProvider).valueOrNull;
  return departments?[s.dep]?.regionSlug;
}
