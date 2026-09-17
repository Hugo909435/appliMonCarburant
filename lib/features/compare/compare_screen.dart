import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';
import '../../shared/widgets/price_totem.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(comparisonProvider);
    final stations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final selected = [
      for (final id in ids) stations.where((s) => s.id == id).firstOrNull,
    ].whereType<Station>().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer'),
        actions: [
          if (selected.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(comparisonProvider.notifier).clear(),
              child: const Text('Effacer'),
            ),
        ],
      ),
      body: selected.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final station in selected) ...[
                  _StationCompareCard(
                    station: station,
                    onRemove: () =>
                        ref.read(comparisonProvider.notifier).toggle(station.id),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choisissez jusqu\'à deux stations sur la carte pour comparer leurs prix.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StationCompareCard extends ConsumerWidget {
  const _StationCompareCard({required this.station, required this.onRemove});

  final Station station;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(userLocationProvider).valueOrNull;
    final distance = position == null
        ? null
        : station.distanceKmTo(position.latitude, position.longitude);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.ville,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          station.adresse,
                          if (distance != null) 'à ${formatDistance(distance)}',
                        ].join(' · '),
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final fuel in FuelType.values)
              if (station.prices.containsKey(fuel.code))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: fuel.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fuel.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      PriceTotem(
                        price: station.prices[fuel.code],
                        accentColor: fuel.color,
                      ),
                    ],
                  ),
                ),
            if (station.services.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final service in station.services)
                    Chip(
                      label: Text(service, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
