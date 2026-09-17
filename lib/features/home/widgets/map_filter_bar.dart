import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fuel_colors.dart';
import '../../../data/models/fuel_type.dart';
import '../../../providers/derived_providers.dart';
import '../../../providers/ev_stations_provider.dart';
import '../../../providers/filters_provider.dart';
import '../../../providers/station_brands_provider.dart';
import '../../../providers/stations_provider.dart';

/// Each filter's icon gets its own fixed color so it reads as a small
/// "logo" at a glance — the chips themselves stay black/white.
class _FilterColors {
  static const stations = Color(0xFFE87722);
  static const bornes = Color(0xFF2F8F5B);
  static const enseigne = Color(0xFF8E24AA);
  static const autoroute = Color(0xFF1E88E5);
  static const departement = Color(0xFF00897B);
  static const favoris = Color(0xFFFFB300);
  static const plugType = Color(0xFF1E6FA8);
  static const fastCharge = Color(0xFFFFA000);
  static const evFree = Color(0xFF43A047);
  static const evNetwork = Color(0xFF8E24AA);
}

/// The horizontal filter row floating under the search bar: fuel stations
/// vs. EV chargers, then (for fuel stations) fuel type, brand, motorway and
/// favorites-only refinements.
class MapFilterBar extends ConsumerWidget {
  const MapFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(mapLayerProvider);

    return SizedBox(
      height: 38,
      child: ScrollConfiguration(
        behavior: _DragScrollBehavior(),
        child: ListView(
          scrollDirection: Axis.horizontal,
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
                onTap: () => ref.read(mapLayerProvider.notifier).state =
                    MapLayer.bornes,
              ),
            ],
            if (layer == MapLayer.stations) ...[
              const SizedBox(width: 12),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 12),
              const _FuelChip(),
              const SizedBox(width: 8),
              const _BrandChip(),
              const SizedBox(width: 8),
              const _DepartmentChip(),
              const SizedBox(width: 8),
              const _AutorouteChip(),
              const SizedBox(width: 8),
              const _FavoritesChip(),
            ],
            if (layer == MapLayer.bornes) ...[
              const SizedBox(width: 12),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 12),
              const _PlugTypeChip(),
              const SizedBox(width: 8),
              const _EvNetworkChip(),
              const SizedBox(width: 8),
              const _FastChargeChip(),
              const SizedBox(width: 8),
              const _EvFreeChip(),
            ],
          ],
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

/// A round "logo" badge: black icon on white, ringed in the filter's
/// color — used for the always-icon-only filters (map layer, fuel type).
/// Selected = solid ring, unselected = faint ring, so the row stays
/// compact without ever showing a label.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.tooltip,
    this.tintIcon = false,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  /// When true, the icon itself is always tinted with [color] (like the
  /// other filters' logos), instead of staying black until selected.
  final bool tintIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black,
              width: selected ? 2.5 : 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: selected || !tintIcon ? Colors.black : color,
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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
    final enabled = ref.watch(brandFilterEnabledProvider);
    final brand = ref.watch(selectedBrandProvider);

    return _Pill(
      selected: enabled,
      icon: Icons.storefront_rounded,
      iconColor: _FilterColors.enseigne,
      label: brand ?? 'Enseigne',
      trailing: brand != null
          ? GestureDetector(
              onTap: () => ref.read(selectedBrandProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () {
        if (!enabled) {
          ref.read(brandFilterEnabledProvider.notifier).state = true;
        }
        _pickBrand(context, ref);
      },
      onLongPress: () {
        ref.read(brandFilterEnabledProvider.notifier).state = false;
        ref.read(selectedBrandProvider.notifier).state = null;
      },
    );
  }

  void _pickBrand(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.read(stationBrandsProvider);
    final brands =
        (brandsAsync.valueOrNull ?? const []).map((b) => b.brand).toSet().toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enseigne visible ici', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'D\'après OpenStreetMap, sur la zone affichée.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 12),
              if (brands.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucune enseigne trouvée sur cette zone.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in brands)
                      ChoiceChip(
                        label: Text(b),
                        selected: b == ref.read(selectedBrandProvider),
                        onSelected: (_) {
                          ref.read(selectedBrandProvider.notifier).state = b;
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
              onTap: () => ref.read(highwayFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickHighway(context, ref),
    );
  }

  void _pickHighway(BuildContext context, WidgetRef ref) {
    final highways = ref.read(autoroutesListProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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
              onTap: () => ref.read(departmentFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickDepartment(context, ref),
    );
  }

  void _pickDepartment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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
              Text('Département', style: Theme.of(context).textTheme.titleMedium),
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
                        widget.ref.read(departmentFilterProvider.notifier).state =
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

/// The known plug types the IRVE feed distinguishes — fixed, unlike brands
/// or networks, so no need to derive them from the loaded data.
const _plugTypes = ['Type 2', 'Combo CCS', 'CHAdeMO', 'Type EF'];

class _PlugTypeChip extends ConsumerWidget {
  const _PlugTypeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugType = ref.watch(plugTypeFilterProvider);
    return _Pill(
      selected: plugType != null,
      icon: Icons.power_rounded,
      iconColor: _FilterColors.plugType,
      label: plugType ?? 'Prise',
      trailing: plugType != null
          ? GestureDetector(
              onTap: () => ref.read(plugTypeFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickPlugType(context, ref),
    );
  }

  void _pickPlugType(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type de prise', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _plugTypes)
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EvNetworkChip extends ConsumerWidget {
  const _EvNetworkChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(evNetworkFilterProvider);
    return _Pill(
      selected: network != null,
      icon: Icons.apartment_rounded,
      iconColor: _FilterColors.evNetwork,
      label: network ?? 'Réseau',
      trailing: network != null
          ? GestureDetector(
              onTap: () => ref.read(evNetworkFilterProvider.notifier).state = null,
              child: const Icon(Icons.close_rounded, size: 15),
            )
          : null,
      onTap: () => _pickNetwork(context, ref),
    );
  }

  void _pickNetwork(BuildContext context, WidgetRef ref) {
    final evStations = ref.read(evStationsProvider).valueOrNull ?? const [];
    final networks =
        evStations.map((e) => e.network).where((n) => n.isNotEmpty).toSet().toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Réseau visible ici', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'D\'après les bornes affichées sur la zone.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 12),
              if (networks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun réseau trouvé sur cette zone.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in networks)
                      ChoiceChip(
                        label: Text(n),
                        selected: n == ref.read(evNetworkFilterProvider),
                        onSelected: (_) {
                          ref.read(evNetworkFilterProvider.notifier).state = n;
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

class _FastChargeChip extends ConsumerWidget {
  const _FastChargeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(fastChargeOnlyProvider);
    return _Pill(
      selected: active,
      icon: Icons.bolt_rounded,
      iconColor: _FilterColors.fastCharge,
      label: 'Charge rapide',
      onTap: () =>
          ref.read(fastChargeOnlyProvider.notifier).state = !active,
    );
  }
}

class _EvFreeChip extends ConsumerWidget {
  const _EvFreeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(evFreeOnlyProvider);
    return _Pill(
      selected: active,
      icon: Icons.money_off_rounded,
      iconColor: _FilterColors.evFree,
      label: 'Gratuit',
      onTap: () => ref.read(evFreeOnlyProvider.notifier).state = !active,
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
    final fg = selected ? Colors.black : Colors.white;
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
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
                IconTheme(data: IconThemeData(color: fg), child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
