import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/price_gaps.dart';

/// Mention qui situe un prix dans un lot comparé : « la moins chère », ou
/// l'écart au litre avec elle.
///
/// C'est la seule chose que l'œil cherche dans une comparaison, donc elle est
/// dite en toutes lettres pour la gagnante plutôt qu'en « +0,000 € ».
class PriceGapLabel extends StatelessWidget {
  const PriceGapLabel({super.key, required this.gap});

  final PriceGap gap;

  @override
  Widget build(BuildContext context) {
    if (gap.isCheapest) {
      return const Text(
        'la moins chère',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.good,
        ),
      );
    }

    return Text(
      formatPriceGap(gap.perLiter),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.bad,
      ),
    );
  }
}
