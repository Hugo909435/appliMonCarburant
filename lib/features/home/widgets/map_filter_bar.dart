import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brands/brand_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fuel_colors.dart';
import '../../../data/models/ev_station.dart';
import '../../../data/models/fuel_type.dart';
import '../../../providers/derived_providers.dart';
import '../../../providers/ev_stations_provider.dart';
import '../../../providers/filters_provider.dart';
import '../../../providers/map_viewport_provider.dart';
import '../../../providers/station_brands_provider.dart';
import '../../../providers/stations_provider.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/loading_bar.dart';

/// Each filter's icon gets its own fixed color so it reads as a small
/// "logo" at a glance — the chips themselves stay white/navy.
class _FilterColors {
  static const stations = Color(0xFFE87722);
  static const bornes = Color(0xFF2F8F5B);
  static const enseigne = Color(0xFF8E24AA);
  static const autoroute = Color(0xFF1E88E5);
  static const departement = Color(0xFF00897B);
  static const favoris = Color(0xFFFFB300);
  static const service = Color(0xFF6D4C41);
  static const plugType = Color(0xFF1E6FA8);
  static const power = Color(0xFFFFA000);
  static const evOperator = Color(0xFF8E24AA);
}

/// The horizontal filter row floating over the map, under the search: fuel stations
/// vs. EV chargers, a "Filtres" button opening every filter at once, then
/// (for fuel stations) fuel type, brand, motorway and favorites-only
/// refinements, the active ones first.
///
/// Only two or three chips fit on a phone, so the row shows a chevron on
/// its right edge while more are hidden past it.
class MapFilterBar extends ConsumerStatefulWidget {
  const MapFilterBar({super.key});

  @override
  ConsumerState<MapFilterBar> createState() => _MapFilterBarState();
}

class _MapFilterBarState extends ConsumerState<MapFilterBar> {
  final _scroll = ScrollController();
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics m) {
    final left = m.pixels > 4;
    final right = m.pixels < m.maxScrollExtent - 4;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
    return false;
  }

  void _scrollForward() {
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + p.viewportDimension * 0.6).clamp(0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layer = ref.watch(mapLayerProvider);

    // Actifs d'abord : un filtre posé reste visible sans faire défiler.
    final refinements = switch (layer) {
      MapLayer.stations => [
        (ref.watch(selectedBrandProvider) != null, const _BrandChip()),
        (ref.watch(departmentFilterProvider) != null, const _DepartmentChip()),
        (ref.watch(highwayFilterProvider) != null, const _AutorouteChip()),
        (ref.watch(selectedServiceProvider) != null, const _ServiceChip()),
        (ref.watch(favoritesOnlyProvider), const _FavoritesChip()),
      ],
      MapLayer.bornes => [
        (ref.watch(plugTypeFilterProvider) != null, const _PlugTypeChip()),
        (ref.watch(evOperatorFilterProvider) != null, const _EvOperatorChip()),
        (ref.watch(evMinPowerProvider) != null, const _EvPowerChip()),
      ],
      null => <(bool, Widget)>[],
    };
    final chips = [
      ...refinements.where((r) => r.$1).map((r) => r.$2),
      ...refinements.where((r) => !r.$1).map((r) => r.$2),
    ];

    // Posée entre la loupe et le compte : sa hauteur garde de la place pour
    // l'ombre des pastilles, que la liste rognerait sinon. Le fondu n'apparaît
    // que du côté où il reste des filtres à voir.
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                _moreLeft ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _moreRight ? Colors.transparent : Colors.black,
              ],
              stops: const [0, 0.05, 0.8, 1],
            ).createShader(bounds),
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => _onMetrics(n.metrics),
                child: ScrollConfiguration(
                  behavior: _DragScrollBehavior(),
                  child: ListView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(8, 11, 40, 11),
                    children: [
                      if (layer == null) ...[
                        // Nothing picked yet: show full labels as a clear
                        // call to action, instead of two unlabeled logos.
                        _Pill(
                          selected: false,
                          icon: Icons.local_gas_station_rounded,
                          iconColor: _FilterColors.stations,
                          label: 'Stations',
                          onTap: () =>
                              ref.read(mapLayerProvider.notifier).state =
                                  MapLayer.stations,
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          selected: false,
                          icon: Icons.ev_station_rounded,
                          iconColor: _FilterColors.bornes,
                          label: 'Bornes électriques',
                          onTap: () =>
                              ref.read(mapLayerProvider.notifier).state =
                                  MapLayer.bornes,
                        ),
                      ] else ...[
                        _LayerToggle(
                          layer: layer,
                          onChanged: (l) =>
                              ref.read(mapLayerProvider.notifier).state = l,
                        ),
                        const SizedBox(width: 8),
                        const _AllFiltersButton(),
                        if (layer == MapLayer.stations) ...[
                          const SizedBox(width: 8),
                          const _FuelChip(),
                        ],
                        for (final chip in chips) ...[
                          const SizedBox(width: 8),
                          chip,
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IgnorePointer(
              ignoring: !_moreRight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _moreRight ? 1 : 0,
                child: _MoreArrow(onTap: _scrollForward),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the horizontal filter row be dragged to scroll with a mouse/
/// trackpad too, not just touch — otherwise it's stuck on web/desktop.
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Stations / bornes as one segmented capsule, so the pair reads as a
/// single switch rather than two more filters.
class _LayerToggle extends StatelessWidget {
  const _LayerToggle({required this.layer, required this.onChanged});

  final MapLayer layer;
  final ValueChanged<MapLayer> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(MapLayer value, IconData icon, Color color, String tip) {
      final selected = layer == value;
      return Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: selected ? Colors.white : color),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(19)),
        boxShadow: _chipShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment(
              MapLayer.stations,
              Icons.local_gas_station_rounded,
              _FilterColors.stations,
              'Stations',
            ),
            const SizedBox(width: 2),
            segment(
              MapLayer.bornes,
              Icons.ev_station_rounded,
              _FilterColors.bornes,
              'Bornes électriques',
            ),
          ],
        ),
      ),
    );
  }
}

