import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/services/location_service.dart';
import '../../data/services/notification_service.dart';
import '../../providers/location_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/price_alerts_provider.dart';

enum _Step {
  location('Localisation', Icons.near_me_rounded),
  notifications('Alertes', Icons.notifications_active_rounded);

  const _Step(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Accueil du premier lancement, en étapes : la localisation, puis les
/// alertes de prix. Chaque étape peut être passée ; tout se
/// règle plus tard depuis l'écran Compte.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Sans tâche de fond (web, Windows), des alertes n'arriveraient qu'app
  /// ouverte : l'étape n'a pas lieu d'être.
  late final _steps = [
    _Step.location,
    if (NotificationService.isSupported) _Step.notifications,
  ];

  int _index = 0;
  bool _busy = false;

  /// Message affiché sous l'étape après un refus ou un échec, et vrai quand
  /// seul un passage par les réglages du téléphone peut le lever.
  String? _message;
  bool _needsSettings = false;

  _Step get _step => _steps[_index];

  void _next() {
    if (_index == _steps.length - 1) {
      ref.read(onboardingDoneProvider.notifier).complete();
      return;
    }
    setState(() {
      _index++;
      _message = null;
      _needsSettings = false;
    });
  }

  Future<void> _primary() async {
    // Après un refus, le bouton principal sert simplement à continuer.
    if (_message != null) return _next();
    switch (_step) {
      case _Step.location:
        await _run(_enableLocation);
      case _Step.notifications:
        await _run(_enableAlerts);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableLocation() async {
    // Récupère aussi la position : la carte s'ouvrira centrée dessus.
    await ref.read(userLocationProvider.notifier).requestLocation();
    if (!mounted) return;
    final result = ref.read(userLocationProvider);
    if (!result.hasError) return _next();
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      final error = result.error;
      _message = error is LocationFailure
          ? error.message
          : "Impossible d'obtenir votre position.";
      // Pas de réglages à ouvrir depuis un navigateur.
      _needsSettings =
          !kIsWeb && permission == LocationPermission.deniedForever;
    });
  }

  Future<void> _enableAlerts() async {
    final granted = await ref.read(priceAlertsProvider.notifier).enable();
    if (!mounted) return;
    if (granted) return _next();
    setState(() {
      _message =
          'Notifications refusées. Vous pourrez les autoriser plus tard '
          'dans les réglages de votre téléphone.';
      _needsSettings = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == _steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: _StepIndicator(steps: _steps, current: _index),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: ListView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    _StepHeader(step: _step),
                    const SizedBox(height: 24),
                    ..._content(),
                    if (_message != null) ...[
                      const SizedBox(height: 20),
                      _Notice(
                        message: _message!,
                        onOpenSettings: _needsSettings ? _openSettings : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _primary,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_primaryLabel(isLast)),
                  ),
                  const SizedBox(height: 4),
                  // Rien à passer une fois l'étape tentée : le bouton
                  // principal continue déjà.
                  Visibility.maintain(
                    visible: _message == null,
                    child: TextButton(
                      onPressed: _busy ? null : _next,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      child: const Text('Plus tard'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _primaryLabel(bool isLast) {
    if (_message != null) return isLast ? 'Terminer' : 'Continuer';
    return switch (_step) {
      _Step.location => 'Activer la localisation',
      _Step.notifications => 'Activer les alertes',
    };
  }

  List<Widget> _content() => switch (_step) {
    _Step.location => const [
      _Benefit(
        icon: Icons.local_gas_station_rounded,
        text: 'Les stations les moins chères autour de vous, dès l’ouverture.',
      ),
      _Benefit(
        icon: Icons.route_rounded,
        text: 'Le vrai coût du plein, trajet jusqu’à la station compris.',
      ),
      _Benefit(
        icon: Icons.lock_outline_rounded,
        text:
            'Votre position est utilisée sur votre téléphone et n’est '
            'jamais enregistrée sur nos serveurs.',
      ),
    ],
    _Step.notifications => const [
      _Benefit(
        icon: Icons.trending_down_rounded,
        text:
            'Une notification quand votre carburant coûte au moins 10 '
            'centimes de moins que d’habitude dans une de vos stations '
            'favorites : 4 € d’économie sur un plein de 40 L.',
      ),
      _Benefit(
        icon: Icons.insights_rounded,
        text:
            'L’app apprend le prix habituel de vos favoris pendant une '
            'semaine avant la première alerte.',
      ),
      _Benefit(
        icon: Icons.wifi_rounded,
        text:
            'App fermée, les prix ne sont vérifiés qu’en Wi-Fi : rien sur '
            'votre forfait mobile.',
      ),
      _Benefit(
        icon: Icons.notifications_off_outlined,
        text:
            'Une notification par jour au plus, et vous pouvez couper les '
            'alertes à tout moment depuis Compte.',
      ),
    ],
  };

  /// Les réglages de l'app, où se trouvent aussi ses notifications.
  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }
}

/// Étapes numérotées, reliées par des pointillés qui se remplissent au fil
/// de l'avancée.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});

  final List<_Step> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Étape ${current + 1} sur ${steps.length}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Padding(
                    // Aligne les pointillés sur le centre des pastilles.
                    padding: const EdgeInsets.only(top: 17),
                    child: _Dots(
                      color: i <= current
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                ),
              _StepBubble(
                number: i + 1,
                label: steps[i].label,
                done: i < current,
                active: i == current,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  const _StepBubble({
    required this.number,
    required this.label,
    required this.done,
    required this.active,
  });

  final int number;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = done || active;
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? scheme.primary : scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: filled ? scheme.primary : scheme.outlineVariant,
                width: 2,
              ),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: filled
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dot = 4.0;
        const gap = 6.0;
        final count = ((constraints.maxWidth + gap) / (dot + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: dot,
                height: dot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        );
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final _Step step;

  static const _titles = {
    _Step.location: 'Les stations autour de vous',
    _Step.notifications: 'Restez informé des baisses',
  };

  static const _subtitles = {
    _Step.location:
        'Autorisez la localisation pour trouver le meilleur prix près de '
        'vous.',
    _Step.notifications:
        'On vous prévient seulement quand ça vaut vraiment le coup de '
        'passer à la pompe.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(step.icon, size: 28, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 18),
        Text(_titles[step]!, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_subtitles[step]!, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.onOpenSettings});

  final String message;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Text(message),
            ),
            if (onOpenSettings != null)
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Ouvrir les réglages'),
              ),
          ],
        ),
      ),
    );
  }
}
