import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/theme/app_theme.dart';

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Seuil WCAG AA pour un élément graphique non textuel.
const _minIconContrast = 3.0;

/// Seuil WCAG AA pour du texte courant.
const _minTextContrast = 4.5;

/// L'encre de la charte, un bleu nuit (#0F2D3F), est à un cheveu du fond
/// sombre (#070D12/#111B22). Une couleur d'icône écrite en dur plutôt
/// que laissée au thème y tombe sous 1,5:1 — invisible.
///
/// Ces tests mesurent la couleur *effective* reçue par une icône posée dans un
/// `ListTile` ou un `Chip`, c'est-à-dire ce que voit l'utilisateur, et non ce
/// que déclare le thème. Ils sont écrits en `testWidgets` pour la même raison :
/// construire un thème hors d'un widget déclenche, via google_fonts, une
/// erreur asynchrone qui vient salir un test au hasard.
void main() {
  /// Monte [child] sous [theme] et rend la couleur dont hérite [icon].
  Future<Color> effectiveIconColor(
    WidgetTester tester,
    ThemeData theme,
    Widget child,
    IconData icon,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    final color = IconTheme.of(tester.element(find.byIcon(icon))).color;
    expect(color, isNotNull, reason: 'aucune couleur héritée');
    return color!;
  }

  for (final (name, build) in [
    ('clair', () => AppTheme.light),
    ('sombre', () => AppTheme.dark),
  ]) {
    group('thème $name', () {
      testWidgets('une icône de ListTile ressort sur la surface', (
        tester,
      ) async {
        final theme = build();
        final color = await effectiveIconColor(
          tester,
          theme,
          const ListTile(
            leading: Icon(Icons.access_time_filled_rounded),
            title: Text('Automate 24h/24'),
          ),
          Icons.access_time_filled_rounded,
        );

        expect(
          _contrast(color, theme.colorScheme.surface),
          greaterThanOrEqualTo(_minIconContrast),
        );
      });

      testWidgets('un avatar de Chip ressort sur la puce', (tester) async {
        // Sans `chipTheme.iconTheme`, Material retombe sur une couleur d'icône
        // pensée pour un fond clair, qui disparaît en thème sombre.
        final theme = build();
        final color = await effectiveIconColor(
          tester,
          theme,
          const Chip(
            avatar: Icon(Icons.check_circle_rounded, size: 16),
            label: Text('Boutique'),
          ),
          Icons.check_circle_rounded,
        );

        expect(
          _contrast(color, theme.chipTheme.backgroundColor!),
          greaterThanOrEqualTo(_minIconContrast),
        );
      });

      for (final selected in [false, true]) {
        testWidgets(
          'le libellé d’une pastille ${selected ? 'choisie' : 'libre'} '
          'se lit',
          (tester) async {
            // Le carburant choisi s'affichait bleu nuit sur bleu nuit.
            final theme = build();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Center(
                    child: ChoiceChip(
                      label: const Text('Gazole'),
                      selected: selected,
                      onSelected: (_) {},
                    ),
                  ),
                ),
              ),
            );
            final label = tester.widget<RichText>(
              find.descendant(
                of: find.text('Gazole'),
                matching: find.byType(RichText),
              ),
            );
            final background = selected
                ? theme.chipTheme.selectedColor!
                : theme.chipTheme.backgroundColor!;

            expect(
              _contrast(label.text.style!.color!, background),
              greaterThanOrEqualTo(_minTextContrast),
            );
          },
        );
      }
    });
  }
}
