import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';

class StationDetailScreen extends ConsumerWidget {
  const StationDetailScreen({super.key, required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final station = stations.where((s) => s.id == stationId).firstOrNull;

    if (station == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Station')),
        body: const Center(child: Text('Station introuvable.')),
      );
    }

    final isFavorite = ref.watch(favoritesProvider.select(
      (v) => (v.valueOrNull ?? const {}).contains(station.id),
    ));
    final position = ref.watch(userLocationProvider).valueOrNull;
    final distance = position == null
        ? null
        : station.distanceKmTo(position.latitude, position.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(station.ville),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
            onPressed: () => ref.read(favoritesProvider.notifier).toggle(station.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(station.adresse, style: Theme.of(context).textTheme.titleMedium),
          Text('${station.cp} ${station.ville}'),
          if (distance != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('À ${formatDistance(distance)}'),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openDirections(station),
            icon: const Icon(Icons.directions),
            label: const Text('Itinéraire'),
          ),
          const SizedBox(height: 24),
          Text('Prix des carburants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final fuel in FuelType.values)
                  if (station.prices.containsKey(fuel.code))
                    ListTile(
                      title: Text(fuel.label),
                      trailing: Text(
                        formatPrice(station.prices[fuel.code]),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Dernière mise à jour : ${formatRelativeDate(station.lastUpdate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (station.horaires != null) ...[
            const SizedBox(height: 24),
            Text('Horaires', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (station.automate)
                      const ListTile(
                        dense: true,
                        leading: Icon(Icons.access_time_filled, color: AppColors.accent),
                        title: Text('Automate 24h/24'),
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
            const SizedBox(height: 24),
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in station.services) Chip(label: Text(service)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDirections(Station station) async {
    final uri = Uri.parse('geo:${station.lat},${station.lng}?q=${station.lat},${station.lng}');
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
