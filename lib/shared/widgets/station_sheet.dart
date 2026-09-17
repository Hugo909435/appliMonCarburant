import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import 'price_totem.dart';

/// Opens the expandable "station card" sheet: all fuel prices, services,
/// info, and the favorite / itinerary / compare actions.
Future<void> showStationSheet(BuildContext context, Station station) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) =>
          _StationSheetContent(station: station, scrollController: scrollController),
    ),
  );
}

class _StationSheetContent extends ConsumerWidget {
  const _StationSheetContent({
    required this.station,
    required this.scrollController,
  });

  final Station station;
  final ScrollController scrollController;

  Future<void> _openDirections() async {
    final uri = Uri.parse(
      'geo:${station.lat},${station.lng}?q=${station.lat},${station.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${station.lat},${station.lng}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select(
        (v) => (v.valueOrNull ?? const {}).contains(station.id),
      ),
    );
    final inComparison = ref.watch(
      comparisonProvider.select((ids) => ids.contains(station.id)),
    );
    final position = ref.watch(userLocationProvider).valueOrNull;
    final distance = position == null
        ? null
        : station.distanceKmTo(position.latitude, position.longitude);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.ville,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      station.adresse,
                      style: TextStyle(color: onSurface.withValues(alpha: 0.65)),
                    ),
                    Text(
                      [
                        '${station.cp} ${station.ville}',
                        if (distance != null) 'à ${formatDistance(distance)}',
                      ].join(' · '),
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? AppColors.accent : null,
                ),
                onPressed: () =>
                    ref.read(favoritesProvider.notifier).toggle(station.id),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openDirections,
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Itinéraire'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(comparisonProvider.notifier).toggle(station.id),
                  icon: Icon(
                    inComparison
                        ? Icons.check_circle_rounded
                        : Icons.compare_arrows_rounded,
                  ),
                  label: Text(inComparison ? 'Sélectionnée' : 'Comparer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Prix des carburants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final fuel in FuelType.values)
                    if (station.prices.containsKey(fuel.code)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                      if (fuel !=
                          FuelType.values.lastWhere(
                            (f) => station.prices.containsKey(f.code),
                          ))
                        const Divider(height: 1, indent: 14, endIndent: 14),
                    ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Dernière mise à jour : ${formatRelativeDate(station.lastUpdate)}',
              style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
          if (station.horaires != null || station.automate) ...[
            const SizedBox(height: 24),
            Text('Horaires', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    if (station.automate)
                      const ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.access_time_filled_rounded,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          'Automate 24h/24',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (station.horaires != null)
                      for (var i = 0; i < 7; i++)
                        ListTile(
                          dense: true,
                          title: Text(dayLabel(i)),
                          trailing: Text(formatHoursSlot(station.horaires![i])),
                        ),
                  ],
                ),
              ),
            ),
          ],
          if (station.services.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in station.services)
                  Chip(
                    label: Text(service),
                    avatar: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
