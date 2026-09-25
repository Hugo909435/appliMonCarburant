/// Prix nettement plus bas que d'habitude dans une station favorite.
class PriceDeal {
  const PriceDeal({
    required this.stationId,
    required this.usualPrice,
    required this.price,
  });

  final String stationId;

  /// Prix habituel de la station (médiane des jours précédents).
  final double usualPrice;
  final double price;

  /// Économie au litre par rapport à l'habitude (toujours positive).
  double get saving => usualPrice - price;
}

/// Prix relevés jour par jour pour chaque favori, et les favoris déjà
/// signalés pour leur bonne affaire en cours.
class FavoritePriceHistory {
  const FavoritePriceHistory({this.daily = const {}, this.alerted = const {}});

  /// Id de station → jour (« 2026-09-24 ») → dernier prix relevé ce jour-là.
  final Map<String, Map<String, double>> daily;

  /// Stations déjà signalées, qui ne le seront de nouveau qu'une fois leur
  /// prix revenu au-dessus du seuil.
  final Set<String> alerted;

  factory FavoritePriceHistory.fromJson(Map<String, dynamic> json) =>
      FavoritePriceHistory(
        daily: (json['daily'] as Map<String, dynamic>).map(
          (id, days) => MapEntry(
            id,
            (days as Map<String, dynamic>).map(
              (day, price) => MapEntry(day, (price as num).toDouble()),
            ),
          ),
        ),
        alerted: (json['alerted'] as List).cast<String>().toSet(),
      );

  Map<String, dynamic> toJson() => {
    'daily': daily,
    'alerted': alerted.toList(),
  };
}

/// Écart avec l'habitude qui vaut une notification : 10 centimes, soit
/// 4 € sur un plein de 40 L. En dessous, les stations bougent autant d'une
/// semaine à l'autre, et l'alerte ne vaudrait pas le dérangement.
const kDealThreshold = 0.10;

/// Jours de relevés nécessaires avant de parler d'« habitude ».
const kMinHistoryDays = 7;

/// Fenêtre sur laquelle se calcule le prix habituel.
const kHistoryDays = 30;

/// Prix habituel d'après [dailyPrices] : la médiane, qu'un prix aberrant
/// isolé (erreur de saisie de la station, promo d'un jour) ne déplace pas.
/// Null tant qu'il y a moins de [kMinHistoryDays] jours de relevés.
double? usualPrice(Iterable<double> dailyPrices) {
  final sorted = dailyPrices.toList()..sort();
  if (sorted.length < kMinHistoryDays) return null;
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Compare [current] (id de station → prix du jour) aux habitudes de
/// [history], et renvoie les nouvelles bonnes affaires, de la plus forte à
/// la plus faible, avec l'historique mis à jour.
///
/// L'historique n'est gardé que pour les stations de [favorites] : un
/// favori sans prix aujourd'hui (rupture) conserve le sien, un favori
/// retiré le perd.
///
/// Le jour même est exclu du calcul de l'habitude : sinon la baisse qu'on
/// cherche à repérer tirerait déjà la référence vers le bas.
///
/// Avec [notify] à faux (une alerte est déjà partie aujourd'hui), les
/// bonnes affaires ne sont pas marquées comme signalées : elles le seront
/// demain si elles tiennent toujours.
({FavoritePriceHistory history, List<PriceDeal> deals}) findPriceDeals({
  required FavoritePriceHistory history,
  required Map<String, double> current,
  required Set<String> favorites,
  required DateTime today,
  bool notify = true,
}) {
  final todayKey = dayKey(today);
  final oldest = dayKey(today.subtract(const Duration(days: kHistoryDays)));
  final daily = <String, Map<String, double>>{};
  final alerted = <String>{};
  final deals = <PriceDeal>[];

  for (final id in favorites) {
    // Les clés « AAAA-MM-JJ » se comparent comme des dates.
    final past = {
      for (final e in (history.daily[id] ?? const {}).entries)
        if (e.key != todayKey && e.key.compareTo(oldest) > 0) e.key: e.value,
    };
    final price = current[id];
    if (price == null) {
      if (past.isNotEmpty) daily[id] = past;
      continue;
    }
    final usual = usualPrice(past.values);
    // En millièmes : les prix du flux ont trois décimales, et la virgule
    // flottante ne tombe pas pile sur 0,10.
    final isDeal =
        usual != null &&
        ((usual - price) * 1000).round() >= (kDealThreshold * 1000).round();

    if (isDeal && history.alerted.contains(id)) {
      alerted.add(id);
    } else if (isDeal && notify) {
      alerted.add(id);
      deals.add(PriceDeal(stationId: id, usualPrice: usual, price: price));
    }
    daily[id] = {...past, todayKey: price};
  }

  deals.sort((a, b) => b.saving.compareTo(a.saving));
  return (
    history: FavoritePriceHistory(daily: daily, alerted: alerted),
    deals: deals,
  );
}

/// Jour de [d] au format « AAAA-MM-JJ ».
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
