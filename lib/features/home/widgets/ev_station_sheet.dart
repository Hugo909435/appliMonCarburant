import 'package:flutter/material.dart';

import '../../../core/utils/directions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ev_station.dart';
import '../../../shared/widgets/brand_badge.dart';

Future<void> showEvStationSheet(BuildContext context, EvStation station) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => _EvStationSheetContent(station: station),
  );
}

class _EvStationSheetContent extends StatelessWidget {
  const _EvStationSheetContent({required this.station});

  final EvStation station;

  Future<void> _openDirections() =>
      openDirectionsTo(station.lat, station.lng, label: station.name);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (station.network.isNotEmpty) ...[
                  BrandBadge(brand: station.network, size: 30),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        station.address,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.bolt_rounded,
                  label: '${station.maxPowerKw.toStringAsFixed(0)} kW max',
                ),
                _InfoChip(
                  icon: Icons.ev_station_rounded,
                  label: '${station.pointCount} point(s)',
                ),
                _InfoChip(
                  icon: station.free
                      ? Icons.money_off_rounded
                      : Icons.payments_rounded,
                  label: station.free ? 'Gratuit' : 'Payant',
                ),
                if (station.pmrAccessible)
                  const _InfoChip(
                    icon: Icons.accessible_rounded,
                    label: 'Accessible PMR',
                  ),
              ],
            ),
            if (station.plugTypes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Prises', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final plug in station.plugTypes) Chip(label: Text(plug)),
                ],
              ),
            ],
            if (station.accessCondition.isNotEmpty ||
                station.hours.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Infos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (station.accessCondition.isNotEmpty)
                Text(station.accessCondition),
              if (station.hours.isNotEmpty) Text('Horaires : ${station.hours}'),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Itinéraire'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}
