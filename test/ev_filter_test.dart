import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/ev_station.dart';

EvStation _borne({
  List<String> plugs = const ['Type 2'],
  String operatorName = 'IZIVIA',
  double kw = 22,
  bool free = false,
}) => EvStation(
  id: 'x',
  name: 'Borne',
  network: '',
  operatorName: operatorName,
  address: '',
  lat: 48.8,
  lng: 2.3,
  pointCount: 2,
  maxPowerKw: kw,
  plugTypes: plugs,
  free: free,
);

void main() {
  group('puissance', () {
    test('les puissances publiées en watts sont ramenées en kW', () {
      expect(evPowerKw(22000), 22);
      expect(evPowerKw(7400), 7.4);
      expect(evPowerKw(350), 350);
      expect(evPowerKw(null), isNull);
    });

    test('une borne en watts garde sa vraie puissance', () {
      final station = EvStation.fromRecords('a', [
        {'puissance_nominale': 22000, 'prise_type_2': 'True', 'pdc': 2},
      ]);
      expect(station.maxPowerKw, 22);
    });
  });

  group('connecteurs', () {
    test('lus quelle que soit la casse, domestique et type 3 compris', () {
      final station = EvStation.fromRecords('a', [
        {
          'prise_type_2': 'TRUE',
          'prise_type_ef': 'true',
          'prise_type_autre': '1',
          'prise_type_combo_ccs': 'False',
          'prise_type_chademo': '0',
        },
      ]);
      expect(station.plugTypes, ['Type 2', 'Domestique', 'Type 3']);
    });
  });

  group('opérateurs', () {
    test('les orthographes qui ne diffèrent que par la casse fusionnent', () {
      final operators = EvOperator.merge({
        'LIDL France': 5562,
        'Lidl France': 5127,
        'IZIVIA': 16467,
        ' ': 3,
      });

      expect(operators.map((o) => o.name), ['IZIVIA', 'LIDL France']);
      final lidl = operators.last;
      expect(lidl.pointCount, 10689);
      expect(lidl.spellings, unorderedEquals(['LIDL France', 'Lidl France']));
      expect(lidl.runs('Lidl France'), isTrue);
      expect(lidl.runs('Lidl'), isFalse);
    });
  });

  group('filtre', () {
    const lidl = EvOperator(
      name: 'LIDL France',
      spellings: ['LIDL France', 'Lidl "FR"'],
      pointCount: 1,
    );

    test('vide : aucune condition', () {
      const filter = EvFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.where, isEmpty);
    });

    test('écrit les conditions pour l’API', () {
      const filter = EvFilter(plug: 'Type 3', evOperator: lidl, minPowerKw: 50);
      expect(
        filter.where,
        '(lower(prise_type_autre) = "true" or prise_type_autre = "1") and '
        r'nom_operateur in ("LIDL France","Lidl \"FR\"") and '
        '((puissance_nominale >= 50 and puissance_nominale <= 1000.0) or '
        'puissance_nominale >= 50000)',
      );
    });

    test('accepte seulement les bornes qui passent chaque critère', () {
      const filter = EvFilter(plug: 'Combo CCS', minPowerKw: 50);
      expect(filter.accepts(_borne(plugs: ['Combo CCS'], kw: 150)), isTrue);
      expect(filter.accepts(_borne(plugs: ['Type 2'], kw: 150)), isFalse);
      expect(filter.accepts(_borne(plugs: ['Combo CCS'], kw: 22)), isFalse);

      const byOperator = EvFilter(evOperator: lidl);
      expect(byOperator.accepts(_borne(operatorName: 'Lidl France')), isTrue);
      expect(byOperator.accepts(_borne(operatorName: 'IZIVIA')), isFalse);
    });

    test('deux filtres identiques sont égaux', () {
      expect(
        const EvFilter(plug: 'Type 2', minPowerKw: 7),
        const EvFilter(plug: 'Type 2', minPowerKw: 7),
      );
      expect(
        const EvFilter(plug: 'Type 2'),
        isNot(const EvFilter(plug: 'Type 3')),
      );
    });
  });
}
