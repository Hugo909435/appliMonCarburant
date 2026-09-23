import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/formatters.dart';
import 'package:mon_carburant_app/core/utils/price_gaps.dart';
import 'package:mon_carburant_app/providers/comparison_provider.dart';

void main() {
  group('priceGaps', () {
    test('la moins chère sert de référence, les autres se situent par rapport '
        'à elle', () {
      final gaps = priceGaps({'a': 1.759, 'b': 1.709, 'c': 1.802});

      expect(gaps['b']!.isCheapest, isTrue);
      expect(gaps['b']!.perLiter, 0);
      expect(gaps['a']!.perLiter, closeTo(0.05, 1e-9));
      expect(gaps['c']!.perLiter, closeTo(0.093, 1e-9));
    });

    test("une station qui ne propose pas le carburant sort de la comparaison", () {
      // Elle n'est pas « plus chère » : elle n'a pas de prix du tout, et la
      // compter comme dernière tromperait sur le classement.
      final gaps = priceGaps({'a': 1.759, 'b': null});

      expect(gaps.keys, ['a']);
      expect(gaps['a']!.isCheapest, isTrue);
    });

    test('sans aucun prix, il n y a rien à comparer', () {
      expect(priceGaps({'a': null, 'b': null}), isEmpty);
      expect(priceGaps({}), isEmpty);
    });

    test('à prix égal, toutes sont les moins chères', () {
      final gaps = priceGaps({'a': 1.75, 'b': 1.75});

      expect(gaps.values.every((gap) => gap.isCheapest), isTrue);
    });

    test("l'écart au litre devient un montant sur un plein", () {
      // Les trois millièmes d'euro au litre ne parlent pas ; les euros du
      // plein, si.
      final gaps = priceGaps({'a': 1.80, 'b': 1.75});

      expect(gaps['a']!.onFillUp(40), closeTo(2.0, 1e-9));
      expect(gaps['b']!.onFillUp(40), 0);
    });
  });

  group('formatPriceGap', () {
    test('un écart garde toujours son signe', () {
      // Sans le signe, « 0,043 € » se lirait comme un prix.
      expect(formatPriceGap(0.043), '+0,043 €');
      expect(formatPriceGap(0), '+0,000 €');
    });
  });

  group('sélection à comparer', () {
    ComparisonNotifier notifierIn(ProviderContainer container) =>
        container.read(comparisonProvider.notifier);

    test('on peut en retenir quatre', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final id in ['a', 'b', 'c', 'd']) {
        notifierIn(container).toggle(id);
      }

      expect(container.read(comparisonProvider), ['a', 'b', 'c', 'd']);
    });

    test('la cinquième chasse la plus ancienne au lieu de bloquer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final id in ['a', 'b', 'c', 'd', 'e']) {
        notifierIn(container).toggle(id);
      }

      expect(container.read(comparisonProvider), ['b', 'c', 'd', 'e']);
    });

    test('re-toucher une station la retire', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      notifierIn(container).toggle('a');
      notifierIn(container).toggle('b');
      notifierIn(container).toggle('a');

      expect(container.read(comparisonProvider), ['b']);
    });

    test('un envoi groupé est tronqué au maximum comparable', () {
      // Les favoris arrivent déjà triés du moins cher au plus cher : la
      // troncature garde donc les plus intéressants.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      notifierIn(container).replaceWith(['a', 'b', 'c', 'd', 'e', 'f']);

      expect(
        container.read(comparisonProvider),
        hasLength(kMaxComparedStations),
      );
      expect(container.read(comparisonProvider).first, 'a');
    });
  });
}
