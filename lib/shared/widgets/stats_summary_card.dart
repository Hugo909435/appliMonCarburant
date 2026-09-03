import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_stat.dart';
import '../../data/models/fuel_type.dart';

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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final fuel in entries) _FuelStatColumn(fuel: fuel, stat: stats[fuel]!),
              ],
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
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fuel.code,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(formatPrice(stat.avg), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            '${formatPrice(stat.min)} - ${formatPrice(stat.max)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
