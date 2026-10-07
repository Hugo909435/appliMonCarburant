import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/tutorial_provider.dart';
import 'stations_sheet.dart';

/// Hauteur de la ligne du haut de la carte (recherche, filtres, compte),
/// marges comprises : de quoi laisser passer l'ombre des pastilles.
const kMapTopRowHeight = 60.0;

/// Les commandes de la carte que le tutoriel met en lumière. Chaque clé est
/// posée par l'écran d'accueil sur la commande correspondante.
class TutorialTargets {
  final filters = GlobalKey();
  final favorites = GlobalKey();
  final route = GlobalKey();
  final locate = GlobalKey();
  final account = GlobalKey();
}

class _Step {
  const _Step({
    required this.title,
    required this.text,
    this.target,
    this.area,
  });

  final String title;
  final String text;

  /// La commande éclairée…
  final GlobalKey Function(TutorialTargets)? target;

  /// …ou, pour la carte elle-même, une zone de l'écran.
  final Rect Function(Size screen, EdgeInsets padding)? area;
}

/// Haut de la liste des stations à sa hauteur d'ouverture (voir
/// [StationsSheet]), dans le repère de l'écran.
double _sheetTop(Size screen, EdgeInsets padding) {
  final top = padding.top + kMapTopRowHeight;
  return top + (screen.height - top) * (1 - StationsSheet.initialFraction);
}

final _steps = <_Step>[
  _Step(
    title: 'Les prix sur la carte',
    text:
        'Chaque étiquette est une station et son prix. Touchez-en une pour '
        'voir tous ses carburants, ses horaires et l’itinéraire.',
    // La carte visible, entre la ligne du haut et la liste.
    // Toute la carte visible, de la ligne du haut à la liste : là où
    // l'écran d'accueil vient de cadrer les stations (ou la France).
    area: (screen, padding) => Rect.fromLTRB(
      12,
      padding.top + kMapTopRowHeight + 6,
      screen.width - 12,
      _sheetTop(screen, padding) - 10,
    ),
  ),
  _Step(
    title: 'Votre carburant',
    text:
        'Choisissez votre carburant ici, puis faites défiler la ligne pour '
        'filtrer par enseigne, département ou service. Les bornes '
        'électriques sont juste à côté.',
    target: (t) => t.filters,
  ),
  _Step(
    title: 'Une adresse, une ville',
    text:
        'La loupe déplace la carte vers une adresse, une ville ou un code '
        'postal.',
    // Le bouton loupe, au début de la ligne du haut : la recherche qui le
    // porte s'étend, elle, sur toute la largeur.
    area: (screen, padding) => Rect.fromLTWH(
      12,
      padding.top + (kMapTopRowHeight - 40) / 2,
      40,
      40,
    ).inflate(6),
  ),
  _Step(
    title: 'La liste des stations',
    text:
        'Les stations affichées sur la carte, des moins chères aux plus '
        'proches. Tirez la liste vers le haut pour la voir en entier.',
    // Le haut de la liste, à sa hauteur d'ouverture (voir StationsSheet).
    area: (screen, padding) {
      final sheetTop = _sheetTop(screen, padding);
      return Rect.fromLTRB(
        8,
        sheetTop + 4,
        screen.width - 8,
        (sheetTop + 190).clamp(0, screen.height - 8),
      );
    },
  ),
  _Step(
    title: 'Vos favoris',
    text:
        'L’étoile d’une station l’ajoute à vos favoris. Retrouvez ici leurs '
        'prix d’un geste, et comparez-les.',
    target: (t) => t.favorites,
  ),
  _Step(
    title: 'Le plein sur votre trajet',
    text:
        'Indiquez une destination : l’app repère les stations les moins '
        'chères le long de la route, détour compris.',
    target: (t) => t.route,
  ),
  _Step(
    title: 'Autour de vous',
    text:
        'Ce bouton recentre la carte sur votre position et fait apparaître '
        '« Le plus rentable autour de moi » : le vrai coût du plein, trajet '
        'jusqu’à la station compris.',
    target: (t) => t.locate,
  ),
  _Step(
    title: 'Votre compte',
    text:
        'Connectez-vous pour garder vos favoris sur tous vos appareils, et '
        'réglez les alertes de prix. Ce tutoriel s’y revoit à tout moment.',
    target: (t) => t.account,
  ),
];

/// Tutoriel du premier lancement, joué sur la vraie carte : chaque commande
/// est éclairée à son tour dans un voile sombre, avec une bulle qui explique
/// à quoi elle sert.
///
/// À poser en dernier dans le `Stack` de l'écran d'accueil ; ne dessine rien
/// tant que [tutorialProvider] est faux.
class HomeTutorial extends ConsumerWidget {
  const HomeTutorial({super.key, required this.targets});

  final TutorialTargets targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(tutorialProvider)) return const SizedBox.shrink();
    return Positioned.fill(
      child: _Coach(
        targets: targets,
        onDone: () => ref.read(tutorialProvider.notifier).finish(),
      ),
    );
  }
}

class _Coach extends StatefulWidget {
  const _Coach({required this.targets, required this.onDone});

  final TutorialTargets targets;
  final VoidCallback onDone;

  @override
  State<_Coach> createState() => _CoachState();
}

class _CoachState extends State<_Coach> with SingleTickerProviderStateMixin {
  /// Marge entre une commande et le bord de la zone éclairée.
  static const _halo = 6.0;