/// Round white button on the row's right edge, shown while chips are
/// hidden past it.
class _MoreArrow extends StatelessWidget {
  const _MoreArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Plus de filtres',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// How many refinements are set on the current layer (the fuel type, always
/// set, doesn't count).
final _activeFilterCountProvider = Provider.autoDispose<int>((ref) {
  final active = switch (ref.watch(mapLayerProvider)) {
    MapLayer.stations => [
      ref.watch(selectedBrandProvider) != null,
      ref.watch(departmentFilterProvider) != null,
      ref.watch(highwayFilterProvider) != null,
      ref.watch(selectedServiceProvider) != null,
      ref.watch(favoritesOnlyProvider),
    ],
    MapLayer.bornes => [
      ref.watch(plugTypeFilterProvider) != null,
      ref.watch(evOperatorFilterProvider) != null,
      ref.watch(evMinPowerProvider) != null,
    ],
    null => const <bool>[],
  };
  return active.where((a) => a).length;
});

/// Clears every refinement of the current layer, keeping the fuel type.
void _clearFilters(WidgetRef ref) {
  switch (ref.read(mapLayerProvider)) {
    case MapLayer.stations:
      ref.read(selectedBrandProvider.notifier).state = null;
      ref.read(departmentFilterProvider.notifier).state = null;
      ref.read(highwayFilterProvider.notifier).state = null;
      ref.read(selectedServiceProvider.notifier).state = null;
      ref.read(favoritesOnlyProvider.notifier).state = false;
    case MapLayer.bornes:
      ref.read(plugTypeFilterProvider.notifier).state = null;
      ref.read(evOperatorFilterProvider.notifier).state = null;
      ref.read(evMinPowerProvider.notifier).state = null;
    case null:
      break;
  }
}

/// "Filtres" button with the number of active filters: an entry point that
/// stays in view whatever fits in the row.
class _AllFiltersButton extends ConsumerWidget {
  const _AllFiltersButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_activeFilterCountProvider);
    return _Pill(
      selected: count > 0,
      icon: Icons.tune_rounded,
      label: 'Filtres',
      trailing: count > 0
          ? Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => const _AllFiltersSheet(),
      ),
    );
  }
}

/// Every filter of the current layer as a list, each with its current
/// value. A row opens that filter's own picker on top.
class _AllFiltersSheet extends ConsumerWidget {
  const _AllFiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(mapLayerProvider);
    final count = ref.watch(_activeFilterCountProvider);
    final theme = Theme.of(context);

