import 'package:flutter/material.dart';

/// A thin rounded bar that stretches out from the left, then pulls in
/// towards the right, once a second: the app's wait indicator.
class LoadingBar extends StatefulWidget {
  const LoadingBar({
    super.key,
    this.color = const Color(0xFF0071E2),
    this.width = 130,
    this.height = 4,
    this.label,
  });

  final Color color;
  final double width;
  final double height;

  /// Shown under the bar, e.g. « Recherche des bornes… ».
  final String? label;

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Animations coupées dans les réglages : une barre à moitié pleine, fixe.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(widget.height * 7.5);

    final bar = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.2),
        borderRadius: radius,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Première moitié : grandit depuis la gauche ; seconde : se
          // rétracte vers la droite. Chaque moitié en ease-in-out.
          final t = _controller.value;
          final growing = t < 0.5;
          final fill = growing
              ? Curves.easeInOut.transform(t * 2)
              : 1 - Curves.easeInOut.transform((t - 0.5) * 2);
          return Align(
            alignment: growing ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: widget.width * fill,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: radius,
              ),
            ),
          );
        },
      ),
    );

    return Semantics(
      label: label ?? 'Chargement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(child: bar),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
