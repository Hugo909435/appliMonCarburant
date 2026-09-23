import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/price_gaps.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/fuel_selector.dart';
import '../../shared/widgets/price_gap_label.dart';
import '../../shared/widgets/price_totem.dart';

/// Largeur de la colonne figée qui nomme les carburants.
const _fuelColumnWidth = 78.0;

/// Largeur d'une colonne de station.
///
/// Elle est dictée par le totem de prix, qui ne se comprime pas : en dessous,
/// ses chiffres débordent. Les colonnes défilent horizontalement, donc mieux
/// vaut qu'elles restent lisibles que toutes visibles à la fois.
const _stationColumnWidth = 132.0;

const _headerHeight = 94.0;
const _rowHeight = 64.0;

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(comparisonProvider);
    final stations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final byId = {for (final station in stations) station.id: station};
    // L'ordre de sélection est celui de l'utilisateur : on le garde, sans
    // reclasser les colonnes sous ses yeux à chaque changement de carburant.
    final selected = [for (final id in ids) ?byId[id]];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer'),
        actions: [
          if (selected.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(comparisonProvider.notifier).clear(),
              child: const Text('Effacer'),
            ),
        ],
      ),
      body: selected.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                const SizedBox(height: 12),
                const FuelSelector(),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _VerdictCard(stations: selected),
                      const SizedBox(height: 20),
                      Text(
                        'Tous les carburants',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Écart au litre avec la moins chère de la sélection.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ComparisonTable(stations: selected),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Choisissez jusqu\'à $kMaxComparedStations stations sur la carte '
              'ou dans vos favoris pour comparer leurs prix.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// La réponse que l'écran doit donner en un coup d'œil : laquelle est la moins
/// chère pour le carburant choisi, et ce que l'écart représente sur un plein.
class _VerdictCard extends ConsumerWidget {
  const _VerdictCard({required this.stations});

  final List<Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(selectedFuelProvider);
    final liters = ref.watch(vehicleProfileProvider).fillLiters;
    final theme = Theme.of(context);

    final gaps = priceGaps({
      for (final station in stations) station.id: station.prices[fuel.code],
    });

    if (gaps.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gaps.isEmpty
                      ? 'Aucune des stations sélectionnées ne propose '
                            'du ${fuel.label}.'
                      : 'Une seule des stations sélectionnées propose '
                            'du ${fuel.label} : rien à comparer.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cheapestId = gaps.entries.firstWhere((e) => e.value.isCheapest).key;
    final cheapest = stations.firstWhere((s) => s.id == cheapestId);
    final widest = gaps.values
        .map((gap) => gap.perLiter)
        .reduce((a, b) => a > b ? a : b);
    final dearestId = gaps.entries
        .firstWhere((e) => e.value.perLiter == widest)
        .key;
    final dearest = stations.firstWhere((s) => s.id == dearestId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StationBrandLogo(
                  stationId: cheapest.id,
                  size: 34,
                  placeholder: const SizedBox(width: 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'La moins chère en ${fuel.code}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: AppColors.good,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cheapest.ville,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (cheapest.adresse.isNotEmpty)
                        Text(
                          cheapest.adresse,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PriceTotem(
                  price: gaps[cheapestId]!.price,
                  accentColor: fuel.color,
                  size: PriceTotemSize.large,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.good.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                widest == 0
                    // Rien à gagner : le dire franchement vaut mieux qu'annoncer
                    // une économie de 0,00 € face à la station elle-même.
                    ? 'Les ${gaps.length} stations affichent le même prix '
                          'en ${fuel.code} : seule la distance les départage.'
                    : 'Vous économisez '
                          '${formatEuros(gaps[dearestId]!.onFillUp(liters))} '
                          'sur un plein de ${liters.round()} L '
                          'face à ${dearest.ville} '
                          '(${formatPriceGap(widest)} le litre).',
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carburants en lignes, stations en colonnes. La colonne des carburants reste
/// figée pendant que les stations défilent : sans elle, on perd de vue ce que
/// chaque prix compare.
class _ComparisonTable extends ConsumerWidget {
  const _ComparisonTable({required this.stations});

  final List<Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(userLocationProvider).valueOrNull;

    // Une ligne n'a d'intérêt que si au moins une station affiche ce
    // carburant : les autres ne feraient que des tirets.
    final fuels = [
      for (final fuel in FuelType.values)
        if (stations.any((s) => s.prices.containsKey(fuel.code))) fuel,
    ];

    final gapsByFuel = {
      for (final fuel in fuels)
        fuel: priceGaps({
          for (final station in stations) station.id: station.prices[fuel.code],
        }),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 0, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(height: _headerHeight),
                for (final fuel in fuels) _FuelRowLabel(fuel: fuel),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final station in stations)
                      Column(
                        children: [
                          _StationColumnHeader(
                            station: station,
                            distanceKm: position == null
                                ? null
                                : station.distanceKmTo(
                                    position.latitude,
                                    position.longitude,
                                  ),
                            onRemove: () => ref
                                .read(comparisonProvider.notifier)
                                .toggle(station.id),
                          ),
                          for (final fuel in fuels)
                            _PriceCell(
                              fuel: fuel,
                              gap: gapsByFuel[fuel]![station.id],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelRowLabel extends StatelessWidget {
  const _FuelRowLabel({required this.fuel});

  final FuelType fuel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _fuelColumnWidth,
      height: _rowHeight,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: fuel.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fuel.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationColumnHeader extends StatelessWidget {
  const _StationColumnHeader({
    required this.station,
    required this.distanceKm,
    required this.onRemove,
  });

  final Station station;
  final double? distanceKm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final subtitle = distanceKm != null
        ? formatDistance(distanceKm!)
        : station.adresse;

    return SizedBox(
      width: _stationColumnWidth,
      height: _headerHeight,
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
          StationBrandLogo(
            stationId: station.id,
            size: 26,
            placeholder: const SizedBox(height: 26),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Text(
                  station.ville,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({required this.fuel, required this.gap});

  final FuelType fuel;

  /// `null` quand la station ne propose pas ce carburant : elle n'est pas
  /// « plus chère », elle est hors comparaison.
  final PriceGap? gap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final gap = this.gap;

    return Container(
      width: _stationColumnWidth,
      height: _rowHeight,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: gap != null && gap.isCheapest
          ? BoxDecoration(
              color: AppColors.good.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            )
          : null,
      child: gap == null
          ? Text(
              '—',
              style: TextStyle(
                fontSize: 16,
                color: onSurface.withValues(alpha: 0.35),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PriceTotem(price: gap.price, accentColor: fuel.color),
                const SizedBox(height: 4),
                PriceGapLabel(gap: gap),
              ],
            ),
    );
  }
}
