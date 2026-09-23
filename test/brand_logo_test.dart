import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/brands/brand_catalog.dart';
import 'package:mon_carburant_app/core/brands/logo_metrics.dart';
import 'package:mon_carburant_app/providers/station_brands_provider.dart';
import 'package:mon_carburant_app/shared/widgets/brand_logo.dart';

/// Les tailles auxquelles l'app affiche un logo d'enseigne.
const _marker = 22.0; // totem de prix, puces de filtre
const _tile = 32.0; // lignes de liste
const _sheet = 44.0; // fiche station, feuille de station

/// Côté du logo dans la pastille ronde de la carte : le diamètre de 32 px
/// moins l'anneau de 2 px de part et d'autre (voir `_dotSize` dans
/// home_screen.dart).
const _dot = 28.0;

/// Monte un [BrandLogo] en faisant croire que tous les PNG d'enseigne sont
/// embarqués, ce que le bundle de test ne fournit pas.
Future<void> _pumpLogo(
  WidgetTester tester,
  FuelBrand brand, {
  required double size,
  required BrandLogoShape shape,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        brandLogoAssetsProvider.overrideWith(
          (ref) async => {'assets/logos/${brand.key}.png'},
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: BrandLogo(brand: brand, size: size, shape: shape)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('lisibilité du logo', () {
    test('un logo carré est montré jusque sur un marqueur de carte', () {
      // Avia et Eni remplissent tout le fichier.
      for (final key in ['avia', 'eni', 'shell', 'auchan']) {
        expect(
          shouldDrawLogo(key, _marker, hasAsset: true),
          isTrue,
          reason: key,
        );
      }
    });

    test('le dernier logotype large cède la place au badge', () {
      // Colruyt est la seule enseigne dont aucun symbole carré n'est publié :
      // ni sur son site, ni sur Commons, ni en icône d'application. Réduit à
      // 6 px de haut, son logo ne serait qu'une bavure.
      expect(shouldDrawLogo('colruyt', _marker, hasAsset: true), isFalse);
      expect(shouldDrawLogo('colruyt', _tile, hasAsset: true), isFalse);
      // La place d'une fiche suffit en revanche à le rendre lisible.
      expect(shouldDrawLogo('colruyt', _sheet, hasAsset: true), isTrue);
    });

    test('remplacer un logotype par un fichier carré le fait revenir', () {
      // Ces quatre-là étaient illisibles sur la carte. Leurs fichiers ont été
      // remplacés par une forme carrée de la même marque — le rond au « L »,
      // le sapin, la fleur, le logo sur deux lignes de l'app Intermarché —
      // et la mesure les fait repasser devant le badge, sans une ligne de
      // code changée.
      for (final key in ['leclerc', 'spar', 'casino', 'intermarche']) {
        expect(
          shouldDrawLogo(key, _marker, hasAsset: true),
          isTrue,
          reason: key,
        );
      }
    });

    test('sans fichier, jamais de logo, quelle que soit la taille', () {
      // Ecomarché n'a pas de PNG : c'est le badge, et rien d'autre.
      for (final size in [_marker, _tile, _sheet]) {
        expect(shouldDrawLogo('ecomarche', size, hasAsset: false), isFalse);
      }
    });

    test('une enseigne inconnue au fichier de mesures reste affichée', () {
      // Un logo ajouté sans relancer tool/measure_logos.dart ne doit pas
      // disparaître : en l'absence de mesure, on lui fait confiance.
      expect(
        shouldDrawLogo('enseigne_inedite', _marker, hasAsset: true),
        isTrue,
      );
    });
  });

  group('pastille ronde de la carte', () {
    test('le logo est jugé sur le carré inscrit, pas sur le diamètre', () {
      // Un rond ne laisse au dessin que le carré qui y est inscrit : juger
      // sa lisibilité sur le diamètre le montrerait rogné aux bords.
      expect(
        drawnLogoSize(_dot, BrandLogoShape.circle),
        lessThan(drawnLogoSize(_dot, BrandLogoShape.rounded)),
      );
      expect(drawnLogoSize(_dot, BrandLogoShape.rounded), _dot);
    });

    test('les logos carrés tiennent dans la pastille', () {
      final drawn = drawnLogoSize(_dot, BrandLogoShape.circle);
      for (final key in ['avia', 'eni', 'shell', 'leclerc', 'intermarche']) {
        expect(shouldDrawLogo(key, drawn, hasAsset: true), isTrue, reason: key);
      }
    });

    test('les logotypes les plus larges y repassent au badge', () {
      // Réduits au carré inscrit, Colruyt et Netto tombent sous le seuil de
      // lisibilité : le badge coloré dit alors l'enseigne mieux qu'eux.
      final drawn = drawnLogoSize(_dot, BrandLogoShape.circle);
      for (final key in ['colruyt', 'netto']) {
        expect(
          shouldDrawLogo(key, drawn, hasAsset: true),
          isFalse,
          reason: key,
        );
      }
    });
  });

  group('fichier de mesures', () {
    test('couvre tous les logos embarqués', () {
      // Garde-fou : un logo ajouté sans relancer l'outil de mesure serait
      // évalué à l'aveugle.
      expect(logoContentHeightFraction, isNotEmpty);
      for (final entry in logoContentHeightFraction.entries) {
        expect(
          entry.value,
          inInclusiveRange(0, 1),
          reason: '${entry.key} hors bornes',
        );
      }
    });
  });

  group('rendu de la pastille ronde', () {
    testWidgets('un logo lisible est dessiné, sans déborder du rond', (
      tester,
    ) async {
      final brand = brandForKey('leclerc')!;
      await _pumpLogo(
        tester,
        brand,
        size: _dot,
        shape: BrandLogoShape.circle,
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text(brand.short), findsNothing);
      // Le retrait confine le dessin au carré inscrit : c'est lui, et non un
      // clip, qui empêche le rond de rogner le logo.
      expect(
        tester.getSize(find.byType(Image)).width,
        closeTo(drawnLogoSize(_dot, BrandLogoShape.circle), 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un logotype illisible cède la place au badge', (tester) async {
      final brand = brandForKey('colruyt')!;
      await _pumpLogo(
        tester,
        brand,
        size: _dot,
        shape: BrandLogoShape.circle,
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text(brand.short), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
