/// Straight-line distances underestimate the real road distance; this is the
/// usual average ratio for French roads (~1.3), good enough to rank stations
/// without calling a routing service for each one.
const kRoadDetourFactor = 1.3;

/// Plein de référence pour chiffrer le coût réel : ce que met une voiture
/// thermique moyenne à chaque passage à la pompe.
const kTypicalFillLiters = 40.0;

/// Consommation de référence, en L/100 km, pour valoriser le trajet
/// jusqu'à la station.
const kTypicalConsumptionL100 = 6.5;

/// What a fill-up actually costs once the trip to reach the station is
/// counted: a station 3 cts cheaper but 10 km away is often a bad deal.
class FillCost {
  const FillCost({
    required this.fuelCost,
    required this.tripCost,
    required this.tripKm,
  });

  /// Price of the liters put in the tank.
  final double fuelCost;

  /// Fuel burnt driving to the station and back (or off the route and back),
  /// valued at the station's own price.
  final double tripCost;

  /// Road kilometers driven for the detour (both ways).
  final double tripKm;

  double get total => fuelCost + tripCost;
}

/// [detourKm] is the one-way straight-line distance from the user (or from
/// the route) to the station: it's converted to road kilometers and doubled
/// since the driver has to come back.
FillCost computeFillCost({
  required double pricePerLiter,
  required double liters,
  required double consumptionL100,
  required double detourKm,
}) {
  final tripKm = detourKm * kRoadDetourFactor * 2;
  final tripLiters = tripKm * consumptionL100 / 100;
  return FillCost(
    fuelCost: liters * pricePerLiter,
    tripCost: tripLiters * pricePerLiter,
    tripKm: tripKm,
  );
}
