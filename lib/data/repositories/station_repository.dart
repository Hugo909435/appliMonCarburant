import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../models/station.dart';
import '../services/gov_feed_service.dart';
import '../services/sample_stations_service.dart';
import '../services/station_cache.dart';

class StationRepository {
  StationRepository({
    GovFeedService? feedService,
    StationCache? cache,
    SampleStationsService? sample,
  }) : _feed = feedService ?? GovFeedService(),
       _cache = cache ?? StationCache(),
       _sample = sample ?? SampleStationsService();

  final GovFeedService _feed;
  final StationCache _cache;
  final SampleStationsService _sample;

  /// Cached data is considered fresh enough to skip an automatic refresh
  /// for this long (the government feed itself updates continuously, but
  /// there is no need to re-download 10+ MB every app launch).
  ///
  /// Kept under two hours on purpose: the product promise is that a user
  /// never sees data older than 2 h. [StationsNotifier] checks staleness
  /// every [StationsNotifier.checkEvery] and on resume, so the margin
  /// covers that check interval plus the download itself.
  static const freshFor = Duration(hours: 1, minutes: 50);

  Future<List<Station>> loadFromCache() async {
    final raw = await _cache.read();
    if (raw == null) return [];
    return raw.map(Station.fromJson).toList();
  }

  /// Last successful download in this session. Backs up the on-disk date
  /// where the cache can't be written (web): without it the data would
  /// always look stale and be re-downloaded on every periodic check.
  DateTime? _fetchedAt;

  Future<DateTime?> lastUpdate() async =>
      await _cache.lastUpdate() ?? _fetchedAt;

  Future<bool> isStale() async => isTooOld(await lastUpdate());

  /// Whether data downloaded at [last] is due for a refresh.
  static bool isTooOld(DateTime? last) =>
      last == null || DateTime.now().difference(last) > freshFor;

  Future<List<Station>> refresh() async {
    try {
      final raw = await _feed.fetchStations();
      await _cache.write(raw);
      _fetchedAt = DateTime.now();
      return raw.map(Station.fromJson).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Flux gouvernemental indisponible ($e) : données de test locales.',
        );
        return _sample.load();
      }
      rethrow;
    }
  }
}
