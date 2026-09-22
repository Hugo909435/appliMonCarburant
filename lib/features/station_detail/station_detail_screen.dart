import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/station_brands_provider.dart';
import '../../providers/stations_provider.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/fill_cost_card.dart';
import '../../shared/widgets/price_totem.dart';

class StationDetailScreen extends ConsumerWidget {
  const StationDetailScreen({super.key, required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final station = stations.where((s) => s.id == stationId).firstOrNull;

    if (station == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Station')),
        body: const Center(child: Text('Station introuvable.')),
      );
    }

    final isFavorite = ref.watch(
      favoritesProvider.select(
        (v) => (v.valueOrNull ?? const {}).contains(station.id),
      ),
    );
    final position = ref.watch(userLocationProvider).valueOrNull;
    final distance = position == null
        ? null
        : station.distanceKmTo(position.latitude, position.longitude);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final brand = ref.watch(stationBrandProvider(station.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche station'),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              StationBrandLogo(
                stationId: station.id,
                size: 44,
                placeholder: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    station.isAutoroute
                        ? Icons.local_gas_station_rounded
                        : Icons.local_gas_station_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brand != null)
                      Text(
                        brand.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      station.ville,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      station.adresse,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.65),
                      ),
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
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openDirections(station),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Itinéraire'),
          ),
          const SizedBox(height: 28),
          Text(
            'Prix des carburants',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
          if (distance != null) ...[
            const SizedBox(height: 12),
            FillCostCard(station: station, distanceKm: distance),
          ],
          if (station.horaires != null) ...[
            const SizedBox(height: 28),
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
            const SizedBox(height: 28),
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

  Future<void> _openDirections(Station station) async {
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
