import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/ev_station.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../data/services/geocoding_service.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/derived_providers.dart';
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

/// Below this zoom level the map is showing a wide area (region/country),
/// where dozens of full price totems would just overlap into noise — show
/// compact colored dots instead, and switch to full totems once zoomed in
/// enough to tell individual stations apart.
const _detailZoomThreshold = 12.0;

/// How far past the visible viewport (as a fraction of its span) to keep
/// building station markers, so panning doesn't cause markers to pop in.
const _viewportPadding = 0.3;

enum _ViewMode { map, list }

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
  _ViewMode _viewMode = _ViewMode.map;

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
      ref.read(mapZoomProvider.notifier).state = camera.zoom;
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == _ViewMode.map ? _ViewMode.list : _ViewMode.map;
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
            viewMode: _viewMode,
            onQueryChanged: _onQueryChanged,
            onClearSearch: _clearSearch,
            onSelectResult: _selectResult,
            onLocate: _locateMe,
            onAccount: () => context.push('/compte'),
            onToggleViewMode: _toggleViewMode,
          ),
          Expanded(
            child: Stack(
              children: [
                if (_viewMode == _ViewMode.map)
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
                  )
                else
                  const _MapListView(),
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
    required this.viewMode,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onSelectResult,
    required this.onLocate,
    required this.onAccount,
    required this.onToggleViewMode,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool searching;
  final List<_SearchHit> results;
  final bool locationLoading;
  final _ViewMode viewMode;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_SearchHit> onSelectResult;
  final VoidCallback onLocate;
  final VoidCallback onAccount;
  final VoidCallback onToggleViewMode;

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
                    icon: viewMode == _ViewMode.map
                        ? Icons.view_list_rounded
                        : Icons.map_rounded,
                    onTap: onToggleViewMode,
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
    var stations = ref.watch(filteredStationsProvider);
    final fuel = ref.watch(selectedFuelProvider);
    final favoriteIds =
        ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final brandEnabled = ref.watch(brandFilterEnabledProvider);
    final selectedBrand = ref.watch(selectedBrandProvider);
    final bounds = ref.watch(mapBoundsProvider);
    final zoom = ref.watch(mapZoomProvider);

    // Only build markers for stations near the visible viewport (plus a
    // padding margin): with the full national dataset otherwise reclustered
    // on every pan, this is what keeps panning/zooming smooth.
    if (bounds != null) {
      final padded = bounds.expanded(_viewportPadding);
      stations = stations
          .where(
            (s) =>
                s.lat >= padded.south &&
                s.lat <= padded.north &&
                s.lng >= padded.west &&
                s.lng <= padded.east,
          )
          .toList();
    }

    var brandByStation = const <String, String>{};
    if (brandEnabled && bounds != null) {
      brandByStation = ref.watch(stationBrandMatchesProvider);
      if (selectedBrand != null) {
        stations = stations
            .where((s) => brandByStation[s.id] == selectedBrand)
            .toList();
      }
    }

    // Zoomed out over a region/the whole country: full price totems would
    // just overlap into noise, so show compact dots until the user zooms in
    // enough to make out individual stations.
    final showDetail = zoom == null || zoom >= _detailZoomThreshold;

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(40, 40),
        markers: [
          for (final station in stations)
            Marker(
              point: ll.LatLng(station.lat, station.lng),
              width: showDetail ? 92 : 22,
              height: showDetail ? 44 : 22,
              child: showDetail
                  ? _StationMarker(
                      station: station,
                      fuel: fuel,
                      brand: brandByStation[station.id],
                      isFavorite: favoriteIds.contains(station.id),
                      onTap: () => showStationSheet(context, station),
                    )
                  : _StationDot(
                      color: fuel.color,
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
    final evStations = ref.watch(filteredEvStationsProvider);

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

/// Compact stand-in for [_StationMarker] shown when the map is zoomed out
/// too far for full price totems to be legible — just enough color to spot
/// clusters of stations without the visual noise of dozens of totems.
class _StationDot extends StatelessWidget {
  const _StationDot({
    required this.color,
    required this.isFavorite,
    required this.onTap,
  });

  final Color color;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isFavorite ? AppColors.accent : Colors.white,
            width: 2,
          ),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
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

/// The list alternative to the map, for when there are too many stations on
/// screen to make sense of visually — sorted cheapest-first (or, for
/// chargers, most powerful first) instead of spatially.
class _MapListView extends ConsumerWidget {
  const _MapListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(mapLayerProvider);
    return layer == MapLayer.bornes
        ? const _EvListView()
        : const _StationListView();
  }
}

class _StationListView extends ConsumerWidget {
  const _StationListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(filteredStationsProvider);
    final fuel = ref.watch(selectedFuelProvider);
    final favoriteIds =
        ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final position = ref.watch(userLocationProvider).valueOrNull;

    final sorted = [...stations]..sort((a, b) {
      final priceA = a.prices[fuel.code];
      final priceB = b.prices[fuel.code];
      if (priceA == null && priceB == null) return 0;
      if (priceA == null) return 1;
      if (priceB == null) return -1;
      return priceA.compareTo(priceB);
    });

    if (sorted.isEmpty) {
      return const _EmptyListState(
        message: 'Aucune station ne correspond à ces filtres.',
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final station = sorted[index];
          final distanceKm = position != null
              ? station.distanceKmTo(position.latitude, position.longitude)
              : null;
          return _StationListTile(
            station: station,
            fuel: fuel,
            distanceKm: distanceKm,
            isFavorite: favoriteIds.contains(station.id),
            onTap: () => showStationSheet(context, station),
          );
        },
      ),
    );
  }
}

class _EvListView extends ConsumerWidget {
  const _EvListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evStations = ref.watch(filteredEvStationsProvider);
    final position = ref.watch(userLocationProvider).valueOrNull;

    final sorted = [...evStations];
    if (position != null) {
      sorted.sort((a, b) {
        final distA = a.distanceKmTo(position.latitude, position.longitude);
        final distB = b.distanceKmTo(position.latitude, position.longitude);
        return distA.compareTo(distB);
      });
    } else {
      sorted.sort((a, b) => b.maxPowerKw.compareTo(a.maxPowerKw));
    }

    if (sorted.isEmpty) {
      return const _EmptyListState(
        message: 'Aucune borne ne correspond à ces filtres sur cette zone.',
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ev = sorted[index];
          final distanceKm = position != null
              ? ev.distanceKmTo(position.latitude, position.longitude)
              : null;
          return _EvListTile(
            station: ev,
            distanceKm: distanceKm,
            onTap: () => showEvStationSheet(context, ev),
          );
        },
      ),
    );
  }
}

class _StationListTile extends StatelessWidget {
  const _StationListTile({
    required this.station,
    required this.fuel,
    required this.distanceKm,
    required this.isFavorite,
    required this.onTap,
  });

  final Station station;
  final FuelType fuel;
  final double? distanceKm;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PriceTotem(price: station.prices[fuel.code], accentColor: fuel.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.ville,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.adresse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtleColor),
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatDistance(distanceKm!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isFavorite)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.star_rounded, color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvListTile extends StatelessWidget {
  const _EvListTile({
    required this.station,
    required this.distanceKm,
    required this.onTap,
  });

  final EvStation station;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F8F5B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${station.network} · ${station.maxPowerKw.toStringAsFixed(0)} kW',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtleColor),
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatDistance(distanceKm!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (station.free)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.money_off_rounded, color: Color(0xFF43A047)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListState extends StatelessWidget {
  const _EmptyListState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
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
