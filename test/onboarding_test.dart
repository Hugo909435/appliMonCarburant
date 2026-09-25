import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/features/onboarding/onboarding_screen.dart';
import 'package:mon_carburant_app/providers/onboarding_provider.dart';
import 'package:mon_carburant_app/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingNotifier.skipForExistingInstall', () {
    test('shows the onboarding on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await OnboardingNotifier.skipForExistingInstall(prefs);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingDoneProvider), isFalse);
    });

    test('still shows it after a first launch left unfinished', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await OnboardingNotifier.skipForExistingInstall(prefs);
      // Écrit par le premier téléchargement, pendant l'accueil.
      await prefs.setString('national_price_history', '{}');

      // Relance à froid, accueil jamais terminé.
      await OnboardingNotifier.skipForExistingInstall(prefs);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingDoneProvider), isFalse);
    });

    test('skips it for an app installed before it existed', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_station_ids': ['1'],
      });
      final prefs = await SharedPreferences.getInstance();
      await OnboardingNotifier.skipForExistingInstall(prefs);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingDoneProvider), isTrue);
    });
  });

  testWidgets('walks through the steps, each one skippable', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Plus d'étape « Voiture » : l'accueil commence par la localisation.
    expect(find.text('Votre voiture'), findsNothing);
    expect(find.text('Les stations autour de vous'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    // Puis les alertes, passées aussi — l'accueil est terminé.
    expect(find.text('Restez informé des baisses'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingDoneProvider), isTrue);
  });
}
