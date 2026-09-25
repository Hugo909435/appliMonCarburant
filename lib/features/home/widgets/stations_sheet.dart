import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_gaps.dart';
import '../../../providers/derived_providers.dart';
import '../../../providers/ev_stations_provider.dart';
import '../../../providers/filters_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../shared/widgets/ad_slot.dart';
import '../../../shared/widgets/station_list_tile.dart';
import '../../../shared/widgets/station_sheet.dart';
import 'ev_station_sheet.dart';
import 'ev_station_tile.dart';

/// Height of the sheet when pulled all the way down: the handle and the
/// header (count + sort), so the list is always one flick away without
/// hiding the map.
const kStationsSheetPeek = 112.0;

/// The list of stations — or EV chargers when [ev] is set — inside the
/// map's visible area, in a sheet the user drags over the map — peek, half
/// screen or almost full screen.
///
/// It follows the map: panning or zooming refreshes it (see
/// [viewportStationsProvider]), so the map answers "where" and the list
/// answers "how much".
class StationsSheet extends StatefulWidget {
  const StationsSheet({
    super.key,
    required this.availableHeight,
    required this.extent,
    required this.onFocus,
    this.ev = false,
  });

  /// Centre la carte sur une station ou une borne touchée dans la liste.
  final void Function(double lat, double lng) onFocus;

  /// Lists the EV chargers in view instead of the fuel stations.
  final bool ev;

  /// Height of the area the sheet slides over, to turn the pixel peek
  /// height into a fraction.
  final double availableHeight;

  /// Current fraction of [availableHeight] the sheet covers, so the map's
  /// floating controls can stay just above it.
  final ValueNotifier<double> extent;

  static const initialFraction = 0.38;
  static const maxFraction = 0.94;

  @override
  State<StationsSheet> createState() => _StationsSheetState();
}

