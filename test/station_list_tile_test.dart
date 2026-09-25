import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/fuel_type.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/shared/widgets/station_list_tile.dart';

const _station = Station(
  id: '1',
  cp: '06000',
  dep: '06',
  ville: 'Nice',
  adresse: '57, av. J.Raybaud',
  lat: 43.7,
  lng: 7.26,
  pop: 'R',
  prices: {'Gazole': 2.25},
  priceUpdates: {},
  services: [],
  horaires: null,
  automate: false,
);

Future<void> _pumpTile(
  WidgetTester tester, {
  required VoidCallback onTap,
  VoidCallback? onMore,
}) async {
  // Largeur d'un téléphone étroit : le lien ne doit rien faire déborder.
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: StationListTile(
            station: _station,
            fuel: FuelType.gazole,
            onTap: onTap,
            onMore: onMore,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('toucher la ligne et « Voir plus » font deux choses distinctes', (
    tester,
  ) async {
    var taps = 0;
    var mores = 0;
    await _pumpTile(tester, onTap: () => taps++, onMore: () => mores++);

    await tester.tap(find.text('Nice'));
    expect((taps, mores), (1, 0));

    await tester.tap(find.text('Voir plus'));
    expect((taps, mores), (1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans fiche à ouvrir à part, pas de « Voir plus »', (
    tester,
  ) async {
    await _pumpTile(tester, onTap: () {});

    expect(find.text('Voir plus'), findsNothing);
  });
}
