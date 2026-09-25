import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications locales : pas de serveur, l'app (ou sa tâche de fond)
/// les émet elle-même quand elle constate une baisse de prix.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  /// Seules les apps mobiles savent vérifier les prix en arrière-plan : sur
  /// le web et sous Windows, une alerte n'arriverait qu'app ouverte, ce qui
  /// ne vaut pas une demande d'autorisation.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_monochrome'),
        // L'autorisation est demandée à l'étape dédiée de l'accueil, jamais
        // par surprise au démarrage.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Affiche la demande d'autorisation du système (Android 13+ et iOS).
  /// Renvoie vrai si les notifications sont autorisées.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    final granted = defaultTargetPlatform == TargetPlatform.iOS
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false)
        : await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'price_drops',
          'Baisses de prix',
          channelDescription:
              'Prévient quand le carburant baisse dans une station favorite.',
          // Pastille monochrome de l'icône adaptative : Android n'affiche
          // que la silhouette d'une petite icône de notification.
          icon: 'ic_launcher_monochrome',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
