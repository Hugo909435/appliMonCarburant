import '../models/station.dart';
import '../services/gov_feed_service.dart';
import '../services/station_cache.dart';

class StationRepository {
  StationRepository({GovFeedService? feedService, StationCache? cache})
      : _feed = feedService ?? GovFeedService(),
        _cache = cache ?? StationCache();

  final GovFeedService _feed;
  final StationCache _cache;

  /// Cached data is considered fresh enough to skip an automatic refresh
  /// for this long (the government feed itself updates continuously, but
  /// there is no need to re-download 10+ MB every app launch).
  static const freshFor = Duration(hours: 6);

  Future<List<Station>> loadFromCache() async {
    final raw = await _cache.read();
    if (raw == null) return [];
    return raw.map(Station.fromJson).toList();
  }

  Future<DateTime?> lastUpdate() => _cache.lastUpdate();

  Future<bool> isStale() async {
    final last = await lastUpdate();
    if (last == null) return true;
    return DateTime.now().difference(last) > freshFor;
  }

  Future<List<Station>> refresh() async {
    final raw = await _feed.fetchStations();
    await _cache.write(raw);
    return raw.map(Station.fromJson).toList();
  }
}
