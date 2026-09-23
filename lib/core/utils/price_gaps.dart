import 'dart:math';

/// Ce qu'un prix vaut, rapporté au moins cher d'un même ensemble de stations.
///
/// C'est la brique de toute comparaison de l'app : un prix seul ne dit rien,
/// c'est l'écart avec le meilleur du lot qui fait décider.
class PriceGap {
  const PriceGap({required this.price, required this.perLiter});

  /// Le prix affiché par la station, en euros par litre.
  final double price;

  /// Écart au litre avec la station la moins chère de l'ensemble. Nul pour
  /// elle, positif pour toutes les autres.
  final double perLiter;

  bool get isCheapest => perLiter == 0;

  /// Ce que cet écart coûte réellement sur un plein de [liters] litres — le
  /// chiffre qui parle, là où trois millièmes d'euro au litre ne parlent pas.
  double onFillUp(double liters) => perLiter * liters;
}

/// Situe chaque station d'un ensemble par rapport à la moins chère.
///
/// [pricesByStation] associe un identifiant de station à son prix pour un
/// carburant donné, `null` quand elle ne le propose pas. Ces stations-là sont
/// absentes du résultat : elles ne sont pas « plus chères », elles sont hors
/// comparaison, et l'appelant doit les traiter comme telles.
///
/// Retourne une table vide si aucune station ne propose le carburant, cas où
/// il n'existe simplement rien à comparer.
Map<String, PriceGap> priceGaps(Map<String, double?> pricesByStation) {
  final available = <String, double>{
    for (final entry in pricesByStation.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
  if (available.isEmpty) return const {};

  final cheapest = available.values.reduce(min);
  return {
    for (final entry in available.entries)
      entry.key: PriceGap(
        price: entry.value,
        perLiter: entry.value - cheapest,
      ),
  };
}
