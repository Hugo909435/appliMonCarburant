import 'package:flutter/material.dart';

/// Lien « Voir plus » d'une ligne de liste, qui ouvre la fiche complète
/// quand toucher la ligne elle-même fait autre chose (centrer la carte).
class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        // Aligné sur le texte de la ligne, comme un lien, sans perdre une
        // zone de toucher confortable.
        padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
        minimumSize: const Size(48, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compressible : sur une ligne étroite ou en grands caractères, il
          // partage la colonne de l'adresse sans la faire déborder.
          Flexible(
            child: Text(
              'Voir plus',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}
