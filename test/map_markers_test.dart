import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/ev_station.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/features/home/home_screen.dart';

Station _station(int i, {required double lat, required double lng}) => Station(
  id: '$i',
  cp: '06000',
  dep: '06',
  ville: 'Nice',
  adresse: '$i avenue',
  lat: lat,
  lng: lng,
  pop: 'R',
  prices: {'Gazole': 1.6 + i / 1000},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

/// [count] stations serrées sur une dizaine de kilomètres autour de Nice,
/// comme sur la côte des Alpes-Maritimes.
List<Station> _aroundNice(int count) => [
  for (var i = 0; i < count; i++)
    _station(i, lat: 43.66 + (i % 12) * 0.008, lng: 7.15 + (i ~/ 12) * 0.012),
];

({List<Station> stations, MarkerMode mode}) _shown(
  List<Station> stations, {
  required double zoom,
  bool zoneFiltered = false,
  Set<String> favoriteIds = const {},
}) => markerStations(
  stations,
  zoom: zoom,
  zoneFiltered: zoneFiltered,
  fuelCode: 'Gazole',
  favoriteIds: favoriteIds,
);

void main() {
  final stations = _aroundNice(120);

  group('sans filtre de zone', () {
    test('de plus en plus de stations apparaissent en zoomant', () {
      final counts = [
        for (final zoom in [8.0, 10.0, 11.0, 12.0, 13.0, 14.0])
          _shown(stations, zoom: zoom).stations.length,
      ];

      for (var i = 1; i < counts.length; i++) {
        expect(
          counts[i],
          greaterThanOrEqualTo(counts[i - 1]),
          reason: 'zooms successifs : $counts',
        );
      }
      // Vue large : écrémée ; au plus près avant les regroupements : bien plus.
      expect(counts.first, lessThan(10));
      expect(counts.last, greaterThan(counts.first * 5));
    });

    test('toutes apparaissent au zoom le plus proche', () {
      final shown = _shown(stations, zoom: 15);

      expect(shown.stations, hasLength(120));
      expect(shown.mode, MarkerMode.clustered);
    });

    test('vue large : la moins chère de chaque case et les favoris', () {
      final shown = _shown(stations, zoom: 8, favoriteIds: {'119'});
      final ids = shown.stations.map((s) => s.id);

      expect(ids, contains('0')); // la moins chère de toutes
      expect(ids, contains('119')); // favori, pourtant la plus chère
    });
  });

  group('département ou autoroute choisi', () {
    test('toutes les stations de la zone, même en vue large', () {
      final shown = _shown(stations, zoom: 8, zoneFiltered: true);

      expect(shown.stations, hasLength(120));
      expect(shown.mode, MarkerMode.plain);
      // Les moins chères en dernier, dessinées par-dessus les autres.
      expect(shown.stations.last.id, '0');
      expect(shown.stations.first.id, '119');
    });

    test('toutes aussi en zoomant, regroupées là où elles se chevauchent', () {
      for (final zoom in [12.0, 13.0, 14.0, 15.0]) {
        final shown = _shown(stations, zoom: zoom, zoneFiltered: true);
        expect(shown.stations, hasLength(120), reason: 'zoom $zoom');
        expect(shown.mode, MarkerMode.clustered, reason: 'zoom $zoom');
      }
    });

    test('au-delà de quelques centaines, l’écrémage reste de mise', () {
      final many = _aroundNice(700);

      final shown = _shown(many, zoom: 8, zoneFiltered: true);

      expect(shown.stations.length, lessThan(700));
    });
  });

  group('bornes', () {
    EvStation borne(int i, {required double kw}) => EvStation(
      id: '$i',
      name: 'Borne $i',
      network: '',
      address: '',
      lat: 43.66 + (i % 12) * 0.008,
      lng: 7.15 + (i ~/ 12) * 0.012,
      pointCount: 1,
      maxPowerKw: kw,
      plugTypes: const [],
      free: false,
    );

    test('en vue large, la plus puissante de chaque case seulement', () {
      final bornes = [
        for (var i = 0; i < 120; i++) borne(i, kw: i == 57 ? 350 : 22),
      ];

      final shown = markerEvStations(bornes, zoom: 8);

      expect(shown.mode, MarkerMode.plain);
      expect(shown.stations.length, lessThan(120));
      expect(shown.stations.map((e) => e.id), contains('57'));
    });

    test('au niveau de la rue, toutes, regroupées', () {
      final bornes = [for (var i = 0; i < 120; i++) borne(i, kw: 22)];

      final shown = markerEvStations(bornes, zoom: 15);

      expect(shown.mode, MarkerMode.clustered);
      expect(shown.stations, hasLength(120));
    });
  });
}
