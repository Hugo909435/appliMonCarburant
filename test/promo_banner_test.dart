import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/promo_annonce.dart';
import 'package:mon_carburant_app/providers/promo_provider.dart';
import 'package:mon_carburant_app/shared/widgets/promo_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const annonce = PromoAnnonce(
    id: 'promo-1',
    titre: 'Prix coûtant',
    message: 'Carrefour à prix coûtant ce week-end.',
    actif: true,
  );

  Future<void> pumpBanner(WidgetTester tester, PromoAnnonce? published) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promoAnnonceProvider.overrideWith((ref) => Stream.value(published)),
        ],
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: PromoBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows nothing when no annonce is published', (tester) async {
    await pumpBanner(tester, null);
    expect(find.text('Prix coûtant'), findsNothing);
  });

  testWidgets('shows the published annonce', (tester) async {
    await pumpBanner(tester, annonce);
    expect(find.text('Prix coûtant'), findsOneWidget);
    expect(find.text('Carrefour à prix coûtant ce week-end.'), findsOneWidget);
  });

  testWidgets('closing hides it and remembers the campaign', (tester) async {
    await pumpBanner(tester, annonce);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Prix coûtant'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('dismissed_promo_ids'), ['promo-1']);
  });

  testWidgets('stays hidden for a campaign already closed', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dismissed_promo_ids': ['promo-1'],
    });
    await pumpBanner(tester, annonce);
    expect(find.text('Prix coûtant'), findsNothing);
  });

  testWidgets('comes back when the campaign id changes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dismissed_promo_ids': ['promo-1'],
    });
    await pumpBanner(
      tester,
      const PromoAnnonce(
        id: 'promo-2',
        titre: 'Prix coûtant',
        message: 'Nouvelle opération.',
        actif: true,
      ),
    );
    expect(find.text('Nouvelle opération.'), findsOneWidget);
  });
}