    final List<Widget> rows;
    if (layer == MapLayer.bornes) {
      final plug = ref.watch(plugTypeFilterProvider);
      final op = ref.watch(evOperatorFilterProvider);
      final power = ref.watch(evMinPowerProvider);
      rows = [
        _FilterRow(
          icon: Icons.power_rounded,
          color: _FilterColors.plugType,
          title: 'Connecteur',
          value: plug,
          onTap: () => _PlugTypeChip._pickPlugType(context, ref),
          onClear: () => ref.read(plugTypeFilterProvider.notifier).state = null,
        ),
        _FilterRow(
          icon: Icons.apartment_rounded,
          color: _FilterColors.evOperator,
          title: 'Opérateur',
          value: op?.name,
          onTap: () => _EvOperatorChip._pickOperator(context),
          onClear: () =>
              ref.read(evOperatorFilterProvider.notifier).state = null,
        ),
        _FilterRow(
          icon: Icons.bolt_rounded,
          color: _FilterColors.power,
          title: 'Puissance minimale',
          value: power == null ? null : '$power kW et +',
          onTap: () => _EvPowerChip._pickPower(context, ref),
          onClear: () => ref.read(evMinPowerProvider.notifier).state = null,
        ),
      ];
    } else {
      final fuel = ref.watch(selectedFuelProvider);
      final brandKey = ref.watch(selectedBrandProvider);
      final dep = ref.watch(departmentFilterProvider);
      final depName = dep == null
          ? null
          : (ref.watch(departmentsDataProvider).valueOrNull?[dep]?.name ?? dep);
      final highway = ref.watch(highwayFilterProvider);
      final service = ref.watch(selectedServiceProvider);
      final favorites = ref.watch(favoritesOnlyProvider);
      rows = [
        _FilterRow(
          icon: Icons.water_drop_rounded,
          color: fuel.color,
          title: 'Carburant',
          value: fuel.code,
          onTap: () => _FuelChip._pickFuel(context, ref),
        ),
        _FilterRow(
          icon: Icons.storefront_rounded,
          color: _FilterColors.enseigne,
          title: 'Enseigne',
          value: brandKey == null ? null : brandForKey(brandKey)?.name,
          onTap: () => _BrandChip._pickBrand(context, ref),
          onClear: () => ref.read(selectedBrandProvider.notifier).state = null,
        ),
        _FilterRow(
          icon: Icons.map_rounded,
          color: _FilterColors.departement,
          title: 'Département',
          value: depName,
          onTap: () => _DepartmentChip._pickDepartment(context, ref),
          onClear: () =>
              ref.read(departmentFilterProvider.notifier).state = null,
        ),
        _FilterRow(
          icon: Icons.route_rounded,
          color: _FilterColors.autoroute,
          title: 'Autoroute',
          value: highway == null
              ? null
              : highway == kAnyHighway
              ? 'Toutes les autoroutes'
              : highway,
          onTap: () => _AutorouteChip._pickHighway(context, ref),
          onClear: () => ref.read(highwayFilterProvider.notifier).state = null,
        ),
        _FilterRow(
          icon: Icons.room_service_rounded,
          color: _FilterColors.service,
          title: 'Service',
          value: service,
          onTap: () => _ServiceChip._pickService(context, ref),
          onClear: () =>
              ref.read(selectedServiceProvider.notifier).state = null,
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.only(left: 20, right: 16),
          secondary: const _FilterIcon(
            icon: Icons.star_rounded,
            color: _FilterColors.favoris,
          ),
          title: const Text(
            'Favoris uniquement',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          value: favorites,
          onChanged: (v) => ref.read(favoritesOnlyProvider.notifier).state = v,
        ),
      ];
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    layer == MapLayer.bornes
                        ? 'Filtres des bornes'
                        : 'Filtres des stations',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (count > 0)
                  TextButton(
                    onPressed: () => _clearFilters(ref),
                    child: const Text('Tout effacer'),
                  ),
              ],
            ),
          ),
          Flexible(child: ListView(shrinkWrap: true, children: rows)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voir la carte'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A filter's colored icon on a tinted rounded square.
class _FilterIcon extends StatelessWidget {
  const _FilterIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// One line of the filters sheet: icon, name, current value ("Tous" when
/// unset) and either a clear button or a chevron.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? value;
  final VoidCallback onTap;

  /// Null for a filter that's always set (the fuel type).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = value != null && onClear != null;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 8),
      leading: _FilterIcon(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        value ?? 'Tous',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: active
          ? IconButton(
              tooltip: 'Retirer ce filtre',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClear,
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.chevron_right_rounded),
            ),
      onTap: onTap,
    );
  }
}

