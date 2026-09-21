import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/promo_annonce.dart';
import '../../providers/promo_provider.dart';

/// Bandeau d'annonce « prix coûtant », posé juste au-dessus de la barre de
/// navigation.
///
/// Volontairement pas une boîte de dialogue : rien à valider, rien qui
/// bloque la carte, et il occupe une bande fine dans le flux plutôt que de
/// flotter par-dessus le contenu (sinon il recouvrirait le bouton
/// « Comparer » de l'accueil). Il se ferme d'une croix ou d'un balayage
/// latéral, et ne revient plus pour la même campagne.
class PromoBanner extends ConsumerWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annonce = ref.watch(visiblePromoProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: annonce == null
          ? const SizedBox(width: double.infinity)
          : _PromoCard(
              key: ValueKey(annonce.id),
              annonce: annonce,
              onClose: () => ref
                  .read(dismissedPromosProvider.notifier)
                  .dismiss(annonce.id),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({super.key, required this.annonce, required this.onClose});

  final PromoAnnonce annonce;
  final VoidCallback onClose;

  Future<void> _openLink() async {
    final uri = Uri.tryParse(annonce.lienUrl!);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest;
    final foreground = theme.colorScheme.onSurface;

    return Dismissible(
      key: ValueKey('promo-${annonce.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onClose(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: annonce.hasLien ? _openLink : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 18,
                    color: foreground.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          annonce.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          annonce.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withValues(alpha: 0.75),
                            height: 1.25,
                          ),
                        ),
                        if (annonce.hasLien) ...[
                          const SizedBox(height: 2),
                          Text(
                            annonce.lienLibelle?.isNotEmpty == true
                                ? annonce.lienLibelle!
                                : 'En savoir plus',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: foreground.withValues(alpha: 0.6),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Masquer l'annonce",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
