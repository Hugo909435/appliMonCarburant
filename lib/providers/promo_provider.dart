import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/platform_support.dart';
import '../data/models/promo_annonce.dart';
import '../data/services/promo_service.dart';

final promoServiceProvider = Provider<PromoService>((ref) => PromoService());

/// Annonce brute telle que publiée, sans tenir compte des fermetures.
final promoAnnonceProvider = StreamProvider<PromoAnnonce?>((ref) {
  if (!isFirebaseSupported) return Stream.value(null);
  return ref.watch(promoServiceProvider).watch();
});

/// Campagnes que l'utilisateur a fermées, mémorisées par id.
///
/// Stocké en local uniquement : c'est une préférence d'affichage, pas une
/// donnée de compte, et ça évite une écriture Firestore par fermeture.
class DismissedPromosNotifier extends AsyncNotifier<Set<String>> {
  static const _key = 'dismissed_promo_ids';

  /// Une annonce fermée l'est pour de bon, mais on ne garde pas un historique
  /// infini : au-delà, les plus anciennes campagnes ne reviendront de toute
  /// façon jamais.
  static const _maxKept = 20;

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> dismiss(String promoId) async {
    final updated = [...(state.valueOrNull ?? const <String>{}), promoId];
    final kept = updated.length > _maxKept
        ? updated.sublist(updated.length - _maxKept)
        : updated;
    state = AsyncData(kept.toSet());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, kept);
  }
}

final dismissedPromosProvider =
    AsyncNotifierProvider<DismissedPromosNotifier, Set<String>>(
      DismissedPromosNotifier.new,
    );

/// L'annonce réellement affichable : publiée, dans sa fenêtre de dates, et
/// pas encore fermée par cet utilisateur. `null` tant que les fermetures
/// n'ont pas fini de charger, pour éviter un bandeau qui clignote au
/// démarrage avant de disparaître.
final visiblePromoProvider = Provider<PromoAnnonce?>((ref) {
  final annonce = ref.watch(promoAnnonceProvider).valueOrNull;
  if (annonce == null || !annonce.isLiveAt(DateTime.now())) return null;
  final dismissed = ref.watch(dismissedPromosProvider).valueOrNull;
  if (dismissed == null || dismissed.contains(annonce.id)) return null;
  return annonce;
});
