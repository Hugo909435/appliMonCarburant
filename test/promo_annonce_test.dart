import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/promo_annonce.dart';

void main() {
  Map<String, dynamic> doc({
    Object? actif = true,
    String id = 'promo-1',
    String message = 'Carrefour à prix coûtant ce week-end.',
    Object? debut,
    Object? fin,
  }) => {
    'id': id,
    'actif': actif,
    'titre': 'Prix coûtant',
    'message': message,
    'debut': ?debut,
    'fin': ?fin,
  };

  final now = DateTime(2026, 10, 4, 12);

  group('PromoAnnonce.fromMap', () {
    test('parses a complete document', () {
      final annonce = PromoAnnonce.fromMap(
        doc(debut: '2026-10-03', fin: DateTime(2026, 10, 5)),
      )!;
      expect(annonce.id, 'promo-1');
      expect(annonce.titre, 'Prix coûtant');
      expect(annonce.debut, DateTime(2026, 10, 3));
      expect(annonce.fin, DateTime(2026, 10, 5));
      expect(annonce.hasLien, isFalse);
    });

    test('returns null when the document is missing or unusable', () {
      expect(PromoAnnonce.fromMap(null), isNull);
      expect(PromoAnnonce.fromMap(doc(id: '')), isNull);
      expect(PromoAnnonce.fromMap(doc(message: '   ')), isNull);
    });

    test('treats anything other than true as not published', () {
      expect(PromoAnnonce.fromMap(doc(actif: 'oui'))!.actif, isFalse);
      expect(PromoAnnonce.fromMap(doc(actif: null))!.actif, isFalse);
    });

    test('ignores an unparseable date instead of dropping the annonce', () {
      final annonce = PromoAnnonce.fromMap(doc(fin: 'du 3 au 5 octobre'))!;
      expect(annonce.fin, isNull);
      expect(annonce.isLiveAt(now), isTrue);
    });
  });

  group('isLiveAt', () {
    test('is visible only while published', () {
      expect(PromoAnnonce.fromMap(doc())!.isLiveAt(now), isTrue);
      expect(PromoAnnonce.fromMap(doc(actif: false))!.isLiveAt(now), isFalse);
    });

    test('respects the date window', () {
      final annonce = PromoAnnonce.fromMap(
        doc(debut: '2026-10-03', fin: '2026-10-05'),
      )!;
      expect(annonce.isLiveAt(DateTime(2026, 10, 2)), isFalse);
      expect(annonce.isLiveAt(now), isTrue);
      expect(annonce.isLiveAt(DateTime(2026, 10, 6)), isFalse);
    });
  });
}
