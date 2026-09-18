import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/platform_support.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Centralizes framework/async error capture so failures are logged
  // consistently instead of vanishing silently or red-screening in release
  // — the entry point for wiring in a crash reporter later.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exceptionAsString()}');
      };
      if (isFirebaseSupported) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          debugPrint('Échec de l\'initialisation Firebase, mode local: $e');
        }
      }
      runApp(const ProviderScope(child: MonCarburantApp()));
    },
    (error, stack) {
      debugPrint('Uncaught async error: $error\n$stack');
    },
  );
}
