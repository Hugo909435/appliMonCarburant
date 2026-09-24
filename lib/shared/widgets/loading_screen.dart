import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Écran affiché au lancement, le temps que les stations soient chargées.
///
/// Il reprend exactement le fond et le logo du splash natif
/// (`flutter_native_splash` dans pubspec.yaml) : le passage de l'un à
/// l'autre est invisible, seuls les trois points apparaissent en plus.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.primary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/branding/splash_logo.png'),
              width: 192,
              height: 192,
            ),
            SizedBox(height: 32),
            BouncingDots(),
          ],
        ),
      ),
    );
  }
}

/// Trois points qui rebondissent l'un après l'autre.
class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key, this.color = Colors.white, this.size = 12});

  final Color color;
  final double size;

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounce = widget.size;
    return Semantics(
      label: 'Chargement',
      child: SizedBox(
        height: widget.size + bounce,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.size / 3),
                  child: Transform.translate(
                    offset: Offset(0, -bounce * _height(i)),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hauteur du point [index] entre 0 et 1 : chaque point saute pendant le
  /// premier tiers de son cycle, décalé d'un sixième sur le précédent, puis
  /// reste au sol — d'où l'effet de vague.
  double _height(int index) {
    final t = (_controller.value - index / 6) % 1.0;
    if (t > 0.4) return 0;
    return math.sin(t / 0.4 * math.pi);
  }
}
