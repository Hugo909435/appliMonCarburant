import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/features/home/widgets/home_tutorial.dart';
import 'package:mon_carburant_app/providers/preferences_provider.dart';
import 'package:mon_carburant_app/providers/tutorial_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// Une carte factice : seules comptent les commandes que le tutoriel
  /// éclaire, placées comme sur l'écran d'accueil.
  Future<ProviderContainer> pumpTutorial(
    WidgetTester tester, {
    bool pending = true,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'tutorial_pending_v1': pending});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final targets = TutorialTargets();
    Widget button(Key key) => SizedBox(key: key, width: 48, height: 48);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              // Sans animations, rien ne bat en boucle : pumpAndSettle rend
              // la main.
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 60,
                  right: 60,
                  height: 40,
                  child: SizedBox(key: targets.filters),
                ),
                Positioned(
                  right: 12,
                  bottom: 300,
                  child: Column(
                    children: [
                      button(targets.favorites),
                      button(targets.route),
                      button(targets.account),
                      button(targets.locate),
                    ],
                  ),
                ),
                HomeTutorial(targets: targets),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('stays out of the way until it is started', (tester) async {
    final container = await pumpTutorial(tester, pending: false);
    expect(find.text('Suivant'), findsNothing);

    container.read(tutorialProvider.notifier).start();
    await tester.pumpAndSettle();
    expect(find.text('Les prix sur la carte'), findsOneWidget);
  });

  testWidgets('walks through every control, then does not come back', (
    tester,
  ) async {
    final container = await pumpTutorial(tester);

    const titles = [
      'Les prix sur la carte',
      'Votre carburant',
      'Une adresse, une ville',
      'La liste des stations',
      'Vos favoris',
      'Le plein sur votre trajet',
      'Autour de vous',
      'Votre compte',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (title != titles.last) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
    }

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Votre compte'), findsNothing);
    expect(container.read(tutorialProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('tutorial_pending_v1'), isFalse);
  });

  testWidgets('can be skipped at any step', (tester) async {
    final container = await pumpTutorial(tester);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(find.text('Votre carburant'), findsNothing);
    expect(container.read(tutorialProvider), isFalse);
  });

  testWidgets('keeps its bubble on screen with enlarged text', (tester) async {
    await pumpTutorial(tester, textScale: 1.6);
    final screen = tester.getRect(find.byType(Scaffold));

    while (true) {
      expect(tester.takeException(), isNull);
      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('Passer').evaluate().isEmpty
                  ? find.text('Terminer')
                  : find.text('Passer'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(screen.contains(bubble.topLeft), isTrue, reason: '$bubble');
      expect(screen.contains(bubble.bottomRight), isTrue, reason: '$bubble');
      if (find.text('Suivant').evaluate().isEmpty) break;
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
  });
}
