import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/shared/widgets/ad_slot.dart';

void main() {
  // Les tests tournent en debug : les emplacements sont affichés.

  List<String> layout(int count) {
    final ads = InFeedAds(count, first: 3, every: 4);
    return [
      for (var i = 0; i < ads.length; i++)
        ads.isAd(i) ? 'ad' : '${ads.itemIndex(i)}',
    ];
  }

  test('pas d’annonce dans une liste plus courte que le seuil', () {
    expect(layout(0), isEmpty);
    expect(layout(2), ['0', '1']);
  });

  test('première annonce après les premiers éléments', () {
    expect(layout(3), ['0', '1', '2', 'ad']);
    expect(layout(5), ['0', '1', '2', 'ad', '3', '4']);
  });

  test('puis une annonce toutes les `every` lignes, sans perdre d’élément', () {
    expect(layout(11), [
      '0', '1', '2', 'ad', //
      '3', '4', '5', '6', 'ad', //
      '7', '8', '9', '10', 'ad',
    ]);
  });
}
