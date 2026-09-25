import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_provider.dart';

/// Vrai une fois l'accueil en trois étapes terminé (ou passé).
class OnboardingNotifier extends Notifier<bool> {
  static const _doneKey = 'onboarding_done_v1';

  /// À appeler au lancement, avant que quoi que ce soit n'écrive dans les
  /// préférences. Des préférences déjà remplies trahissent une app installée
  /// avant l'arrivée de l'accueil : on ne le montre qu'aux nouveaux venus.
  ///
  /// Le verdict est enregistré dès ce premier lancement, « pas encore fait »
  /// compris : sinon, l'historique des prix écrit pendant l'accueil ferait
  /// passer un nouveau venu qui quitte l'app en route pour une ancienne
  /// installation, et l'accueil ne reviendrait plus jamais.
  static Future<void> skipForExistingInstall(SharedPreferences prefs) async {
    if (prefs.containsKey(_doneKey)) return;
    await prefs.setBool(_doneKey, prefs.getKeys().isNotEmpty);
  }

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // Sans préférences (tests), l'app démarre directement sur la carte.
    if (prefs == null) return true;
    return prefs.getBool(_doneKey) ?? false;
  }

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider)?.setBool(_doneKey, true);
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
