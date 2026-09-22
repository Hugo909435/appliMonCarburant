import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/fuel_colors.dart';
import '../../core/utils/fill_cost.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/station.dart';
import '../../providers/filters_provider.dart';
import '../../providers/vehicle_provider.dart';

/// "Plein de 40 L ici : 72,40 € + 1,10 € de trajet", for the fuel currently
/// selected. Hidden when the station doesn't sell that fuel.
class FillCostCard extends ConsumerWidget {
  const FillCostCard({
    super.key,
    required this.station,
    required this.distanceKm,
  });

  final Station station;

  /// One-way straight-line distance from the user to the station.
  final double distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(selectedFuelProvider);
    final vehicle = ref.watch(vehicleProfileProvider);
    final price = station.prices[fuel.code];
    if (price == null) return const SizedBox.shrink();

    final cost = computeFillCost(
      pricePerLiter: price,
      liters: vehicle.fillLiters,
      consumptionL100: vehicle.consumptionL100,
      detourKm: distanceKm,
    );
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: fuel.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plein de ${vehicle.fillLiters.round()} L de ${fuel.code}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatEuros(cost.total),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'dont ${formatEuros(cost.tripCost)} de trajet '
                    '(~${cost.tripKm.round()} km aller-retour)',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
