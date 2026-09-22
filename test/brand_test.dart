import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/brands/brand_catalog.dart';
import 'package:mon_carburant_app/core/brands/brand_matching.dart';
import 'package:mon_carburant_app/core/brands/brand_rules.dart';
import 'package:mon_carburant_app/data/models/station.dart';

Station _station(String id, double lat, double lng) => Station(
  id: id,
  cp: '75001',
  dep: '75',
  ville: 'Paris',
  adresse: '',
  lat: lat,
  lng: lng,
  pop: 'route',
  prices: const {'Gazole': 1.8},
  priceUpdates: const {},
  services: const [],
  horaires: null,
  automate: false,
);

void main() {
  group('brandKeyFor', () {
    test('recognizes the usual OSM spellings', () {
      expect(brandKeyFor('TotalEnergies', isBrandTag: true), 'totalenergies');
      expect(brandKeyFor('Total Access', isBrandTag: true), 'totalenergies');
      expect(brandKeyFor('E.Leclerc', isBrandTag: true), 'leclerc');
      expect(brandKeyFor('Intermarché', isBrandTag: true), 'intermarche');
      expect(brandKeyFor('Super U', isBrandTag: true), 'systemeu');
      expect(brandKeyFor('U', isBrandTag: true), 'systemeu');
      expect(brandKeyFor('Carrefour Market', isBrandTag: true), 'carrefour');
      expect(brandKeyFor('Station Esso Express', isBrandTag: false), 'esso');
    });

    test('matches whole words only', () {
      // "u" alone must not match inside other names.
      expect(brandKeyFor('Station du bourg', isBrandTag: false), isNull);
      expect(brandKeyFor('Totalement libre', isBrandTag: false), isNull);
    });

    test('keeps unknown brand tags but not unknown names', () {
      expect(brandKeyFor('Fulli', isBrandTag: true), 'other:Fulli');
      expect(brandKeyFor('Station service', isBrandTag: false), isNull);
      expect(brandKeyFor('Independent', isBrandTag: true), isNull);
    });

    test('every catalog key has display info', () {
      for (final key in ['totalenergies', 'leclerc', 'systemeu', 'spar']) {
        expect(brandForKey(key)?.isKnown, isTrue, reason: key);
      }
      expect(brandForKey('other:Fulli')?.short, 'F');
    });
  });

  group('matchStationBrands', () {
    test('pairs a station with its nearby OSM twin', () {
      final result = matchStationBrands(
        [_station('a', 48.85, 2.35)],
        [const OsmFuelPoi(48.8505, 2.3502, 'Esso', '')],
      );
      expect(result, {'a': 'esso'});
    });

    test("doesn't borrow a neighbour's brand", () {
      // Station "b" is missing from OSM; the only OSM point nearby is
      // station "a"'s, which is closer to "a".
      final result = matchStationBrands(
        [_station('a', 48.85, 2.35), _station('b', 48.8515, 2.35)],
        [const OsmFuelPoi(48.8501, 2.35, 'Shell', '')],
      );
      expect(result, {'a': 'shell'});
    });

    test('ignores points beyond the match radius', () {
      final result = matchStationBrands(
        [_station('a', 48.85, 2.35)],
        [const OsmFuelPoi(48.86, 2.35, 'BP', '')], // ~1.1 km
      );
      expect(result, isEmpty);
    });
  });

  test('parseOverpassCsv', () {
    final pois = parseOverpassCsv(
      '47.3\t4.5\tEni\tEni\nbad line\n46.9\t4.8\t\tRelais\n',
    );
    expect(pois, hasLength(2));
    expect(pois.last.brand, '');
    expect(pois.last.name, 'Relais');
  });
}
