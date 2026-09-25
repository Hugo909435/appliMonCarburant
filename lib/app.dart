import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/price_alerts_provider.dart';
import 'providers/stations_provider.dart';
import 'router/app_router.dart';
import 'shared/widgets/loading_screen.dart';

class MonCarburantApp extends ConsumerWidget {
  const MonCarburantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authBootstrapProvider);
    ref.watch(priceAlertSyncProvider);
    return MaterialApp.router(
      title: 'Mon Carburant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          _StartupGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Recouvre l'app de [LoadingScreen] jusqu'au premier chargement des
/// stations (cache ou téléchargement), puis s'efface en fondu. La carte est
/// construite dessous pendant ce temps, prête dès que l'écran disparaît.
class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  /// Filet de sécurité : un réseau qui ne répond pas ne doit pas bloquer
  /// l'utilisateur derrière l'écran de chargement.
  static const _maxWait = Duration(seconds: 20);

  /// Durée minimale d'affichage, pour qu'on ait le temps de voir le logo et
  /// l'animation même quand les stations sortent du cache instantanément.
  static const _minWait = Duration(seconds: 3);

  bool _timedOut = false;
  bool _minElapsed = false;

  /// Vrai une fois le fondu terminé : l'écran quitte l'arbre, et ses points
  /// cessent de s'animer pour rien.
  bool _dismissed = false;

  late final Timer _timeout;
  late final Timer _minimum;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(_maxWait, () => setState(() => _timedOut = true));
    _minimum = Timer(_minWait, () => setState(() => _minElapsed = true));
  }

  @override
  void dispose() {
    _timeout.cancel();
    _minimum.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(stationsProvider);
    final loaded = stations.hasValue || stations.hasError;
    final ready = _timedOut || (_minElapsed && loaded);
    return Stack(
      children: [
        // Toujours au même emplacement du Stack : retirer l'écran ne doit
        // pas reconstruire le navigateur qu'il recouvrait.
        widget.child,
        if (!_dismissed)
          IgnorePointer(
            ignoring: ready,
            child: AnimatedOpacity(
              opacity: ready ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              onEnd: () {
                if (ready) setState(() => _dismissed = true);
              },
              child: const LoadingScreen(),
            ),
          ),
      ],
    );
  }
}
