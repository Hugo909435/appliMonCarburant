import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/features/home/widgets/map_filter_bar.dart';
import 'package:mon_carburant_app/providers/filters_provider.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

void main() {
  Future<ProviderContainer> pumpBar(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [departmentsDataProvider.overrideWith((ref) async => {})],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              // Largeur d'un téléphone : tous les filtres ne tiennent pas.
              child: SizedBox(width: 320, child: MapFilterBar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('une flèche signale les filtres cachés et fait défiler', (
    tester,
  ) async {
    await pumpBar(tester);
    final arrow = find.byTooltip('Plus de filtres');
    expect(arrow, findsOneWidget);

    final before = tester.getTopLeft(find.text('Filtres')).dx;
    await tester.tap(arrow);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Filtres')).dx, lessThan(before));
  });

  testWidgets('le bouton Filtres compte les filtres actifs et les efface', (
    tester,
  ) async {
    final container = await pumpBar(tester);

    await tester.tap(find.text('Filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Filtres des stations'), findsOneWidget);
    expect(find.text('Tout effacer'), findsNothing);

    await tester.tap(find.text('Favoris uniquement'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesOnlyProvider), isTrue);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesOnlyProvider), isFalse);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('un filtre actif passe en tête de la ligne', (tester) async {
    final container = await pumpBar(tester);
    container.read(highwayFilterProvider.notifier).state = 'A6';
    await tester.pumpAndSettle();

    final labels = [
      for (final t in tester.widgetList<Text>(
        find.byType(Text, skipOffstage: false),
      ))
        t.data,
    ];
    // Juste après le carburant, avant les filtres inactifs.
    expect(labels.indexOf('A6'), labels.indexOf('Carburant') + 1);
    expect(labels.indexOf('A6'), lessThan(labels.indexOf('Enseigne')));
  });
}
