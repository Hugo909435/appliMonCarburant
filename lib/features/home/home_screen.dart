import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../data/models/ev_station.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/osm_brand_service.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/ev_stations_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/map_viewport_provider.dart';
import '../../providers/station_brands_provider.dart';
import '../../providers/stations_provider.dart';
import '../../shared/widgets/brand_badge.dart';
import '../../shared/widgets/price_totem.dart';
import '../../shared/widgets/station_sheet.dart';
import 'widgets/ev_station_sheet.dart';
import 'widgets/map_filter_bar.dart';

enum _SearchKind { station, address }

class _SearchHit {
  const _SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  final _SearchKind kind;
  final String title;
  final String subtitle;
  final double lat;
  final double lng;
}

/// Home is the map: it's the fastest way to answer "where's the cheapest
/// fuel/charger near me", so there's no separate landing page above it.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const _franceCenter = ll.LatLng(46.6, 2.5);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _geocodingService = GeocodingService();

  Timer? _searchDebounce;
  Timer? _boundsDebounce;
  int _searchToken = 0;
  List<_SearchHit> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _boundsDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<Station> _matchStations(List<Station> stations, String query) {
    final q = query.trim().toLowerCase();
    final isPostal = RegExp(r'^\d{2,5}$').hasMatch(q);
    if (isPostal) {
      return stations.where((s) => s.cp.startsWith(q)).take(5).toList();
    }
    return stations
        .where(
          (s) =>
              s.ville.toLowerCase().contains(q) ||
              s.adresse.toLowerCase().contains(q),
        )
        .take(5)
        .toList();
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final stations =
        ref.read(stationsProvider).valueOrNull ?? const <Station>[];
    final stationResults = _matchStations(stations, query)
        .map(
          (s) => _SearchHit(
            kind: _SearchKind.station,
            title: s.ville,
            subtitle: s.adresse,
            lat: s.lat,
            lng: s.lng,
          ),
        )
        .toList();

    setState(() {
      _results = stationResults;
      _searching = true;
    });

    List<GeocodingResult> addresses;
    try {
      addresses = await _geocodingService.search(query);
    } catch (_) {
      addresses = const [];
    }
    if (!mounted || token != _searchToken) return;

    setState(() {
      _results = [
        ...stationResults,
        ...addresses.map(
          (a) => _SearchHit(
            kind: _SearchKind.address,
            title: a.label.split(',').first,
            subtitle: a.label,
            lat: a.lat,
            lng: a.lng,
          ),
        ),
      ];
      _searching = false;
    });
  }

  void _selectResult(_SearchHit result) {
    _searchController.text = result.title;
    _searchFocus.unfocus();
    setState(() => _results = []);
    _mapController.move(ll.LatLng(result.lat, result.lng), 15);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _results = [];
      _searching = false;
    });
  }

  void _dismissResults() {
    if (_results.isEmpty && !_searchFocus.hasFocus) return;
    _searchFocus.unfocus();
    setState(() => _results = []);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final bounds = camera.visibleBounds;
      ref.read(mapBoundsProvider.notifier).state = MapBounds(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      );
    });
  }

  Future<void> _locateMe() async {
    await ref.read(userLocationProvider.notifier).requestLocation();
    if (!mounted) return;
    final result = ref.read(userLocationProvider);
    result.when(
      data: (position) {
        if (position == null) return;
        _mapController.move(
          ll.LatLng(position.latitude, position.longitude),
          14,
        );
      },
      error: (err, _) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString()))),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final layer = ref.watch(mapLayerProvider);
    final position = ref.watch(userLocationProvider).valueOrNull;
    final locationLoading = ref.watch(
      userLocationProvider.select((v) => v.isLoading),
    );
    final comparisonCount = ref.watch(
      comparisonProvider.select((ids) => ids.length),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _TopBar(
            searchController: _searchController,
            searchFocus: _searchFocus,
            searching: _searching,
            results: _results,
            locationLoading: locationLoading,
            onQueryChanged: _onQueryChanged,
            onClearSearch: _clearSearch,
            onSelectResult: _selectResult,
            onLocate: _locateMe,
            onAccount: () => context.push('/compte'),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: position != null
                        ? ll.LatLng(position.latitude, position.longitude)
                        : HomeScreen._franceCenter,
                    initialZoom: position != null ? 12 : 5.5,
                    onTap: (_, _) => _dismissResults(),
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.moncarburant.mon_carburant_app',
                    ),
                    if (layer == MapLayer.stations)
                      const _StationMarkersLayer()
                    else if (layer == MapLayer.bornes)
                      const _EvMarkersLayer(),
                    if (position != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ll.LatLng(
                              position.latitude,
                              position.longitude,
                            ),
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        const TextSourceAttribution(
                          '© OpenStreetMap contributors',
                        ),
                        if (layer == MapLayer.bornes)
                          const TextSourceAttribution('IRVE · data.gouv.fr'),
                      ],
                    ),
                  ],
                ),
                if (comparisonCount > 0)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'compare-fab',
                      backgroundColor: Colors.black,
                      onPressed: () => context.push('/comparer'),
                      icon: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Text(
                          '$comparisonCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      label: const Text('Comparer'),
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

/// Fixed black header above the map: search, locate-me, account, then the
/// filter row — deliberately not floating over the map tiles.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.searchFocus,
    required this.searching,
    required this.results,
    required this.locationLoading,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onSelectResult,
    required this.onLocate,
    required this.onAccount,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool searching;
  final List<_SearchHit> results;
  final bool locationLoading;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_SearchHit> onSelectResult;
  final VoidCallback onLocate;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: searchController,
                      focusNode: searchFocus,
                      searching: searching,
                      onChanged: onQueryChanged,
                      onClear: onClearSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    icon: Icons.my_location_rounded,
                    loading: locationLoading,
                    onTap: onLocate,
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    icon: Icons.person_rounded,
                    onTap: onAccount,
                  ),
                ],
              ),
              if (results.isNotEmpty)
                _SearchResultsList(results: results, onSelect: onSelectResult),
              const SizedBox(height: 10),
              const MapFilterBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationMarkersLayer extends ConsumerWidget {
  const _StationMarkersLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allStations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final fuel = ref.watch(selectedFuelProvider);
    final autorouteOnly = ref.watch(autorouteOnlyProvider);
    final dep = ref.watch(departmentFilterProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final favoriteIds =
        ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final brandEnabled = ref.watch(brandFilterEnabledProvider);
    final selectedBrand = ref.watch(selectedBrandProvider);
    final bounds = ref.watch(mapBoundsProvider);

    var stations = allStations
        .where((s) => s.prices.containsKey(fuel.code))
        .toList();
    if (autorouteOnly) stations = stations.where((s) => s.isAutoroute).toList();
    if (dep != null) stations = stations.where((s) => s.dep == dep).toList();
    if (favoritesOnly) {
      stations = stations.where((s) => favoriteIds.contains(s.id)).toList();
    }

    final brandByStation = <String, String>{};
    if (brandEnabled && bounds != null) {
      stations = stations
          .where(
            (s) =>
                s.lat >= bounds.south &&
                s.lat <= bounds.north &&
                s.lng >= bounds.west &&
                s.lng <= bounds.east,
          )
          .toList();
      final brands = ref.watch(stationBrandsProvider).valueOrNull ?? const [];
      for (final s in stations) {
        OsmFuelBrand? nearest;
        var best = double.infinity;
        for (final b in brands) {
          final d = s.distanceKmTo(b.lat, b.lng);
          if (d < best) {
            best = d;
            nearest = b;
          }
        }
        if (nearest != null && best <= 0.07) brandByStation[s.id] = nearest.brand;
      }
      if (selectedBrand != null) {
        stations = stations
            .where((s) => brandByStation[s.id] == selectedBrand)
            .toList();
      }
    }

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(40, 40),
        markers: [
          for (final station in stations)
            Marker(
              point: ll.LatLng(station.lat, station.lng),
              width: 92,
              height: 44,
              child: _StationMarker(
                station: station,
                fuel: fuel,
                brand: brandByStation[station.id],
                isFavorite: favoriteIds.contains(station.id),
                onTap: () => showStationSheet(context, station),
              ),
            ),
        ],
        builder: (context, markers) => CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            '${markers.length}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _EvMarkersLayer extends ConsumerWidget {
  const _EvMarkersLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evAsync = ref.watch(evStationsProvider);
    final evStations = evAsync.valueOrNull ?? const <EvStation>[];

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(40, 40),
        markers: [
          for (final ev in evStations)
            Marker(
              point: ll.LatLng(ev.lat, ev.lng),
              width: 44,
              height: 44,
              child: _EvMarker(
                station: ev,
                onTap: () => showEvStationSheet(context, ev),
              ),
            ),
        ],
        builder: (context, markers) => CircleAvatar(
          backgroundColor: const Color(0xFF2F8F5B),
          child: Text(
            '${markers.length}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({
    required this.station,
    required this.fuel,
    required this.brand,
    required this.isFavorite,
    required this.onTap,
  });

  final Station station;
  final FuelType fuel;
  final String? brand;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          PriceTotem(
            price: station.prices[fuel.code],
            accentColor: fuel.color,
            size: PriceTotemSize.compact,
          ),
          if (brand != null)
            Positioned(
              top: -6,
              right: 4,
              child: BrandBadge(brand: brand!, size: 16),
            ),
          if (isFavorite)
            const Positioned(
              bottom: -4,
              left: 4,
              child: Icon(
                Icons.star_rounded,
                size: 14,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

class _EvMarker extends StatelessWidget {
  const _EvMarker({required this.station, required this.onTap});

  final EvStation station;
  final VoidCallback onTap;

  Color get _powerColor {
    if (station.maxPowerKw >= 100) return const Color(0xFFD81B60);
    if (station.maxPowerKw >= 22) return const Color(0xFFFB8C00);
    return const Color(0xFF2F8F5B);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _powerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      color: Colors.white,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Adresse, ville ou code postal…',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: onClear,
                        ),
                ),
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onSelect});

  final List<_SearchHit> results;
  final ValueChanged<_SearchHit> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: Theme.of(context).colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              final isStation = result.kind == _SearchKind.station;
              return ListTile(
                leading: Icon(
                  isStation
                      ? Icons.local_gas_station_rounded
                      : Icons.place_outlined,
                  color: AppColors.accent,
                ),
                title: Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  result.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelect(result),
              );
            },
          ),
        ),
      ),
    );
  }
}
