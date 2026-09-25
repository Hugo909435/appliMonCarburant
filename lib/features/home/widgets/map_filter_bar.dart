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
/// vs. EV chargers, then (for fuel stations) fuel type, brand, motorway and
/// favorites-only refinements.
class MapFilterBar extends ConsumerWidget {
  const MapFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(mapLayerProvider);

    // Posée entre la loupe et le compte : sa hauteur garde de la place pour
    // l'ombre des pastilles, que la liste rognerait sinon, et un fondu sur
    // chaque bord montre qu'elle défile au lieu de la trancher net.
    return SizedBox(
      height: 60,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.04, 0.94, 1],
        ).createShader(bounds),
        child: ScrollConfiguration(
          behavior: _DragScrollBehavior(),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 11, 12, 11),
            children: [
              if (layer == null) ...[
                // Nothing picked yet: show full labels as a clear call to
                // action, instead of two unlabeled logos with no context.
                _Pill(
                  selected: false,
                  icon: Icons.local_gas_station_rounded,
                  iconColor: _FilterColors.stations,
                  label: 'Stations',
                  onTap: () => ref.read(mapLayerProvider.notifier).state =
                      MapLayer.stations,
                ),
                const SizedBox(width: 8),
                _Pill(
                  selected: false,
                  icon: Icons.ev_station_rounded,
                  iconColor: _FilterColors.bornes,
                  label: 'Bornes électriques',
                  onTap: () => ref.read(mapLayerProvider.notifier).state =
                      MapLayer.bornes,
                ),
              ] else ...[
                _LogoBadge(
                  icon: Icons.local_gas_station_rounded,
                  color: _FilterColors.stations,
                  selected: layer == MapLayer.stations,
                  tooltip: 'Stations',
                  onTap: () => ref.read(mapLayerProvider.notifier).state =
                      MapLayer.stations,
                ),
                const SizedBox(width: 8),
                _LogoBadge(
                  icon: Icons.ev_station_rounded,
                  color: _FilterColors.bornes,
                  selected: layer == MapLayer.bornes,
                  tooltip: 'Bornes électriques',
                  tintIcon: true,
                  fillWithColor: true,
                  onTap: () => ref.read(mapLayerProvider.notifier).state =
                      MapLayer.bornes,
                ),
              ],
              if (layer == MapLayer.stations) ...[
                const SizedBox(width: 14),
                const _FuelChip(),
                const SizedBox(width: 8),
                const _BrandChip(),
                const SizedBox(width: 8),
                const _DepartmentChip(),
                const SizedBox(width: 8),
                const _AutorouteChip(),
                const SizedBox(width: 8),
                const _ServiceChip(),
                const SizedBox(width: 8),
                const _FavoritesChip(),
              ],
              if (layer == MapLayer.bornes) ...[
                const SizedBox(width: 14),
                const _PlugTypeChip(),
                const SizedBox(width: 8),
                const _EvOperatorChip(),
                const SizedBox(width: 8),
                const _EvPowerChip(),
              ],
            ],
          ),
        ),
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

/// A round "logo" badge — used for the always-icon-only filters (map
/// layer). Selected = filled navy, unselected = white, so the row stays
/// compact without ever showing a label.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.tooltip,
    this.tintIcon = false,
    this.fillWithColor = false,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  /// When true, the icon itself is always tinted with [color] (like the
  /// other filters' logos), instead of staying black until selected.
  final bool tintIcon;

  /// When true, the badge fills with [color] once selected, instead of the
  /// app's navy.
  final bool fillWithColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (fillWithColor ? color : AppColors.primary)
                : Colors.white,
            shape: BoxShape.circle,
            boxShadow: _chipShadow,
          ),
          child: Icon(
            icon,
            color: selected
                ? Colors.white
                : (tintIcon ? color : AppColors.primary),
            size: 18,
          ),
        ),
      ),
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

  void _pickFuel(BuildContext context, WidgetRef ref) {
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
  ({List<(FuelBrand, int)> visible, List<(FuelBrand, int)> elsewhere})
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

  Future<void> _pickBrand(BuildContext context, WidgetRef ref) async {
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

  void _pickHighway(BuildContext context, WidgetRef ref) {
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

  void _pickService(BuildContext context, WidgetRef ref) {
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

  void _pickDepartment(BuildContext context, WidgetRef ref) {
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

  void _pickPlugType(BuildContext context, WidgetRef ref) {
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

  void _pickPower(BuildContext context, WidgetRef ref) {
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
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _OperatorPickerSheet(),
      ),
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
