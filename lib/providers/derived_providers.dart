import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/station.dart';
import '../data/models/station_with_distance.dart';
import 'location_provider.dart';
import 'stations_provider.dart';

/// Stations sorted by distance to the user, closest first. Empty until
/// location has been requested.
final nearbyStationsProvider = Provider<List<StationWithDistance>>((ref) {
  final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
  final position = ref.watch(userLocationProvider).valueOrNull;
  if (position == null) return const [];

  final withDistance = stations
      .map((s) => StationWithDistance(s, s.distanceKmTo(position.latitude, position.longitude)))
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
  final list = counts.entries
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
final searchResultsProvider = Provider.autoDispose.family<List<Station>, String>((ref, query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const [];
  final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];

  final isPostal = RegExp(r'^\d{2,5}$').hasMatch(trimmed);
  if (isPostal) {
    return stations.where((s) => s.cp.startsWith(trimmed)).toList();
  }
  return stations.where((s) => s.ville.toLowerCase().contains(trimmed)).toList();
});
