import 'package:flutter/foundation.dart' show debugPrint;
import 'package:workmanager/workmanager.dart';

import '../models/station.dart';
import 'gov_feed_service.dart';
import 'notification_service.dart';
import 'price_alert_service.dart';
import 'station_cache.dart';

/// Point d'entrée de la tâche de fond, lancé par le système dans un isolate
/// à part, sans l'app ni Riverpod.
@pragma('vm:entry-point')
void priceAlertDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Pas de StationRepository : en debug, il retombe sur les stations de
      // test quand le flux échoue, et comparer leurs prix fictifs aux vrais
      // déclencherait de fausses alertes.
      final raw = await GovFeedService().fetchStations();
      // Au passage, la carte s'ouvrira sur des prix frais.
      await StationCache().write(raw);
      await PriceAlertService().check(raw.map(Station.fromJson).toList());
      return true;
    } catch (e) {
      debugPrint('Vérification des prix en arrière-plan échouée : $e');
      // Faux : le système retentera plus tard, selon sa propre politique.
      return false;
    }
  });
}

/// Programme la vérification périodique des prix des favoris.
class PriceAlertScheduler {
  const PriceAlertScheduler._();

  /// Identifiant de la tâche. Sur iOS, il doit figurer tel quel dans
  /// `BGTaskSchedulerPermittedIdentifiers` (ios/Runner/Info.plist).
  static const taskId = 'com.moncarburant.priceAlerts';

  /// Deux fois par jour : une bonne affaire de 10 centimes dure bien plus
  /// longtemps, et chaque vérification retélécharge 10+ Mo. iOS ignore
  /// cette durée et décide seul, selon l'usage de l'app.
  static const every = Duration(hours: 12);

  /// À appeler à chaque lancement, avant toute programmation : Android
  /// retrouve la tâche par ce point d'entrée.
  static Future<void> initialize() async {
    if (!NotificationService.isSupported) return;
    try {
      await Workmanager().initialize(priceAlertDispatcher);
    } catch (e) {
      debugPrint('Tâche de fond indisponible : $e');
    }
  }

  static Future<void> enable() async {
    if (!NotificationService.isSupported) return;
    try {
      await Workmanager().registerPeriodicTask(
        taskId,
        taskId,
        frequency: every,
        initialDelay: every,
        // Met à jour une tâche déjà programmée avec d'autres réglages,
        // plutôt que de la laisser tourner à l'ancien rythme.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          // Wi-Fi seulement : en arrière-plan, le flux ne doit rien coûter
          // sur le forfait mobile. App ouverte, les prix se téléchargent
          // quel que soit le réseau, et la vérification se fait au passage.
          networkType: NetworkType.unmetered,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('Programmation des alertes de prix impossible : $e');
    }
  }

  static Future<void> disable() async {
    if (!NotificationService.isSupported) return;
    try {
      await Workmanager().cancelByUniqueName(taskId);
    } catch (e) {
      debugPrint('Annulation des alertes de prix impossible : $e');
    }
  }
}
