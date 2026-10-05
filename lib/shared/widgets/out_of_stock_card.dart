import 'package:flutter/material.dart';

import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import 'price_totem.dart';

/// Takes the place of the price list on the sheet of a station with no fuel
/// on sale: says so, and which fuels it has run out of.
class OutOfStockCard extends StatelessWidget {
  const OutOfStockCard({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fuels = [
      for (final code in station.shortages)
        FuelType.fromCode(code)?.label ?? code,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OutOfStockTotem(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fuels.isEmpty
                    ? "Cette station signale n'avoir plus aucun carburant pour "
                          "l'instant."
                    : "Cette station signale être à court de : "
                          "${fuels.join(', ')}.",
                style: TextStyle(color: onSurface.withValues(alpha: 0.75)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
