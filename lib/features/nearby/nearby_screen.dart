import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/fill_cost.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/station.dart';
import '../../providers/derived_providers.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../shared/widgets/fuel_selector.dart';
import '../../shared/widgets/station_list_tile.dart';
import '../../shared/widgets/ad_slot.dart';

enum _NearbySort { realCost, price, distance }

/// Beyond this, no detour to a cheaper station can pay off for a normal
/// fill-up, and listing all ~10 000 stations of France gets slow.
const _maxRadiusKm = 25.0;

class _Entry {
  const _Entry(this.station, this.distanceKm, this.price, this.cost);
  final Station station;
  final double distanceKm;
  final double price;
  final FillCost cost;
}

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  _NearbySort _sort = _NearbySort.realCost;

  @override
  void initState() {
    super.initState();
    if (ref.read(userLocationProvider).valueOrNull == null) {
      Future.microtask(
        () => ref.read(userLocationProvider.notifier).requestLocation(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearby = ref.watch(nearbyStationsProvider);
    final location = ref.watch(userLocationProvider);
    final fuel = ref.watch(selectedFuelProvider);

    final entries = <_Entry>[];
    for (final n in nearby) {
      if (n.distanceKm > _maxRadiusKm) break; // sorted by distance
      final price = n.station.prices[fuel.code];
      if (price == null) continue;
      entries.add(
        _Entry(
          n.station,
          n.distanceKm,
          price,
          computeFillCost(
            pricePerLiter: price,
            liters: kTypicalFillLiters,
            consumptionL100: kTypicalConsumptionL100,
            detourKm: n.distanceKm,
          ),
        ),
      );
    }

    // What the user would pay by just going to the closest station: the
    // baseline every "you save X €" figure is measured against.
    final baseline = entries.isEmpty ? null : entries.first.cost.total;
    final ads = InFeedAds(entries.length);

    switch (_sort) {
      case _NearbySort.realCost:
        entries.sort((a, b) => a.cost.total.compareTo(b.cost.total));
      case _NearbySort.price:
        entries.sort((a, b) => a.price.compareTo(b.price));
      case _NearbySort.distance:
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Autour de moi')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          const FuelSelector(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_NearbySort>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _NearbySort.realCost,
                  label: Text('Coût réel'),
                ),
                ButtonSegment(value: _NearbySort.price, label: Text('Prix')),
                ButtonSegment(
                  value: _NearbySort.distance,
                  label: Text('Distance'),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (s) => setState(() => _sort = s.first),
            ),
          ),
          if (_sort == _NearbySort.realCost)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                'Plein de ${kTypicalFillLiters.round()} L + carburant consommé '
                "pour l'aller-retour jusqu'à la station.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: location.isLoading
                ? const Center(child: CircularProgressIndicator())
                : location.hasError
                ? _Message(location.error.toString())
                : entries.isEmpty
                ? const _Message('Aucune station trouvée à proximité.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: ads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (ads.isAd(index)) return const AdSlot();
                      final e = entries[ads.itemIndex(index)];
                      return StationListTile(
                        station: e.station,
                        fuel: fuel,
                        distanceKm: e.distanceKm,
                        footer: _CostLine(cost: e.cost, baseline: baseline),
                        onTap: () => context.push('/station/${e.station.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine({required this.cost, required this.baseline});

  final FillCost cost;
  final double? baseline;

  @override
  Widget build(BuildContext context) {
    final saving = baseline == null ? 0.0 : baseline! - cost.total;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 12.5,
          color: onSurface.withValues(alpha: 0.8),
        ),
        children: [
          TextSpan(
            text: formatEuros(cost.total),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' (dont ${formatEuros(cost.tripCost)} de trajet)'),
          if (saving.abs() >= 0.05)
            TextSpan(
              text: saving > 0
                  ? ' · −${formatEuros(saving)}'
                  : ' · +${formatEuros(-saving)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: saving > 0 ? AppColors.good : AppColors.bad,
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
