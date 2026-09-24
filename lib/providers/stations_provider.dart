import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/department.dart';
import '../data/models/station.dart';
import '../data/repositories/station_repository.dart';
import '../data/services/departments_data.dart';
import '../data/services/price_history_service.dart';
import 'stats_provider.dart';

final stationRepositoryProvider = Provider<StationRepository>(
  (ref) => StationRepository(),
);

final departmentsDataProvider = FutureProvider<Map<String, Department>>((ref) {
  return DepartmentsData().load();
});

final priceHistoryServiceProvider = Provider<PriceHistoryService>(
  (ref) => PriceHistoryService(),
);

final lastUpdateProvider = StateProvider<DateTime?>((ref) => null);

/// Ce que fait la synchronisation des prix en ce moment, pour l'indicateur
/// posé sur la carte.
enum StationsSync {
  /// Données à jour, rien en cours : pas d'indicateur.
  idle,

  /// Téléchargement du flux gouvernemental en cours.
  updating,

  /// Plus de réseau : les prix affichés sont ceux du dernier téléchargement,
  /// la mise à jour repartira d'elle-même au retour de la connexion.
  offline,

  /// Le réseau est là mais le dernier téléchargement a échoué (serveur
  /// indisponible, portail captif…).
  failed,
}

final stationsSyncProvider = StateProvider<StationsSync>(
  (ref) => StationsSync.idle,
);

class StationsNotifier extends AsyncNotifier<List<Station>> {
  /// How often an open app re-checks whether its data went stale. Short
  /// next to [StationRepository.freshFor] so the data never ages much past
  /// it; the check itself only reads a small metadata file.
  static const checkEvery = Duration(minutes: 5);

  /// The download in progress, if any: a resume and a periodic tick can
  /// land together, and the 10+ MB feed must not be fetched twice.
  Future<List<Station>>? _inFlight;

  /// Optimiste jusqu'à la première réponse de [Connectivity] : au pire, un
  /// téléchargement tenté hors ligne échoue et passe en [StationsSync.failed].
  bool _online = true;
  bool _lastFailed = false;

  @override
  Future<List<Station>> build() async {
    _keepFresh();

    final repo = ref.read(stationRepositoryProvider);
    final cached = await repo.loadFromCache();
    final lastUpdate = await repo.lastUpdate();
    ref.read(lastUpdateProvider.notifier).state = lastUpdate;

    if (cached.isNotEmpty) {
      // Show cached data immediately, refresh quietly in the background if stale.
      if (_online && await repo.isStale()) {
        unawaited(refresh());
      }
      return cached;
    }

    return refresh();
  }

  /// Without this, staleness was only checked at cold start: an app kept
  /// in memory for days would keep showing the prices of its launch day.
  /// Timers don't fire while the OS suspends the app, hence the extra
  /// check on resume. The network is watched too, to flag offline mode and
  /// catch up as soon as the connection comes back.
  void _keepFresh() {
    final timer = Timer.periodic(checkEvery, (_) => _refreshIfStale());
    final lifecycle = AppLifecycleListener(onResume: _refreshIfStale);
    final connectivity = Connectivity();
    // Pas de plugin natif dans les tests (ni sur certaines plateformes) :
    // on reste alors sur l'hypothèse « en ligne ».
    final network = connectivity.onConnectivityChanged.listen(
      _onConnectivity,
      onError: (Object _) {},
    );
    unawaited(
      connectivity.checkConnectivity().then(
        _onConnectivity,
        onError: (Object _) {},
      ),
    );
    ref.onDispose(() {
      timer.cancel();
      lifecycle.dispose();
      network.cancel();
    });
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    _publishSync();
    if (!online) return;
    // Retour du réseau : un téléchargement raté est retenté tout de suite,
    // sinon on ne télécharge que si les données ont vieilli entre-temps.
    unawaited(_lastFailed ? refresh() : _refreshIfStale());
  }

  Future<void> _refreshIfStale() async {
    if (!_online) return;
    if (await ref.read(stationRepositoryProvider).isStale()) {
      await refresh();
    }
  }

  Future<List<Station>> refresh() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final download = _download().whenComplete(() {
      _inFlight = null;
      _publishSync();
    });
    _inFlight = download;
    _publishSync();
    return download;
  }

  void _publishSync() {
    ref.read(stationsSyncProvider.notifier).state = _inFlight != null
        ? StationsSync.updating
        : !_online
        ? StationsSync.offline
        : _lastFailed
        ? StationsSync.failed
        : StationsSync.idle;
  }

  Future<List<Station>> _download() async {
    final repo = ref.read(stationRepositoryProvider);
    state = const AsyncLoading<List<Station>>().copyWithPrevious(state);
    try {
      final stations = await repo.refresh();
      _lastFailed = false;
      ref.read(lastUpdateProvider.notifier).state = await repo.lastUpdate();
      state = AsyncData(stations);
      await _recordHistory(stations);
      return stations;
    } catch (err, stack) {
      _lastFailed = true;
      // Keep showing whatever we had before if the refresh fails. No
      // rethrow: build() invokes this via unawaited() for a silent
      // background refresh, so an uncaught error would otherwise surface
      // even though we've already degraded gracefully above.
      final previous = state.valueOrNull;
      if (previous != null) {
        state = AsyncData(previous);
        return previous;
      }
      state = AsyncError(err, stack);
      return const [];
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
