import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'utils/platform_support.dart';

/// Remonte à Crashlytics les erreurs levées par un provider Riverpod.
///
/// Sans cet observateur, une requête qui échoue dans un `AsyncNotifier` se
/// contente de produire un `AsyncError` : l'UI affiche son message d'erreur,
/// et personne n'apprend jamais que ça casse en production.
class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint('Provider ${provider.name ?? provider.runtimeType} : $error');
    if (!isCrashReportingSupported || Firebase.apps.isEmpty) return;
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      // Non fatal : l'app continue de tourner, l'écran concerné affiche son
      // état d'erreur.
      fatal: false,
      reason: 'provider ${provider.name ?? provider.runtimeType}',
    );
  }
}

/// Remplace l'écran rouge de Flutter par un message présentable.
///
/// En debug, l'écran rouge reste : c'est l'outil de travail. En release, il
/// n'apprend rien à l'utilisateur et donne l'impression d'une app cassée,
/// alors qu'un seul widget a échoué.
void installReleaseErrorWidget() {
  if (kDebugMode) return;
  ErrorWidget.builder = (details) => const _FriendlyErrorWidget();
}

class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    // Pas de Theme.of ici : ce widget doit pouvoir s'afficher même quand
    // l'erreur vient de la construction du thème lui-même.
    return const Material(
      color: Color(0xFF0F2D3F),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 40),
              SizedBox(height: 12),
              Text(
                "Cette partie de l'écran n'a pas pu s'afficher.\n"
                "Revenez en arrière, ou relancez l'application.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
