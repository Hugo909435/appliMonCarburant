import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ev_station.dart';
import '../../../shared/widgets/brand_badge.dart';
import '../../../shared/widgets/see_more_button.dart';
import '../../../shared/widgets/trip_line.dart';

/// Colour of a charger by its top power: green for slow AC, orange for
/// fast, pink for high-power DC. Shared by the map markers and the list.
Color evPowerColor(double maxPowerKw) {
  if (maxPowerKw >= 100) return const Color(0xFFD81B60);
  if (maxPowerKw >= 22) return const Color(0xFFFB8C00);
  return const Color(0xFF2F8F5B);
}

/// An EV charger in the home list: network, name, address and distance,
/// with its top power where a fuel station shows its price.
class EvStationListTile extends StatelessWidget {
  const EvStationListTile({
    super.key,
    required this.station,
    this.distanceKm,
    required this.onTap,
    this.onMore,
  });

  final EvStation station;
  final double? distanceKm;
  final VoidCallback onTap;

  /// Ouvre la fiche complète, quand [onTap] fait autre chose : ajoute alors
  /// un lien « Voir plus » sous le détail des points de charge.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = evPowerColor(station.maxPowerKw);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (station.network.isNotEmpty)
                BrandBadge(brand: station.network, size: 34)
              else
                const SizedBox(width: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (station.address.isNotEmpty)
                      Text(
                        station.address,
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
                    const SizedBox(height: 4),
                    Text(
                      [
                        station.pointCount == 1
                            ? '1 point'
                            : '${station.pointCount} points',
                        if (station.plugTypes.isNotEmpty)
                          station.plugTypes.join(', '),
                        if (station.free) 'Gratuit',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onMore case final more?) SeeMoreButton(onPressed: more),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PowerBadge(kw: station.maxPowerKw, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.kw, required this.color});

  final double kw;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: color),
          Text(
            kw > 0 ? '${kw.toStringAsFixed(0)} kW' : '? kW',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
