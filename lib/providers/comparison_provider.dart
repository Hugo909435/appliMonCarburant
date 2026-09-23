import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nombre maximum de stations comparables d'un coup.
///
/// Le tableau de comparaison fait défiler ses colonnes, donc rien n'empêche
/// techniquement d'en montrer plus ; c'est la lisibilité sur un téléphone qui
/// fixe la limite. Changer cette seule constante suffit à l'élargir.
const kMaxComparedStations = 4;

/// Identifiants des stations retenues pour la comparaison, dans l'ordre où
/// elles ont été choisies. Au-delà de [kMaxComparedStations], la plus
/// ancienne cède la place à la nouvelle plutôt que de bloquer la sélection.
class ComparisonNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void toggle(String stationId) {
    if (state.contains(stationId)) {
      state = state.where((id) => id != stationId).toList();
      return;
    }
    if (state.length >= kMaxComparedStations) {
      // Fenêtre glissante : on garde les dernières choisies, la place libérée
      // revient à celle qu'on vient de désigner.
      state = [
        ...state.skip(state.length - kMaxComparedStations + 1),
        stationId,
      ];
      return;
    }
    state = [...state, stationId];
  }

  /// Remplace la sélection entière, tronquée à [kMaxComparedStations].
  ///
  /// Sert aux écrans qui envoient d'un coup une liste déjà ordonnée — les
  /// favoris les moins chers, par exemple.
  void replaceWith(Iterable<String> stationIds) {
    state = stationIds.take(kMaxComparedStations).toList();
  }

  void clear() => state = const [];
}

final comparisonProvider = NotifierProvider<ComparisonNotifier, List<String>>(
  ComparisonNotifier.new,
);
