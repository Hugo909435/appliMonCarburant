import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// Emplacement publicitaire « dans le flux », glissé entre deux cartes d'une
/// liste.
///
/// C'est la place que les règles des régies tolèrent sur un écran de carte :
/// jamais par-dessus la carte ni collé à un bouton, où un geste de
/// déplacement deviendrait un clic accidentel. Il porte toujours la mention
/// « Annonce » pour ne pas se confondre avec une station.
///
/// Aucune régie n'est encore branchée. Sur le web ce sera AdSense (un
/// `<ins class="adsbygoogle">` via `HtmlElementView`) ; dans les apps
/// Android et iOS, AdSense est interdit et c'est AdMob
/// (`google_mobile_ads`, format natif ou bannière adaptative) qui prend le
/// relais. En attendant, l'emplacement est visible en debug pour juger de
/// sa place, et absent d'un build de release.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key});

  /// Vrai quand un emplacement s'affiche vraiment : régie branchée, ou
  /// build de debug. Les listes s'en servent pour ne pas réserver de place
  /// à une annonce qui n'existera pas.
  static bool get isShown => AppConfig.adsEnabled || kDebugMode;

  /// Hauteur réservée, celle d'une bannière native compacte : fixe, pour
  /// que la liste ne saute pas quand l'annonce arrive.
  static const height = 96.0;

  @override
  Widget build(BuildContext context) {
    if (!isShown) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: muted),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Annonce',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Emplacement publicitaire',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Où glisser des [AdSlot] dans une liste de [itemCount] éléments.
///
/// La règle, la même dans toute l'app : jamais avant le [first]-ième
/// élément — ce que l'utilisateur est venu chercher passe d'abord — puis
/// une annonce toutes les [every] lignes. Une liste plus courte que [first]
/// n'en reçoit aucune : trois stations et une annonce, ce serait une
/// annonce pour trois stations.
///
/// Les index passés à [isAd] et [itemIndex] sont ceux de la liste affichée,
/// annonces comprises.
class InFeedAds {
  InFeedAds(this.itemCount, {this.first = 3, this.every = 10})
    : assert(first > 0 && every > 0);

  final int itemCount;
  final int first;
  final int every;

  /// Nombre d'annonces glissées dans la liste.
  int get adCount => !AdSlot.isShown || itemCount < first
      ? 0
      : 1 + (itemCount - first) ~/ every;

  /// Longueur de la liste affichée, annonces comprises.
  int get length => itemCount + adCount;

  /// Vrai si la ligne [index] de la liste affichée est une annonce.
  bool isAd(int index) =>
      adCount > 0 && index >= first && (index - first) % (every + 1) == 0;

  /// Index, dans la liste d'origine, de l'élément affiché à la ligne
  /// [index] (qui ne doit pas être une annonce).
  int itemIndex(int index) {
    if (adCount == 0 || index < first) return index;
    return index - ((index - first) ~/ (every + 1) + 1);
  }
}
