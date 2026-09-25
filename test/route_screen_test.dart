import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/route_corridor.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/data/services/geocoding_service.dart';
import 'package:mon_carburant_app/data/services/routing_service.dart';
import 'package:mon_carburant_app/features/route/route_screen.dart';
import 'package:mon_carburant_app/providers/map_search_provider.dart';
import 'package:mon_carburant_app/providers/routing_provider.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

const _paris = GeocodingResult(
  label: 'Paris, France',
  lat: 48.8566,
  lng: 2.3522,
);
const _versailles = GeocodingResult(
  label: 'Versailles, France',
  lat: 48.8049,
  lng: 2.1204,
);
const _marseille = GeocodingResult(
  label: 'Marseille, France',
  lat: 43.2965,
  lng: 5.3698,
);

class _FakeGeocoding implements GeocodingService {
  @override
  Future<List<GeocodingResult>> search(String query) async => const [
    _paris,
    _versailles,
    _marseille,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Répond à chaque demande quand le test le décide, pour choisir l'ordre
/// d'arrivée des réponses.
class _FakeRouting implements RoutingService {
  final pending = <RoutePoint, Completer<RouteResult>>{};

  @override
  Future<RouteResult> route(RoutePoint from, RoutePoint to) =>
      (pending[to] = Completer<RouteResult>()).future;

  void answer(GeocodingResult to, RouteResult result) => pending.entries
      .firstWhere((e) => e.key.lat == to.lat && e.key.lng == to.lng)
      .value
      .complete(result);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RouteResult _route(GeocodingResult from, GeocodingResult to, double km) =>
    RouteResult(
      points: [RoutePoint(from.lat, from.lng), RoutePoint(to.lat, to.lng)],
      distanceKm: km,
      duration: Duration(minutes: km.round()),
    );

class _NoStations extends StationsNotifier {
  @override
  Future<List<Station>> build() async => const [];
}

Future<_FakeRouting> _pumpRoute(WidgetTester tester) async {
  final routing = _FakeRouting();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        geocodingServiceProvider.overrideWithValue(_FakeGeocoding()),
        routingServiceProvider.overrideWithValue(routing),
        stationsProvider.overrideWith(_NoStations.new),
      ],
      child: const MaterialApp(home: RouteScreen()),
    ),
  );
  await tester.pump();
  return routing;
}

/// Ouvre le choix d'un lieu depuis le bouton [current], cherche, puis
/// choisit [place].
Future<void> _pick(
  WidgetTester tester,
  String current,
  GeocodingResult place,
) async {
  await tester.tap(find.text(current));
  // Pas de pumpAndSettle : pendant un calcul, l'indicateur tourne sans fin.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.byType(TextField), 'ville');
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
  await tester.tap(find.text(place.label.split(',').first).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Comme [testWidgets], sans les échecs de chargement des tuiles : le client
/// HTTP de test répond 400 à tout, et ce n'est pas ce qui est testé ici.
void _testWithMap(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    final report = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      report?.call(details);
    };
    try {
      await body(tester);
    } finally {
      FlutterError.onError = report;
    }
  });
}

void main() {
  _testWithMap('une réponse lente n’écrase pas l’itinéraire demandé ensuite', (
    tester,
  ) async {
    final routing = await _pumpRoute(tester);
    await _pick(tester, 'Ma position', _paris);

    await _pick(tester, 'Où allez-vous ?', _marseille);
    // Changement d'avis avant la réponse : la destination proche répond vite…
    await _pick(tester, 'Marseille', _versailles);
    routing.answer(_versailles, _route(_paris, _versailles, 20));
    await tester.pump();
    // … et la lointaine, demandée avant, arrive après.
    routing.answer(_marseille, _route(_paris, _marseille, 775));
    await tester.pump();

    expect(find.text('Versailles'), findsOneWidget);
    expect(find.textContaining('20 km'), findsOneWidget);
    expect(find.textContaining('775 km'), findsNothing);
  });

  _testWithMap(
    'départ et arrivée confondus n’empêchent pas d’afficher la carte',
    (tester) async {
      final routing = await _pumpRoute(tester);
      await _pick(tester, 'Ma position', _paris);
      await _pick(tester, 'Où allez-vous ?', _paris);

      // Ce que renvoie OSRM dans ce cas : deux fois le même point.
      routing.answer(_paris, _route(_paris, _paris, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('0 km'), findsOneWidget);
    },
  );
}
