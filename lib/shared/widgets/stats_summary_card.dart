import 'package:flutter/material.dart';

import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_stat.dart';
import '../../data/models/fuel_type.dart';
import 'price_totem.dart';

class StatsSummaryCard extends StatelessWidget {
  const StatsSummaryCard({super.key, required this.stats, this.title});

  final Map<FuelType, FuelStat?> stats;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final entries = FuelType.values.where((f) => stats[f] != null).toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final fuel in entries) ...[
                    _FuelStatColumn(fuel: fuel, stat: stats[fuel]!),
                    const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelStatColumn extends StatelessWidget {
  const _FuelStatColumn({required this.fuel, required this.stat});

  final FuelType fuel;
  final FuelStat stat;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fuel.code,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: fuel.color,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        PriceTotem(price: stat.avg, accentColor: fuel.color),
        const SizedBox(height: 4),
        Text(
          '${formatPrice(stat.min)} – ${formatPrice(stat.max)}',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.55),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
