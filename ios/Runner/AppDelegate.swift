import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Identique à `PriceAlertScheduler.taskId` (price_alert_task.dart) et à
  /// l'entrée de `BGTaskSchedulerPermittedIdentifiers` (Info.plist).
  private static let priceAlertsTaskId = "com.moncarburant.priceAlerts"

  /// `PriceAlertScheduler.every`, en secondes : délai avant la vérification
  /// suivante, reprogrammée à la fin de chacune.
  private static let priceAlertsEvery: NSNumber = NSNumber(value: 12 * 60 * 60)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Affiche aussi les alertes de prix quand l'app est au premier plan.
    UNUserNotificationCenter.current().delegate = self

    // La vérification des prix en arrière-plan tourne dans un moteur à part,
    // qui a besoin des mêmes plugins (préférences, notifications, fichiers).
    // Réglé ici plutôt qu'à l'arrivée du moteur de l'écran : une app relancée
    // par iOS pour la tâche de fond n'ouvre pas forcément de scène.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // iOS ne livre une tâche de fond qu'à une app qui a déclaré son
    // gestionnaire avant la fin de ce lancement. Avec les scènes, les plugins
    // ne sont enregistrés qu'après : trop tard, et une déclaration tardive
    // est une erreur fatale. Déclarer le gestionnaire sans rien programmer
    // est sans effet : c'est le côté Dart qui programme ou annule la tâche.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: Self.priceAlertsTaskId,
      earliestBeginInSeconds: Self.priceAlertsEvery
    )
    WorkmanagerPlugin.registerLaunchHandlers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
