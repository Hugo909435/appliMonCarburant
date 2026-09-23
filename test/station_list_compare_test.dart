import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/shared/widgets/station_list_screen.dart';

Station _station(String id, double gazole) => Station(
  id: id,
  cp: '75001',
  dep: '75',
  ville: 'Ville $id',
  adresse: '1 rue $id',
  lat: 48.85,
  lng: 2.35,
  pop: 'route',
  prices: {'Gazole': gazole},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

Future<void> _pumpList(
  WidgetTester tester, {
  required List<Station> stations,
  required bool comparePrices,
}) async {
  // Largeur d'un téléphone étroit : c'est là que la mention d'écart risque de
  // pousser le prix hors de la ligne.
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: StationListScreen(
          title: 'Mes favoris',
          stations: stations,
          comparePrices: comparePrices,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('une liste comparée situe chaque station par rapport à la moins '
      'chère', (tester) async {
    await _pumpList(
      tester,
      stations: [
        _station('a', 1.759),
        _station('b', 1.709),
        _station('c', 1.802),
      ],
      comparePrices: true,
    );

    expect(find.text('la moins chère'), findsOneWidget);
    expect(find.text('+0,050 €'), findsOneWidget);
    expect(find.text('+0,093 €'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une liste ordinaire ne montre que les prix', (tester) async {
    // L'écart avec la moins chère d'un département entier ne veut rien dire :
    // la mention ne doit apparaître que là où l'utilisateur a choisi le lot.
    await _pumpList(
      tester,
      stations: [_station('a', 1.759), _station('b', 1.709)],
      comparePrices: false,
    );

    expect(find.text('la moins chère'), findsNothing);
    expect(find.textContaining('+0,'), findsNothing);
  });
}
