import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/notification_service.dart';
import '../data/services/price_alert_service.dart';
import '../data/services/price_alert_task.dart';
import 'favorites_provider.dart';
import 'vehicle_provider.dart';

final priceAlertServiceProvider = Provider<PriceAlertService>(
  (ref) => PriceAlertService(),
);

/// Alertes de baisse de prix activées ou non. Toujours faux là où l'app ne
/// sait pas notifier (web, Windows).
class PriceAlertsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    if (!NotificationService.isSupported) return false;
    return ref.read(priceAlertServiceProvider).isEnabled();
  }

  /// Active les alertes, après avoir demandé l'autorisation au système.
  /// Renvoie faux si l'utilisateur l'a refusée.
  Future<bool> enable() async {
    final granted = await NotificationService.instance.requestPermission();
    await _apply(granted);
    return granted;
  }

  Future<void> disable() => _apply(false);

  Future<void> _apply(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(priceAlertServiceProvider).setEnabled(enabled);
    await (enabled
        ? PriceAlertScheduler.enable()
        : PriceAlertScheduler.disable());
  }
}

final priceAlertsProvider = AsyncNotifierProvider<PriceAlertsNotifier, bool>(
  PriceAlertsNotifier.new,
);

/// Tient à jour la copie des favoris et du carburant suivis que lit la
/// tâche de fond. À surveiller depuis la racine de l'app.
final priceAlertSyncProvider = Provider<void>((ref) {
  final service = ref.read(priceAlertServiceProvider);
  // Au pire, les alertes suivent une copie en retard d'un réglage : rien
  // qui justifie de remonter une erreur.
  void sync(Future<void> Function() write) =>
      unawaited(write().catchError((Object _) {}));

  ref.listen(favoritesProvider, (_, next) {
    final ids = next.valueOrNull;
    if (ids != null) sync(() => service.syncFavorites(ids));
  }, fireImmediately: true);
  ref.listen(vehicleProvider, (_, next) {
    final profile = next.valueOrNull;
    if (profile != null) sync(() => service.syncFuel(profile.fuel));
  }, fireImmediately: true);
});
