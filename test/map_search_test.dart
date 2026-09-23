import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/data/services/geocoding_service.dart';
import 'package:mon_carburant_app/providers/map_search_provider.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

Station _station({
  required String id,
  String ville = 'Paris',
  String adresse = '1 rue de la Paix',
  String cp = '75001',
}) => Station(
  id: id,
  cp: cp,
  dep: cp.substring(0, 2),
  ville: ville,
  adresse: adresse,
  lat: 48.8,
  lng: 2.3,
  pop: 'route',
  prices: const {'Gazole': 1.7},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

/// Géocodeur de test : répond ce qu'on lui dit, quand on lui dit.
class _FakeGeocoding implements GeocodingService {
  _FakeGeocoding({this.results = const [], this.delay = Duration.zero});

  List<GeocodingResult> results;
  Duration delay;
  bool throws = false;
  int calls = 0;

  @override
  Future<List<GeocodingResult>> search(String query) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throws) throw Exception('réseau indisponible');
    return results;
  }
}

/// Remplace le chargement réel du flux open data par une liste figée.
class _FakeStations extends StationsNotifier {
  _FakeStations(this._stations);
  final List<Station> _stations;

  @override
  Future<List<Station>> build() async => _stations;
}

Future<ProviderContainer> _container({
  List<Station> stations = const [],
  required GeocodingService geocoding,
}) async {
  final container = ProviderContainer(
    overrides: [
      stationsProvider.overrideWith(() => _FakeStations(stations)),
      geocodingServiceProvider.overrideWithValue(geocoding),
    ],
  );
  addTearDown(container.dispose);
  // La liste des stations se charge de façon asynchrone : sans cette attente,
  // la recherche partirait alors que le provider est encore vide, et ne
  // trouverait jamais de station locale.
  await container.read(stationsProvider.future);
  return container;
}

void main() {
  group('matchStations', () {
    final stations = [
      _station(id: 'a', ville: 'Lyon', cp: '69001'),
      _station(
        id: 'b',
        ville: 'Lyon',
        adresse: '2 cours Gambetta',
        cp: '69003',
      ),
      _station(id: 'c', ville: 'Marseille', cp: '13001'),
    ];

    test('une requête numérique est lue comme un code postal', () {
      expect(matchStations(stations, '690').map((s) => s.id), ['a', 'b']);
    });

    test('« 13 » ramène le département, pas une rue numérotée 13', () {
      expect(matchStations(stations, '13').map((s) => s.id), ['c']);
    });

    test('la recherche texte porte sur la ville et sur l’adresse', () {
      expect(matchStations(stations, 'lyon').map((s) => s.id), ['a', 'b']);
      expect(matchStations(stations, 'gambetta').map((s) => s.id), ['b']);
    });

    test('la casse est ignorée', () {
      expect(matchStations(stations, 'MARSEILLE'), hasLength(1));
    });

    test('le nombre de résultats est plafonné', () {
      final many = [for (var i = 0; i < 20; i++) _station(id: '$i')];
      expect(matchStations(many, 'paris'), hasLength(5));
    });

    test('une requête vide ne ramène rien', () {
      expect(matchStations(stations, '   '), isEmpty);
    });
  });

  group('MapSearchNotifier', () {
    test('ignore une requête trop courte, sans appeler le géocodeur', () async {
      final geocoding = _FakeGeocoding();
      final container = await _container(geocoding: geocoding);

      container.read(mapSearchProvider.notifier).onQueryChanged('l');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(container.read(mapSearchProvider).results, isEmpty);
      expect(geocoding.calls, 0);
    });

    test(
      'n’appelle le géocodeur qu’une fois pour une salve de frappes',
      () async {
        final geocoding = _FakeGeocoding();
        final container = await _container(geocoding: geocoding);
        final notifier = container.read(mapSearchProvider.notifier);

        for (final frappe in ['ly', 'lyo', 'lyon']) {
          notifier.onQueryChanged(frappe);
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(geocoding.calls, 1);
      },
    );

    test('affiche les stations locales avant la réponse du réseau', () async {
      final geocoding = _FakeGeocoding(
        delay: const Duration(milliseconds: 300),
      );
      final container = await _container(
        stations: [_station(id: 'a', ville: 'Lyon')],
        geocoding: geocoding,
      );

      container.read(mapSearchProvider.notifier).onQueryChanged('lyon');
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final pending = container.read(mapSearchProvider);
      expect(pending.searching, isTrue);
      expect(pending.results.single.kind, SearchHitKind.station);
      expect(pending.results.single.title, 'Lyon');
    });

    test('complète avec les adresses une fois le géocodeur revenu', () async {
      final geocoding = _FakeGeocoding(
        results: const [
          GeocodingResult(label: 'Lyon, Rhône, France', lat: 45.7, lng: 4.8),
        ],
      );
      final container = await _container(
        stations: [_station(id: 'a', ville: 'Lyon')],
        geocoding: geocoding,
      );

      container.read(mapSearchProvider.notifier).onQueryChanged('lyon');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(mapSearchProvider);
      expect(state.searching, isFalse);
      expect(state.results.map((r) => r.kind), [
        SearchHitKind.station,
        SearchHitKind.address,
      ]);
      // Le libellé long est réduit à sa tête de liste pour l'affichage.
      expect(state.results.last.title, 'Lyon');
      expect(state.results.last.subtitle, 'Lyon, Rhône, France');
    });

    test('un géocodeur en panne laisse les stations trouvées', () async {
      final geocoding = _FakeGeocoding()..throws = true;
      final container = await _container(
        stations: [_station(id: 'a', ville: 'Lyon')],
        geocoding: geocoding,
      );

      container.read(mapSearchProvider.notifier).onQueryChanged('lyon');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(mapSearchProvider);
      expect(state.searching, isFalse);
      expect(state.results, hasLength(1));
      expect(state.results.single.kind, SearchHitKind.station);
    });

    test('une réponse lente ne réécrase pas un résultat plus récent', () async {
      // La première requête met 500 ms, la seconde répond tout de suite :
      // sans le jeton de fraîcheur, la lente écraserait la rapide en arrivant.
      final geocoding = _FakeGeocoding(
        results: const [GeocodingResult(label: 'Lente', lat: 1, lng: 1)],
        delay: const Duration(milliseconds: 500),
      );
      final container = await _container(geocoding: geocoding);
      final notifier = container.read(mapSearchProvider.notifier);

      notifier.onQueryChanged('lyon');
      await Future<void>.delayed(const Duration(milliseconds: 450));

      geocoding
        ..delay = Duration.zero
        ..results = const [GeocodingResult(label: 'Rapide', lat: 2, lng: 2)];
      notifier.onQueryChanged('marseille');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(container.read(mapSearchProvider).results.single.title, 'Rapide');
    });

    test('clear() vide l’état et annule la requête en vol', () async {
      final geocoding = _FakeGeocoding(
        results: const [GeocodingResult(label: 'Lyon', lat: 1, lng: 1)],
        delay: const Duration(milliseconds: 300),
      );
      final container = await _container(geocoding: geocoding);
      final notifier = container.read(mapSearchProvider.notifier);

      notifier.onQueryChanged('lyon');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      notifier.clear();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(mapSearchProvider).results, isEmpty);
      expect(container.read(mapSearchProvider).searching, isFalse);
    });
  });
}
