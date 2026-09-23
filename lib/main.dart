import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/crash_reporting.dart';
import 'core/utils/platform_support.dart';
import 'firebase_options.dart';

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
      runApp(
        const ProviderScope(
          observers: [CrashReportingObserver()],
          child: MonCarburantApp(),
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