/// The fuel-type filter keeps its label (unlike the other logo badges) so
/// the exact selected fuel is always readable, not just its color.
class _FuelChip extends ConsumerWidget {
  const _FuelChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(selectedFuelProvider);
    return _Pill(
      selected: false,
      icon: Icons.water_drop_rounded,
      iconColor: fuel.color,
      // "Gazole" est plus long que les autres codes (SP95, E10, ...).
      label: fuel == FuelType.gazole ? 'Carburant' : fuel.code,
      onTap: () => _pickFuel(context, ref),
    );
  }

  static void _pickFuel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carburant', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in FuelType.values)
                    ChoiceChip(
                      label: Text(f.code),
                      selected: f == ref.read(selectedFuelProvider),
                      onSelected: (_) {
                        ref.read(selectedFuelProvider.notifier).state = f;
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandChip extends ConsumerWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandKey = ref.watch(selectedBrandProvider);
    final brand = brandKey == null ? null : brandForKey(brandKey);

    return _Pill(
      selected: brand != null,
      icon: Icons.storefront_rounded,
      iconColor: _FilterColors.enseigne,
      label: brand?.name ?? 'Enseigne',
      trailing: brand != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(selectedBrandProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickBrand(context, ref),
      onLongPress: () => ref.read(selectedBrandProvider.notifier).state = null,
    );
  }

  /// Brands of the filtered stations, split into those on screen (with
  /// their on-screen count) and the others (with their nationwide count),
  /// each most common first. Off-screen brands stay pickable: the user
  /// just has to zoom out to see them.
  ///
  /// Only brands with a logo in `assets/logos/` are offered: the others
  /// (small independents, one-off names from OpenStreetMap) made a long,
  /// noisy list of initials.
  static ({List<(FuelBrand, int)> visible, List<(FuelBrand, int)> elsewhere})
  _brandsByVisibility(WidgetRef ref, Set<String> logoAssets) {
    final brands =
        ref.read(stationBrandsProvider).valueOrNull ??
        const <String, FuelBrand>{};
    final bounds = ref.read(mapBoundsProvider);
    final visible = <FuelBrand, int>{};
    final total = <FuelBrand, int>{};
    for (final s in ref.read(filteredStationsProvider)) {
      final b = brands[s.id];
      if (b == null || !logoAssets.contains('assets/logos/${b.key}.png')) {
        continue;
      }
      total[b] = (total[b] ?? 0) + 1;
      if (bounds == null ||
          (s.lat >= bounds.south &&
              s.lat <= bounds.north &&
              s.lng >= bounds.west &&
              s.lng <= bounds.east)) {
        visible[b] = (visible[b] ?? 0) + 1;
      }
    }
    List<(FuelBrand, int)> sorted(Iterable<MapEntry<FuelBrand, int>> e) =>
        [for (final x in e) (x.key, x.value)]
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return (
      visible: sorted(visible.entries),
      elsewhere: sorted(
        total.entries.where((e) => !visible.containsKey(e.key)),
      ),
    );
  }

  static Future<void> _pickBrand(BuildContext context, WidgetRef ref) async {
    final Set<String> logoAssets;
    try {
      logoAssets = await ref.read(brandLogoAssetsProvider.future);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    final (:visible, :elsewhere) = _brandsByVisibility(ref, logoAssets);
    final selected = ref.read(selectedBrandProvider);
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );

    Widget chips(List<(FuelBrand, int)> list, BuildContext context) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (b, count) in list)
          ChoiceChip(
            avatar: BrandLogo(brand: b, size: 22),
            label: Text('${b.name} ($count)'),
            selected: b.key == selected,
            onSelected: (_) {
              ref.read(selectedBrandProvider.notifier).state = b.key;
              Navigator.of(context).pop();
            },
          ),
      ],
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enseignes visibles ici',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text("Enseignes d'après OpenStreetMap.", style: muted),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucune enseigne connue sur cette zone.'),
                  )
                else
                  chips(visible, context),
                if (elsewhere.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Autres enseignes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hors de la zone affichée : dézoomez pour les voir.',
                    style: muted,
                  ),
                  const SizedBox(height: 12),
                  chips(elsewhere, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutorouteChip extends ConsumerWidget {
  const _AutorouteChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highway = ref.watch(highwayFilterProvider);
    final label = highway == null || highway == kAnyHighway
        ? 'Autoroute'
        : highway;

    return _Pill(
      selected: highway != null,
      icon: Icons.route_rounded,
      iconColor: _FilterColors.autoroute,
      label: label,
      trailing: highway != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(highwayFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickHighway(context, ref),
    );
  }

  static void _pickHighway(BuildContext context, WidgetRef ref) {
    final highways = ref.read(autoroutesListProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Autoroute', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: ListView(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.route_rounded,
                        color: _FilterColors.autoroute,
                      ),
                      title: const Text('Toutes les autoroutes'),
                      onTap: () {
                        ref.read(highwayFilterProvider.notifier).state =
                            kAnyHighway;
                        Navigator.of(context).pop();
                      },
                    ),
                    if (highways.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Aucune autoroute trouvée.'),
                      )
                    else
                      for (final hw in highways)
                        ListTile(
                          dense: true,
                          title: Text(hw.code),
                          trailing: Text(
                            '${hw.count} stations',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () {
                            ref.read(highwayFilterProvider.notifier).state =
                                hw.code;
                            Navigator.of(context).pop();
                          },
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceChip extends ConsumerWidget {
  const _ServiceChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(selectedServiceProvider);
    return _Pill(
      selected: service != null,
      icon: Icons.room_service_rounded,
      iconColor: _FilterColors.service,
      label: service ?? 'Service',
      trailing: service != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(selectedServiceProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickService(context, ref),
    );
  }

  static void _pickService(BuildContext context, WidgetRef ref) {
    final stations = ref.read(stationsProvider).valueOrNull ?? const [];
    final services = stations.expand((s) => s.services).toSet().toList()
      ..sort();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service proposé',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (services.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun service référencé.'),
                )
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in services)
                          ChoiceChip(
                            label: Text(s),
                            selected: s == ref.read(selectedServiceProvider),
                            onSelected: (_) {
                              ref.read(selectedServiceProvider.notifier).state =
                                  s;
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesChip extends ConsumerWidget {
  const _FavoritesChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(favoritesOnlyProvider);
    return _Pill(
      selected: active,
      icon: Icons.star_rounded,
      iconColor: _FilterColors.favoris,
      label: 'Favoris',
      onTap: () => ref.read(favoritesOnlyProvider.notifier).state = !active,
    );
  }
}

class _DepartmentChip extends ConsumerWidget {
  const _DepartmentChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dep = ref.watch(departmentFilterProvider);
    final departmentsAsync = ref.watch(departmentsDataProvider);
    final label = dep == null
        ? 'Département'
        : (departmentsAsync.valueOrNull?[dep]?.name ?? dep);

    return _Pill(
      selected: dep != null,
      icon: Icons.map_rounded,
      iconColor: _FilterColors.departement,
      label: label,
      trailing: dep != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(departmentFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickDepartment(context, ref),
    );
  }

  static void _pickDepartment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DepartmentPickerSheet(ref: ref),
    );
  }
}

class _DepartmentPickerSheet extends ConsumerStatefulWidget {
  const _DepartmentPickerSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_DepartmentPickerSheet> createState() =>
      _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState
    extends ConsumerState<_DepartmentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentsDataProvider);
    final departments = departmentsAsync.valueOrNull?.values.toList() ?? [];
    departments.sort((a, b) => a.name.compareTo(b.name));
    final filtered = _query.isEmpty
        ? departments
        : departments
              .where(
                (d) =>
                    d.name.toLowerCase().contains(_query.toLowerCase()) ||
                    d.num.contains(_query),
              )
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Département',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un département…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final dep = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text('${dep.num} · ${dep.name}'),
                      onTap: () {
                        widget.ref
                                .read(departmentFilterProvider.notifier)
                                .state =
                            dep.num;
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlugTypeChip extends ConsumerWidget {
  const _PlugTypeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugType = ref.watch(plugTypeFilterProvider);
    return _Pill(
      selected: plugType != null,
      icon: Icons.power_rounded,
      iconColor: _FilterColors.plugType,
      label: plugType ?? 'Connecteur',
      trailing: plugType != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(plugTypeFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickPlugType(context, ref),
    );
  }

  static void _pickPlugType(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ChoiceSheet(
        title: 'Connecteur',
        children: [
          for (final type in evPlugFields.keys)
            ChoiceChip(
              label: Text(type),
              selected: type == ref.read(plugTypeFilterProvider),
              onSelected: (_) {
                ref.read(plugTypeFilterProvider.notifier).state = type;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _EvPowerChip extends ConsumerWidget {
  const _EvPowerChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minPower = ref.watch(evMinPowerProvider);
    return _Pill(
      selected: minPower != null,
      icon: Icons.bolt_rounded,
      iconColor: _FilterColors.power,
      label: minPower == null ? 'Puissance' : '$minPower kW et +',
      trailing: minPower != null
          ? GestureDetector(
              onTap: () => ref.read(evMinPowerProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickPower(context, ref),
    );
  }

  static void _pickPower(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ChoiceSheet(
        title: 'Puissance minimale',
        children: [
          for (final kw in evPowerSteps)
            ChoiceChip(
              label: Text('$kw kW'),
              selected: kw == ref.read(evMinPowerProvider),
              onSelected: (_) {
                ref.read(evMinPowerProvider.notifier).state = kw;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

/// A bottom sheet of choice chips under a title.
class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      ),
    );
  }
}

class _EvOperatorChip extends ConsumerWidget {
  const _EvOperatorChip();

  /// Longest operator name shown whole in the chip.
  static const _maxLabel = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(evOperatorFilterProvider);
    final name = selected?.name;
    return _Pill(
      selected: selected != null,
      icon: Icons.apartment_rounded,
      iconColor: _FilterColors.evOperator,
      label: name == null
          ? 'Opérateur'
          : name.length <= _maxLabel
          ? name
          : '${name.substring(0, _maxLabel - 1).trimRight()}…',
      trailing: selected != null
          ? GestureDetector(
              onTap: () =>
                  ref.read(evOperatorFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickOperator(context),
    );
  }

  static void _pickOperator(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _OperatorPickerSheet(),
    );
  }
}

/// Every operator in France, the largest first, with a search field: there
/// are several hundred.
class _OperatorPickerSheet extends ConsumerStatefulWidget {
  const _OperatorPickerSheet();

  @override
  ConsumerState<_OperatorPickerSheet> createState() =>
      _OperatorPickerSheetState();
}

class _OperatorPickerSheetState extends ConsumerState<_OperatorPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(evOperatorsProvider);
    final selected = ref.watch(evOperatorFilterProvider);
    final favorites = ref.watch(favoriteEvOperatorsProvider.notifier);
    ref.watch(favoriteEvOperatorsProvider);
    final query = _query.trim().toLowerCase();
    final matching = [
      for (final o in operatorsAsync.valueOrNull ?? const <EvOperator>[])
        if (query.isEmpty || o.name.toLowerCase().contains(query)) o,
    ];
    // Les favoris d'abord, chacun dans l'ordre de la liste (les plus gros
    // en premier).
    final operators = [
      ...matching.where(favorites.isFavorite),
      ...matching.where((o) => !favorites.isFavorite(o)),
    ];
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.55);

    final Widget body;
    if (operatorsAsync.isLoading) {
      body = const Center(
        child: LoadingBar(label: 'Chargement des opérateurs…'),
      );
    } else if (operatorsAsync.hasError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impossible de charger les opérateurs.',
              style: TextStyle(color: muted),
            ),
            TextButton.icon(
              onPressed: () => ref.invalidate(evOperatorsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    } else if (operators.isEmpty) {
      body = Center(
        child: Text(
          'Aucun opérateur ne correspond.',
          style: TextStyle(color: muted),
        ),
      );
    } else {
      body = ListView.builder(
        itemCount: operators.length,
        itemBuilder: (context, index) {
          final o = operators[index];
          final favorite = favorites.isFavorite(o);
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(right: 16),
            leading: IconButton(
              tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: favorite ? const Color(0xFFFFB300) : muted,
              ),
              onPressed: () => favorites.toggle(o),
            ),
            title: Text(o.name),
            subtitle: Text(
              o.pointCount == 1
                  ? '1 point de charge'
                  : '${o.pointCount} points de charge',
            ),
            trailing: o.name == selected?.name
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () {
              ref.read(evOperatorFilterProvider.notifier).state = o;
              Navigator.of(context).pop();
            },
          );
        },
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opérateur', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un opérateur…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip on the black top bar: unselected reads white-on-translucent so
/// it stays legible on black, selected inverts to white-on-black so the
/// active state pops without introducing any color.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.trailing,
    this.onLongPress,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// Tints just the icon so it reads as a small colored "logo" for the
  /// filter, while the pill itself and its label stay black/white.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.primary;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(19)),
        boxShadow: _chipShadow,
      ),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: iconColor ?? fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  IconTheme(
                    data: IconThemeData(color: fg),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ombre des pastilles de filtre, plus discrète que celle des boutons de la
/// carte : elles sont nombreuses et côte à côte.
const _chipShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3)),
];
