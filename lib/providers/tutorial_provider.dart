import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';

/// Vrai tant que le tutoriel de la carte doit se jouer : lancé à la fin de
/// l'accueil du premier lancement, ou rejoué depuis l'écran Compte.
///
/// Enregistré, pour qu'un nouveau venu qui quitte l'app en plein tutoriel
/// le retrouve à l'ouverture suivante.
class TutorialNotifier extends Notifier<bool> {
  static const _pendingKey = 'tutorial_pending_v1';

  @override
  bool build() {
    // Sans préférences (tests), pas de tutoriel par-dessus la carte.
    return ref.watch(sharedPreferencesProvider)?.getBool(_pendingKey) ?? false;
  }

  Future<void> start() => _set(true);

  /// Terminé ou passé : il ne revient plus de lui-même.
  Future<void> finish() => _set(false);

  Future<void> _set(bool pending) async {
    state = pending;
    await ref.read(sharedPreferencesProvider)?.setBool(_pendingKey, pending);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);
