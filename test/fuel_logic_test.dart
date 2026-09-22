import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/fill_cost.dart';
import 'package:mon_carburant_app/core/utils/route_corridor.dart';
import 'package:mon_carburant_app/data/models/station.dart';

Station _station(String id, double lat, double lng, {double gazole = 1.8}) =>
    Station(
      id: id,
      cp: '75001',
      dep: '75',
      ville: 'Ville $id',
      adresse: '',
      lat: lat,
      lng: lng,
      pop: 'route',
      prices: {'Gazole': gazole},
      priceUpdates: const {},
      services: const [],
      horaires: null,
      automate: false,
    );

void main() {
  group('computeFillCost', () {
    test('counts the round trip on the road at the station price', () {
      final cost = computeFillCost(
        pricePerLiter: 2,
        liters: 40,
        consumptionL100: 5,
        detourKm: 10,
      );
      expect(cost.fuelCost, 80);
      // 10 km × 1.3 road factor × 2 ways = 26 km → 1.3 L → 2.60 €
      expect(cost.tripKm, closeTo(26, 1e-9));
      expect(cost.tripCost, closeTo(2.6, 1e-9));
      expect(cost.total, closeTo(82.6, 1e-9));
    });

    test('a cheap far station can lose to a dearer close one', () {
      FillCost at(double price, double km) => computeFillCost(
        pricePerLiter: price,
        liters: 40,
        consumptionL100: 7,
        detourKm: km,
      );
      expect(at(1.75, 15).total, greaterThan(at(1.78, 1).total));
    });
  });

  group('stationsAlongRoute', () {
    // Straight west→east route along the 47th parallel, ~76 km long.
    const route = [RoutePoint(47, 2), RoutePoint(47, 3)];

    test('keeps stations inside the corridor with their km position', () {
      final result = stationsAlongRoute(
        route: route,
        corridorKm: 2,
        stations: [
          _station('on', 47.005, 2.5), // ~0.56 km north, mid-route
          _station('far', 47.1, 2.5), // ~11 km north
          _station('before', 47, 1.9), // before the start
        ],
      );
      expect(result.map((r) => r.station.id), ['on']);
      expect(result.single.offRouteKm, closeTo(0.56, 0.1));
      expect(result.single.kmFromStart, closeTo(38, 1));
    });

    test('orders results along the route', () {
      final result = stationsAlongRoute(
        route: route,
        corridorKm: 5,
        stations: [_station('b', 47, 2.8), _station('a', 47, 2.2)],
      );
      expect(result.map((r) => r.station.id), ['a', 'b']);
    });

    test('degenerate route yields nothing', () {
      expect(
        stationsAlongRoute(
          route: const [RoutePoint(47, 2)],
          corridorKm: 2,
          stations: [_station('x', 47, 2)],
        ),
        isEmpty,
      );
    });
  });
}