  static const _move = Duration(milliseconds: 380);

  /// Bat autour de la zone éclairée pour attirer l'œil.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  int _index = 0;

  /// Zone éclairée de l'étape en cours, dans le repère de ce widget ; nulle
  /// tant qu'elle n'a pas été mesurée, ou si la commande est introuvable.
  Rect? _spot;

  bool get _isLast => _index == _steps.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) return widget.onDone();
    setState(() => _index++);
  }

  /// Mesurée après chaque mise en page : les commandes bougent quand l'écran
  /// tourne ou que la liste change de hauteur.
  void _measure() {
    if (!mounted) return;
    final step = _steps[_index];
    final box = context.findRenderObject()! as RenderBox;
    Rect? spot;
    if (step.area case final area?) {
      spot = area(box.size, MediaQuery.paddingOf(context));
    } else {
      final target = step.target!(widget.targets).currentContext
          ?.findRenderObject();
      if (target is RenderBox && target.attached) {
        spot = (target.localToGlobal(Offset.zero, ancestor: box) & target.size)
            .inflate(_halo);
      }
    }
    if (spot != _spot) setState(() => _spot = spot);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final step = _steps[_index];
    final still = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final spot = _spot;
        final safe = MediaQuery.paddingOf(context);
        const gap = 14.0;
        // La bulle prend le côté de la zone éclairée qui a le plus de place,
        // et n'en sort pas : son texte défile s'il est trop long.
        final roomAbove = spot == null ? 0.0 : spot.top - gap - safe.top - 8;
        final roomBelow = spot == null
            ? 0.0
            : size.height - spot.bottom - gap - safe.bottom - 8;
        final below = spot != null && roomBelow >= roomAbove;

        return Stack(
          children: [
            // Le voile arrête les gestes : pendant le tutoriel, la carte ne
            // bouge pas sous les explications.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                // Rien d'éclairé tant que rien n'est mesuré : un voile plein.
                child: spot == null
                    ? CustomPaint(
                        painter: _SpotlightPainter(
                          spot: null,
                          pulse: _pulse,
                          liftSpot: dark,
                        ),
                      )
                    : TweenAnimationBuilder<Rect?>(
                        tween: RectTween(end: spot),
                        duration: still ? Duration.zero : _move,
                        curve: Curves.easeInOutCubic,
                        builder: (context, rect, _) => CustomPaint(
                          painter: _SpotlightPainter(
                            spot: rect,
                            pulse: _pulse,
                            liftSpot: dark,
                          ),
                        ),
                      ),
              ),
            ),
            AnimatedPositioned(
              duration: still ? Duration.zero : _move,
              curve: Curves.easeInOutCubic,
              left: 16,
              right: 16,
              top: below ? spot.bottom + gap : safe.top + 8,
              bottom: spot != null && !below
                  ? size.height - spot.top + gap
                  : safe.bottom + 8,
              child: Align(
                alignment: spot == null
                    ? Alignment.center
                    : below
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: _Bubble(
                  step: step,
                  index: _index,
                  count: _steps.length,
                  isLast: _isLast,
                  onNext: _next,
                  onSkip: widget.onDone,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Le voile sombre, percé d'une zone éclairée qu'entoure un anneau battant.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.spot,
    required this.pulse,
    required this.liftSpot,
  }) : super(repaint: pulse);

  final Rect? spot;
  final Animation<double> pulse;

  /// Éclaircit l'intérieur de la zone éclairée (thème sombre).
  final bool liftSpot;

  @override
  void paint(Canvas canvas, Size size) {
    // Presque noir : sur les tuiles claires de la carte, le bleu nuit de la
    // marque ne donnerait qu'un gris moyen, et la zone éclairée ressortirait
    // mal.
    final veil = Paint()
      ..color = AppColors.backgroundDark.withValues(alpha: 0.72);
    final spot = this.spot;
    if (spot == null) {
      canvas.drawRect(Offset.zero & size, veil);
      return;
    }
    // Arrondi d'une gélule pour les boutons, plus doux pour une grande zone.
    final radius = Radius.circular(
      (spot.shortestSide / 2).clamp(0, AppRadius.lg),
    );
    final hole = RRect.fromRectAndRadius(spot, radius);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      veil,
    );
    // En thème sombre, la liste et les feuilles sont presque aussi foncées
    // que le voile : sans ce léger éclaircissement, la zone ne paraîtrait
    // pas éclairée.
    if (liftSpot) {
      canvas.drawRRect(
        hole,
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
    }
    // Un halo diffus puis un trait net : le contour se lit sur une carte
    // claire comme sur une surface sombre.
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    // L'anneau s'écarte de la zone et s'efface, en boucle.
    final t = Curves.easeOut.transform(pulse.value);
    canvas.drawRRect(
      hole.inflate(10 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spot != spot || old.liftSpot != liftSpot;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.step,
    required this.index,
    required this.count,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final _Step step;
  final int index;
  final int count;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: scheme.surface,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seule partie à céder de la place quand elle manque : les
              // boutons, eux, restent toujours à l'écran.
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: Semantics(
                      key: ValueKey(index),
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${index + 1} / $count',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(step.title, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(step.text, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Wrap : avec un texte agrandi, les boutons passent l'un sous
              // l'autre au lieu de déborder.
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  if (!isLast)
                    TextButton(onPressed: onSkip, child: const Text('Passer')),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(isLast ? 'Terminer' : 'Suivant'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
