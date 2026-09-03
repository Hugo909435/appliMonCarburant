import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/department.dart';
import '../data/models/station.dart';
import '../data/repositories/station_repository.dart';
import '../data/services/departments_data.dart';
import '../data/services/price_history_service.dart';
import 'stats_provider.dart';

final stationRepositoryProvider = Provider<StationRepository>((ref) => StationRepository());

final departmentsDataProvider = FutureProvider<Map<String, Department>>((ref) {
  return DepartmentsData().load();
});

final priceHistoryServiceProvider = Provider<PriceHistoryService>((ref) => PriceHistoryService());

final lastUpdateProvider = StateProvider<DateTime?>((ref) => null);

class StationsNotifier extends AsyncNotifier<List<Station>> {
  @override
  Future<List<Station>> build() async {
    final repo = ref.read(stationRepositoryProvider);
    final cached = await repo.loadFromCache();
    final lastUpdate = await repo.lastUpdate();
    ref.read(lastUpdateProvider.notifier).state = lastUpdate;

    if (cached.isNotEmpty) {
      // Show cached data immediately, refresh quietly in the background if stale.
      if (await repo.isStale()) {
        unawaited(refresh());
      }
      return cached;
    }

    return refresh();
  }

  Future<List<Station>> refresh() async {
    final repo = ref.read(stationRepositoryProvider);
    state = const AsyncLoading<List<Station>>().copyWithPrevious(state);
    try {
      final stations = await repo.refresh();
      ref.read(lastUpdateProvider.notifier).state = await repo.lastUpdate();
      state = AsyncData(stations);
      await _recordHistory(stations);
      return stations;
    } catch (err, stack) {
      // Keep showing whatever we had before if the refresh fails.
      final previous = state.valueOrNull;
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(err, stack);
      }
      rethrow;
    }
  }

  Future<void> _recordHistory(List<Station> stations) async {
    final national = computeStats(stations);
    await ref.read(priceHistoryServiceProvider).recordToday({
      for (final entry in national.entries) entry.key: entry.value?.avg,
    });
  }
}

final stationsProvider = AsyncNotifierProvider<StationsNotifier, List<Station>>(
  StationsNotifier.new,
);