class _StationsSheetState extends State<StationsSheet> {
  final _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tapping the header opens the list fully, or folds it back to half.
  void _toggle() {
    if (!_controller.isAttached) return;
    final open = _controller.size > StationsSheet.initialFraction + 0.05;
    _controller.animateTo(
      open ? StationsSheet.initialFraction : StationsSheet.maxFraction,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Toucher une ligne montre l'endroit sur la carte : la liste redescend
  /// d'abord à mi-hauteur si elle la recouvrait presque entièrement.
  void _focus(double lat, double lng) {
    if (_controller.isAttached &&
        _controller.size > StationsSheet.initialFraction + 0.05) {
      _controller.animateTo(
        StationsSheet.initialFraction,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onFocus(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final minFraction = (kStationsSheetPeek / widget.availableHeight).clamp(
      0.05,
      StationsSheet.initialFraction,
    );
    final scheme = Theme.of(context).colorScheme;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        widget.extent.value = n.extent;
        return false;
      },
      // On the web and desktop, Flutter only drags scrollables by touch:
      // without this the sheet can't be pulled up with a mouse.
      child: ScrollConfiguration(
        behavior: const _SheetScrollBehavior(),
        child: DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: StationsSheet.initialFraction,
          minChildSize: minFraction,
          maxChildSize: StationsSheet.maxFraction,
          snap: true,
          snapSizes: const [StationsSheet.initialFraction],
          builder: (context, scrollController) => DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: widget.ev
                  ? _EvSheetContent(
                      scrollController: scrollController,
                      onHeaderTap: _toggle,
                      onFocus: _focus,
                    )
                  : _SheetContent(
                      scrollController: scrollController,
                      onHeaderTap: _toggle,
                      onFocus: _focus,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetScrollBehavior extends MaterialScrollBehavior {
  const _SheetScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _SheetContent extends ConsumerWidget {
  const _SheetContent({
    required this.scrollController,
    required this.onHeaderTap,
    required this.onFocus,
  });

  final ScrollController scrollController;
  final VoidCallback onHeaderTap;
  final void Function(double lat, double lng) onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(viewportStationsProvider);
    final fuel = ref.watch(selectedFuelProvider);

    // Every station here has a price for [fuel]: filtered out upstream.
    final cheapest = stations.isEmpty
        ? null
        : stations
              .map((l) => l.station.prices[fuel.code]!)
              .reduce((a, b) => a < b ? a : b);
    final ads = InFeedAds(stations.length);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            title: _countLabel(stations.length, 'station'),
            onTap: onHeaderTap,
            toggle: _SortToggle<StationSort>(
              provider: stationSortProvider,
              nearest: StationSort.nearest,
              options: const [
                (StationSort.cheapest, Icons.euro_rounded, 'Moins chères'),
                (StationSort.nearest, Icons.near_me_rounded, 'Plus proches'),
              ],
            ),
          ),
        ),
        if (stations.isEmpty)
          const SliverToBoxAdapter(
            child: _EmptyState(
              'Aucune station ne correspond ici.\n'
              'Déplacez la carte, dézoomez ou assouplissez les filtres.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList.separated(
              itemCount: ads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (ads.isAd(index)) return const AdSlot();
                final listed = stations[ads.itemIndex(index)];
                final price = listed.station.prices[fuel.code]!;
                return StationListTile(
                  station: listed.station,
                  fuel: fuel,
                  distanceKm: listed.distanceKm,
                  priceGap: PriceGap(price: price, perLiter: price - cheapest!),
                  onTap: () => onFocus(listed.station.lat, listed.station.lng),
                  onMore: () => showStationSheet(context, listed.station),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The chargers in view: same sheet as the fuel stations, ranked by power
/// rather than price.
class _EvSheetContent extends ConsumerWidget {
  const _EvSheetContent({
    required this.scrollController,
    required this.onHeaderTap,
    required this.onFocus,
  });

  final ScrollController scrollController;
  final VoidCallback onHeaderTap;
  final void Function(double lat, double lng) onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(viewportEvStationsProvider);
    final loading = ref.watch(evStationsProvider.select((v) => v.isLoading));
    final ads = InFeedAds(stations.length);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            title: _countLabel(stations.length, 'borne'),
            onTap: onHeaderTap,
            toggle: _SortToggle<EvSort>(
              provider: evSortProvider,
              nearest: EvSort.nearest,
              options: const [
                (EvSort.fastest, Icons.bolt_rounded, 'Plus rapides'),
                (EvSort.nearest, Icons.near_me_rounded, 'Plus proches'),
              ],
            ),
          ),
        ),
        if (stations.isEmpty)
          SliverToBoxAdapter(
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const _EmptyState(
                    'Aucune borne ne correspond ici.\n'
                    'Déplacez la carte, dézoomez ou assouplissez les filtres.',
                  ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList.separated(
              itemCount: ads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (ads.isAd(index)) return const AdSlot();
                final listed = stations[ads.itemIndex(index)];
                return EvStationListTile(
                  station: listed.station,
                  distanceKm: listed.distanceKm,
                  onTap: () => onFocus(listed.station.lat, listed.station.lng),
                  onMore: () => showEvStationSheet(context, listed.station),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// « Aucune station », « 1 station », « 12 stations ».
String _countLabel(int count, String noun) => switch (count) {
  0 => 'Aucune $noun',
  1 => '1 $noun',
  _ => '$count ${noun}s',
};

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.title,
    required this.toggle,
    required this.onTap,
  });

  final String title;
  final Widget toggle;
  final VoidCallback onTap;

  @override
  double get minExtent => kStationsSheetPeek;

  @override
  double get maxExtent => kStationsSheetPeek;

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.title != title;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleLarge),
                      Text(
                        'dans la zone affichée',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                toggle,
              ],
            ),
            const Spacer(),
            Divider(height: 1, color: scheme.outline.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Two-way sort switch, e.g. « Moins chères » / « Plus proches ». Picking
/// [nearest] without a known position asks for it first, and stays on the
/// current order if that fails.
class _SortToggle<T> extends ConsumerWidget {
  const _SortToggle({
    required this.provider,
    required this.nearest,
    required this.options,
  });

  final StateProvider<T> provider;
  final T nearest;
  final List<(T, IconData, String)> options;

  Future<void> _select(BuildContext context, WidgetRef ref, T sort) async {
    if (sort == nearest && ref.read(userLocationProvider).valueOrNull == null) {
      await ref.read(userLocationProvider.notifier).requestLocation();
      final result = ref.read(userLocationProvider);
      if (result.valueOrNull == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.hasError
                    ? result.error.toString()
                    : 'Position indisponible.',
              ),
            ),
          );
        }
        return;
      }
    }
    ref.read(provider.notifier).state = sort;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(provider);
    final locating = ref.watch(userLocationProvider.select((v) => v.isLoading));
    final scheme = Theme.of(context).colorScheme;

    Widget segment(T value, IconData icon, String label) {
      final selected = sort == value;
      return Material(
        color: selected ? scheme.onSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm - 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm - 3),
          onTap: selected ? null : () => _select(context, ref, value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value == nearest && locating)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: selected ? scheme.surface : scheme.onSurface,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? scheme.surface : scheme.onSurface,
                  ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.surface : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, icon, label) in options)
            segment(value, icon, label),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Icon(Icons.travel_explore_rounded, size: 36, color: muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}
