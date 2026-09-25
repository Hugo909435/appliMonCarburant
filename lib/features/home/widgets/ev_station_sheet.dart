import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/directions.dart';
import '../../../data/models/ev_station.dart';
import '../../../providers/ev_stations_provider.dart';
import '../../../shared/widgets/brand_badge.dart';
import '../../../shared/widgets/loading_bar.dart';

Future<void> showEvStationSheet(BuildContext context, EvStation station) {
  return showModalBottomSheet(
    context: context,
    // Sans quoi la feuille plafonne à mi-écran et coupe le bas de la fiche.
    isScrollControlled: true,
    builder: (context) => _EvStationSheetContent(station: station),
  );
}

class _EvStationSheetContent extends ConsumerWidget {
  const _EvStationSheetContent({required this.station});

  final EvStation station;

  Future<void> _openDirections() =>
      openDirectionsTo(station.lat, station.lng, label: station.name);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Chargés à l'ouverture : la carte ne les télécharge pas pour chaque
    // borne. En cas d'échec, la fiche s'en passe.
    final detailsAsync = ref.watch(evStationDetailsProvider(station.id));
    final details = detailsAsync.valueOrNull;

    return SafeArea(
      child: SingleChildScrollView(
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
                  if (details?.pmrAccessible ?? false)
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
                    for (final plug in station.plugTypes)
                      Chip(label: Text(plug)),
                  ],
                ),
              ],
              if (detailsAsync.isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: LoadingBar()),
              ] else if (details != null &&
                  (details.accessCondition.isNotEmpty ||
                      details.hours.isNotEmpty)) ...[
                const SizedBox(height: 16),
                Text('Infos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                if (details.accessCondition.isNotEmpty)
                  Text(details.accessCondition),
                if (details.hours.isNotEmpty)
                  Text('Horaires : ${details.hours}'),
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
