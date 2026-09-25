import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/fuel_type.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/data/repositories/station_repository.dart';
import 'package:mon_carburant_app/data/services/price_history_service.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

Station _station(double gazole) => Station(
  id: '1',
  cp: '75001',
  dep: '75',
  ville: 'Paris',
  adresse: '1 rue de Rivoli',
  lat: 48.85,
  lng: 2.35,
  pop: 'route',
  prices: {'Gazole': gazole},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

/// Ce que le cache sur disque contient, modifiable en cours de test comme le
/// ferait la tâche de fond.
class _FakeRepository implements StationRepository {
  _FakeRepository({required this.date, required this.stations});

  DateTime? date;
  List<Station> stations;

  /// Appelé juste après la première lecture (date ou données), pour glisser
  /// une écriture de la tâche de fond entre les deux.
  void Function()? afterFirstRead;
  int refreshCalls = 0;

  void _read() {
    final hook = afterFirstRead;
    afterFirstRead = null;
    hook?.call();
  }

  @override
  Future<DateTime?> lastUpdate() async {
    final result = date;
    _read();
    return result;
  }

  @override
  Future<List<Station>> loadFromCache() async {
    final result = stations;
    _read();
    return result;
  }

  @override
  Future<bool> isStale() async => StationRepository.isTooOld(date);

  @override
  Future<List<Station>> refresh() async {
    refreshCalls++;
    date = DateTime.now();
    stations = [_station(1.5)];
    return stations;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHistory implements PriceHistoryService {
  @override
  Future<void> recordToday(Map<FuelType, double?> nationalAverages) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

double? _shownGazole(ProviderContainer container) =>
    container.read(stationsProvider).valueOrNull?.single.prices['Gazole'];

/// Laisse s'écouler les lectures et téléchargements lancés sans attente.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Retour au premier plan, qui déclenche le contrôle de fraîcheur.
/// [AppLifecycleListener] refuse les sauts d'état : on repasse par
/// « inactive », comme le système.
void _resume() {
  final binding = TestWidgetsFlutterBinding.instance;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

ProviderContainer _container(_FakeRepository repo) {
  final container = ProviderContainer(
    overrides: [
      stationRepositoryProvider.overrideWithValue(repo),
      priceHistoryServiceProvider.overrideWithValue(_NoHistory()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sans état de départ, le passage à « resumed » n'est pas vu comme un
  // retour au premier plan.
  setUp(
    () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  test('les prix écrits par la tâche de fond sont repris au retour dans '
      'l’app, sans retélécharger', () async {
    final repo = _FakeRepository(
      date: DateTime.now().subtract(const Duration(hours: 1)),
      stations: [_station(1.8)],
    );
    final container = _container(repo);
    await container.read(stationsProvider.future);
    expect(_shownGazole(container), 1.8);

    // La tâche de fond enregistre des prix plus récents sur le disque.
    final written = DateTime.now();
    repo
      ..date = written
      ..stations = [_station(1.7)];

    _resume();
    await _settle();

    expect(_shownGazole(container), 1.7);
    expect(container.read(lastUpdateProvider), written);
    expect(repo.refreshCalls, 0);
  });

  test('une écriture entre la lecture de la date et celle des prix ne fait '
      'pas passer de vieux prix pour frais', () async {
    final repo = _FakeRepository(
      date: DateTime.now().subtract(const Duration(hours: 3)),
      stations: [_station(1.8)],
    );
    repo.afterFirstRead = () => repo
      ..date = DateTime.now()
      ..stations = [_station(1.7)];

    final container = _container(repo);
    await container.read(stationsProvider.future);
    await _settle();

    // Au pire un téléchargement de trop ; jamais les prix de 3 h affichés
    // avec la date de l'écriture.
    final shownOldAsFresh =
        repo.refreshCalls == 0 &&
        _shownGazole(container) == 1.8 &&
        !StationRepository.isTooOld(container.read(lastUpdateProvider));
    expect(shownOldAsFresh, isFalse);
    expect(_shownGazole(container), isNot(1.8));
  });
}
