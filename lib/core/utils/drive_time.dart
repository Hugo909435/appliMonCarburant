import 'fill_cost.dart';

/// Rough driving time to a station [straightKm] away as the crow flies,
/// without calling a routing service for every row of a list.
///
/// The straight line is turned into road kilometers, then driven at a speed
/// that grows with the distance: the first kilometers are town streets, the
/// next ones main roads, the rest faster roads. Each band is summed rather
/// than picked, so a farther station never shows a shorter time.
Duration estimateDriveTime(double straightKm) {
  var remaining = straightKm * kRoadDetourFactor;
  var hours = 0.0;
  for (final (bandKm, speedKmh) in _bands) {
    final km = remaining < bandKm ? remaining : bandKm;
    hours += km / speedKmh;
    remaining -= km;
    if (remaining <= 0) break;
  }
  return Duration(seconds: (hours * 3600).round());
}

const _bands = <(double, double)>[
  (3, 25), // en ville
  (12, 45), // routes secondaires
  (25, 65), // nationales
  (double.infinity, 90), // voies rapides
];
