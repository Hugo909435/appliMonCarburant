import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/price_gaps.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/favorites_provider.dart';
import 'brand_logo.dart';
import 'price_gap_label.dart';
import 'price_totem.dart';
import 'see_more_button.dart';
import 'trip_line.dart';

class StationListTile extends ConsumerWidget {
  const StationListTile({
    super.key,
    required this.station,
    required this.fuel,
    this.distanceKm,
    this.footer,
    this.priceGap,
    required this.onTap,
    this.onMore,
  });

  final Station station;
  final FuelType fuel;
  final double? distanceKm;

  /// Position de cette station par rapport à la moins chère de la liste où
  /// elle figure. `null` quand l'écran ne compare pas ses stations entre
  /// elles, et la mention disparaît.
  final PriceGap? priceGap;

  /// Optional extra line under the address (e.g. the real cost of a fill-up).
  final Widget? footer;
  final VoidCallback onTap;

  /// Ouvre la fiche complète, quand [onTap] fait autre chose : ajoute alors
  /// un lien « Voir plus » sous l'adresse.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = station.prices[fuel.code];
    final isFavorite = ref.watch(
      favoritesProvider.select(
        (v) => (v.valueOrNull ?? const {}).contains(station.id),
      ),
    );
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: fuel.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              StationBrandLogo(
                stationId: station.id,
                size: 34,
                placeholder: const SizedBox(width: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.ville,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (station.adresse.isNotEmpty)
                      Text(
                        station.adresse,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    if (distanceKm case final km?) ...[
                      const SizedBox(height: 3),
                      TripLine(distanceKm: km),
                    ],
                    if (footer != null) ...[const SizedBox(height: 4), footer!],
                    if (onMore case final more?) SeeMoreButton(onPressed: more),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PriceTotem(price: price, accentColor: fuel.color),
                  if (priceGap case final gap?) ...[
                    const SizedBox(height: 4),
                    PriceGapLabel(gap: gap),
                  ],
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite
                      ? onSurface
                      : onSurface.withValues(alpha: 0.35),
                ),
                onPressed: () =>
                    ref.read(favoritesProvider.notifier).toggle(station.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
