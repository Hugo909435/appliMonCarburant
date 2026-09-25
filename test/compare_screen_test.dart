import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/features/compare/compare_screen.dart';
import 'package:mon_carburant_app/providers/comparison_provider.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

Station _station(String id, {double? gazole, double? sp95}) => Station(
  id: id,
  cp: '75001',
  dep: '75',
  ville: 'Ville $id',
  adresse: '1 rue $id',
  lat: 48.85,
  lng: 2.35,
  pop: 'route',
  prices: {'Gazole': ?gazole, 'SP95': ?sp95},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

class _FixedStations extends StationsNotifier {
  _FixedStations(this.stations);

  final List<Station> stations;

  @override
  Future<List<Station>> build() async => stations;
}

Future<void> _pumpCompare(
  WidgetTester tester, {
  required List<Station> stations,
  required List<String> compared,
}) async {
  final container = ProviderContainer(
    overrides: [stationsProvider.overrideWith(() => _FixedStations(stations))],
  );
  addTearDown(container.dispose);
  // Laisse l'AsyncNotifier produire sa valeur avant le premier rendu, sinon
  // l'écran ne voit qu'une liste vide.
  await container.read(stationsProvider.future);
  container.read(comparisonProvider.notifier).replaceWith(compared);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CompareScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('quatre stations tiennent dans le tableau', (tester) async {
    final stations = [
      _station('a', gazole: 1.759),
      _station('b', gazole: 1.709),
      _station('c', gazole: 1.802),
      _station('d', gazole: 1.75),
    ];

    await _pumpCompare(
      tester,
      stations: stations,
      compared: ['a', 'b', 'c', 'd'],
    );

    for (final station in stations) {
      expect(find.text(station.ville), findsWidgets, reason: station.id);
    }
    // Les colonnes défilent : aucune ne doit déborder de la largeur du
    // téléphone au passage de deux à quatre stations.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "l'écart avec la moins chère est affiché, pas seulement le prix",
    (tester) async {
      await _pumpCompare(
        tester,
        stations: [_station('a', gazole: 1.759), _station('b', gazole: 1.709)],
        compared: ['a', 'b'],
      );

      // 1,759 − 1,709 = 0,050 €/L, et la gagnante est nommée comme telle.
      expect(find.text('+0,050 €'), findsOneWidget);
      expect(find.text('la moins chère'), findsWidgets);
    },
  );

  testWidgets('une station sans le carburant ne passe pas pour la plus chère', (
    tester,
  ) async {
    await _pumpCompare(
      tester,
      stations: [_station('a', gazole: 1.759), _station('b', sp95: 1.899)],
      compared: ['a', 'b'],
    );

    // Une seule propose du gazole : le verdict le dit au lieu de la déclarer
    // gagnante d'une comparaison qui n'a pas eu lieu.
    expect(
      find.textContaining('Une seule des stations sélectionnées'),
      findsOneWidget,
    );
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('sans sélection, l écran invite à en choisir', (tester) async {
    await _pumpCompare(tester, stations: const [], compared: const []);

    expect(
      find.textContaining('jusqu\'à $kMaxComparedStations stations'),
      findsOneWidget,
    );
  });

  testWidgets('chaque case reste en face de son carburant et de sa station', (
    tester,
  ) async {
    // Le SP95 manque chez b et c : leurs cases de la 2e ligne affichent « — ».
    await _pumpCompare(
      tester,
      stations: [
        _station('a', gazole: 1.759, sp95: 1.899),
        _station('b', gazole: 1.709),
        _station('c', gazole: 1.802),
      ],
      compared: ['a', 'b', 'c'],
    );

    final dash = find.text('—').last; // colonne c, ligne SP95
    // Même hauteur que l'étiquette de la ligne (le premier « SP95 » est
    // celui du sélecteur de carburant)…
    expect(
      tester.getCenter(dash).dy,
      moreOrLessEquals(
        tester.getCenter(find.text('SP95').last).dy,
        epsilon: 0.5,
      ),
    );
    // … et même axe que l'en-tête de la colonne.
    expect(
      tester.getCenter(dash).dx,
      moreOrLessEquals(
        tester.getCenter(find.text('Ville c').first).dx,
        epsilon: 0.5,
      ),
    );
  });
}
