import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/price_deals.dart';

/// Historique d'une station : un prix par jour, les [days] jours précédant
/// [today].
Map<String, double> _pastDays(DateTime today, int days, double price) => {
  for (var i = 1; i <= days; i++)
    dayKey(today.subtract(Duration(days: i))): price,
};

void main() {
  final today = DateTime(2026, 9, 24);

  group('usualPrice', () {
    test('is the median, unmoved by a one-off outlier', () {
      expect(
        usualPrice([1.80, 1.81, 1.79, 1.80, 1.80, 1.82, 0.99]),
        closeTo(1.80, 1e-9),
      );
    });

    test('is unknown with less than a week of prices', () {
      expect(usualPrice([1.80, 1.80, 1.80]), isNull);
    });
  });

  group('findPriceDeals', () {
    test('flags a price 10 cents under the usual one', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(
          daily: {'a': _pastDays(today, 10, 1.899)},
        ),
        current: {'a': 1.799},
        favorites: {'a'},
        today: today,
      );

      expect(result.deals.single.stationId, 'a');
      expect(result.deals.single.saving, closeTo(0.10, 1e-9));
      expect(result.history.alerted, {'a'});
    });

    test('ignores smaller drops', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(
          daily: {'a': _pastDays(today, 10, 1.899)},
        ),
        current: {'a': 1.829},
        favorites: {'a'},
        today: today,
      );

      expect(result.deals, isEmpty);
    });

    test('waits for a week of history before alerting', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(daily: {'a': _pastDays(today, 3, 1.899)}),
        current: {'a': 1.599},
        favorites: {'a'},
        today: today,
      );

      expect(result.deals, isEmpty);
      expect(result.history.daily['a'], hasLength(4));
    });

    test('alerts once per deal, and again after the price went back up', () {
      final history = FavoritePriceHistory(
        daily: {'a': _pastDays(today, 10, 1.899)},
        alerted: {'a'},
      );

      final stillLow = findPriceDeals(
        history: history,
        current: {'a': 1.779},
        favorites: {'a'},
        today: today,
      );
      expect(stillLow.deals, isEmpty);
      expect(stillLow.history.alerted, {'a'});

      final backUp = findPriceDeals(
        history: history,
        current: {'a': 1.889},
        favorites: {'a'},
        today: today,
      );
      expect(backUp.history.alerted, isEmpty);
    });

    test('holds a deal back when notifying is off for today', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(
          daily: {'a': _pastDays(today, 10, 1.899)},
        ),
        current: {'a': 1.699},
        favorites: {'a'},
        today: today,
        notify: false,
      );

      expect(result.deals, isEmpty);
      // Pas marquée : elle partira demain si elle tient toujours.
      expect(result.history.alerted, isEmpty);
    });

    test('keeps the history of an unpriced favorite, drops removed ones', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(
          daily: {
            'a': _pastDays(today, 5, 1.899),
            'gone': _pastDays(today, 5, 1.899),
          },
        ),
        current: const {},
        favorites: {'a'},
        today: today,
      );

      expect(result.history.daily.keys, ['a']);
    });

    test('forgets prices older than the 30-day window', () {
      final result = findPriceDeals(
        history: FavoritePriceHistory(
          daily: {'a': _pastDays(today, 40, 1.899)},
        ),
        current: {'a': 1.899},
        favorites: {'a'},
        today: today,
      );

      // 29 jours passés dans la fenêtre, plus aujourd'hui.
      expect(result.history.daily['a'], hasLength(30));
    });
  });
}
