import 'package:flutter/material.dart';

import '../../core/utils/drive_time.dart';
import '../../core/utils/formatters.dart';

/// « 2,4 km · ≈ 6 min » under a station in a list: how far it is from the
/// user and roughly how long it takes to drive there. On its own line so a
/// long address can't push it out of sight.
class TripLine extends StatelessWidget {
  const TripLine({super.key, required this.distanceKm});

  /// Straight-line distance from the user's position.
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.75);
    final style = TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Icon(Icons.near_me_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${formatDistance(distanceKm)} · '
            '≈ ${formatDriveTime(estimateDriveTime(distanceKm))}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
