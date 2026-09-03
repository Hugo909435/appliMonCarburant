import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/favorites_provider.dart';

class StationListTile extends ConsumerWidget {
  const StationListTile({
    super.key,
    required this.station,
    required this.fuel,
    this.distanceKm,
    required this.onTap,
  });

  final Station station;
  final FuelType fuel;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = station.prices[fuel.code];
    final isFavorite = ref.watch(favoritesProvider.select(
      (v) => (v.valueOrNull ?? const {}).contains(station.id),
    ));

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(
          station.isAutoroute ? Icons.local_gas_station : Icons.local_gas_station_outlined,
          color: AppColors.primary,
        ),
      ),
      title: Text(station.ville, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          station.adresse,
          if (distanceKm != null) formatDistance(distanceKm!),
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPrice(price),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? AppColors.accent : null,
            ),
            onPressed: () => ref.read(favoritesProvider.notifier).toggle(station.id),
          ),
        ],
      ),
    );
  }
}
