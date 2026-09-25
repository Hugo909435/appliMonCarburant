import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/crash_reporting.dart';
import 'core/utils/platform_support.dart';
import 'data/services/price_alert_service.dart';
import 'data/services/price_alert_task.dart';
import 'firebase_options.dart';
import 'providers/filters_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/preferences_provider.dart';

Future<void> main() async {
  // Centralise la capture des erreurs — framework, async et zone — pour
  // qu'aucune ne disparaisse en silence. Tant que Crashlytics n'est pas
  // disponible (web, Windows, ou Firebase en échec), on retombe sur la
  // console : mieux vaut un log qu'un écran rouge muet en release.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = _logFlutterError;
      AppConfig.warnIfMisconfigured();
      installReleaseErrorWidget();

      if (isFirebaseSupported) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          if (isCrashReportingSupported) {
            await _installCrashReporting();
          }
        } catch (e) {
          debugPrint('Échec de l\'initialisation Firebase, mode local: $e');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await OnboardingNotifier.skipForExistingInstall(prefs);
      // Après : les anciens réglages du véhicule signalent encore une
      // installation antérieure à l'accueil.
      await migrateVehiclePreferences(prefs);
      await _startPriceAlerts();
      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          observers: const [CrashReportingObserver()],
          child: const MonCarburantApp(),
        ),
      );
    },
    (error, stack) {
      if (isCrashReportingSupported && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      debugPrint('Uncaught async error: $error\n$stack');
    },
  );
}

/// Android oublie le point d'entrée de la tâche de fond d'un lancement à
/// l'autre : il faut le redonner à chaque fois, puis reprogrammer la tâche
/// si l'utilisateur a activé les alertes.
Future<void> _startPriceAlerts() async {
  await PriceAlertScheduler.initialize();
  try {
    if (await PriceAlertService().isEnabled()) {
      unawaited(PriceAlertScheduler.enable());
    }
  } catch (e) {
    debugPrint('Lecture du réglage des alertes impossible : $e');
  }
}

Future<void> _installCrashReporting() async {
  // En debug, les plantages sont déjà sous les yeux du développeur : les
  // envoyer ne ferait que polluer les statistiques de la version publiée.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = (details) {
    _logFlutterError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  // Erreurs remontées par le moteur hors de toute zone Dart.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

void _logFlutterError(FlutterErrorDetails details) {
  FlutterError.presentError(details);
  debugPrint('Flutter error: ${details.exceptionAsString()}');
}
