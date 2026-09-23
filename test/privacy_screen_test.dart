import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/features/privacy/privacy_screen.dart';

/// L'écran de confidentialité doit rester le miroir de
/// `docs/politique-confidentialite.md`, que le validateur Apple lit par son
/// URL publique. Ces tests ne valident pas la prose ; ils empêchent qu'une
/// section disparaisse sans qu'on s'en aperçoive.
void main() {
  Future<void> pump(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));

  testWidgets('l’absence de publicité et de traçage est affirmée d’entrée', (
    tester,
  ) async {
    await pump(tester);

    // C'est ce qui justifie « Non » à la colonne Suivi des déclarations de
    // confidentialité de l'App Store.
    expect(find.textContaining('ni publicité'), findsOneWidget);
    expect(find.textContaining('ne vend, ne loue'), findsOneWidget);
  });

  testWidgets('chaque sujet déclaré dans PrivacyInfo.xcprivacy a sa section', (
    tester,
  ) async {
    await pump(tester);

    // Les sections sont listées dans l'ordre de la page : le défilement
    // cumulé les fait défiler une à une jusqu'au bas.
    for (final section in const [
      'Votre position',
      'Prix des carburants',
      'Cartes et itinéraires',
      'Compte et favoris',
      'Rapports de plantage',
      'Vos données de véhicule',
      'Vos droits',
    ]) {
      final finder = find.text(section);
      await _scrollTo(tester, finder);
      expect(finder, findsOneWidget, reason: 'section « $section »');
    }
  });

  testWidgets('le bas de page porte le contact et la date', (tester) async {
    await pump(tester);

    final footer = find.textContaining('Dernière mise à jour');
    await _scrollTo(tester, footer);

    expect(footer, findsOneWidget);
    // L'adresse de contact est ce qui rend la section « Vos droits »
    // actionnable : sans elle, la promesse RGPD est creuse.
    expect(find.textContaining('contact@mon-carburant.com'), findsWidgets);
  });
}

/// Fait défiler la page jusqu'à [finder]. La liste est paresseuse : ce qui
/// est sous la ligne de flottaison n'existe pas encore dans l'arbre.
Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
