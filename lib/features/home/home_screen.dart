import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../core/brands/brand_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../data/models/ev_station.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../providers/map_search_provider.dart';
import '../../providers/comparison_provider.dart';
import '../../providers/derived_providers.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/map_viewport_provider.dart';
import '../../providers/station_brands_provider.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/price_totem.dart';
import '../../shared/widgets/promo_banner.dart';
import '../../shared/widgets/station_sheet.dart';
import '../../core/config/app_config.dart';
import 'widgets/ev_station_sheet.dart';
import 'widgets/ev_station_tile.dart';
import 'widgets/map_filter_bar.dart';
import 'widgets/stations_sheet.dart';
import 'widgets/sync_indicator.dart';

/// Below this zoom level the map is showing a wide area (region/country),
/// where dozens of full price totems would just overlap into noise — show
/// compact colored dots instead, and switch to full totems once zoomed in
/// enough to tell individual stations apart.
const _detailZoomThreshold = 12.0;

/// How far past the visible viewport (as a fraction of its span) to keep
/// building station markers, so panning doesn't cause markers to pop in.
const _viewportPadding = 0.3;

/// From this zoom level on (street level), the viewport holds few enough
/// stations to show every one of them, clustered where they overlap.
/// Below it, [_thinOut] keeps only one station per screen cell so the map
/// never builds more than a couple hundred markers, however far out it is.
const _thinningMaxZoom = 15.0;

/// Au-delà, même un filtre de zone garde l'écrémage de [_thinOut]. Le plus
/// gros département compte moins de 300 stations et l'ensemble des
/// autoroutes un peu plus de 400 : la marge couvre l'un comme l'autre.
const _maxZoneMarkers = 600;

/// Side, in screen pixels, of the grid cell holding at most one station
/// while thinning: about a marker's footprint, so the kept markers barely
/// overlap. Totems are wider than dots, hence the larger cell.
const _dotCellPx = 44.0;
const _totemCellPx = 88.0;

/// Même chose pour les bornes : le point de la vue large, puis le rond à
/// éclair (voir [_EvMarker]) sous [_detailZoomThreshold] et au-delà.
const _evDotCellPx = 24.0;
const _evIconCellPx = 44.0;

/// Diamètre de la pastille d'enseigne montrée sous [_detailZoomThreshold].
///
/// Le logo n'occupe que le carré inscrit dans le rond, anneau déduit : il est
/// donc dessiné à peine plus de 19 px de côté ici. C'est ce qui fixe le
/// diamètre — plus étroit, les logotypes larges comme celui d'Intermarché
/// repasseraient au badge coloré (voir [BrandLogo]).
const _dotSize = 32.0;

/// Épaisseur de l'anneau coloré autour de la pastille.
const _dotRingWidth = 2.0;

/// Boîte du marqueur compact : la pastille, plus la marge de son ombre.
const _dotMarkerSize = _dotSize + 4;

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

  /// Whether the search is unfolded from its magnifier button.
  final _searchExpanded = ValueNotifier<bool>(false);

  Timer? _boundsDebounce;

  /// How much of the map the stations list sheet covers, as a fraction.
  final _sheetExtent = ValueNotifier<double>(StationsSheet.initialFraction);

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _sheetExtent.dispose();
    _searchExpanded.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectResult(SearchHit result) {
    _searchController.text = result.title;
    _searchFocus.unfocus();
    ref.read(mapSearchProvider.notifier).clear();
    _mapController.move(ll.LatLng(result.lat, result.lng), 15);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    ref.read(mapSearchProvider.notifier).clear();
  }

  void _dismissResults() {
    // Toucher la carte replie une recherche restée vide.
    if (_searchController.text.isEmpty) _searchExpanded.value = false;
    if (ref.read(mapSearchProvider).isEmpty && !_searchFocus.hasFocus) return;
    _searchFocus.unfocus();
    ref.read(mapSearchProvider.notifier).clear();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _publishCamera(camera);
    });
  }

  void _publishCamera(MapCamera camera) {
    final bounds = camera.visibleBounds;
    ref.read(mapBoundsProvider.notifier).state = MapBounds(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );
    ref.read(mapZoomProvider.notifier).state = camera.zoom;
  }

  /// Recadre la carte sur les stations que laisse passer le filtre qui
  /// vient d'être choisi (un département, une autoroute), au lieu de laisser
  /// l'utilisateur les chercher sur une carte restée où elle était.
  void _fitToFilteredStations() {
    // Appelé depuis l'écoute du filtre, avant que la liste filtrée n'ait vu
    // le changement : la lire tout de suite rendrait encore toute la France.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitNow();
    });
  }

  void _fitNow() {
    final points = [
      for (final s in ref.read(filteredStationsProvider))
        // Coordonnées absentes du flux : un point au large de l'Afrique
        // ferait dézoomer sur tout le globe.
        if (s.lat != 0 || s.lng != 0) ll.LatLng(s.lat, s.lng),
    ];
    if (points.isEmpty) return;
    // Une seule station (ou toutes au même endroit) : pas de zoom infini.
    _fitVisibleArea(points, maxZoom: 14);
  }

  /// Centre la carte sur une station touchée dans la liste, assez près pour
  /// la voir avec son prix et ses voisines, au-dessus de la liste.
  void _focusOn(double lat, double lng) {
    _fitVisibleArea(
      [ll.LatLng(lat, lng)],
      maxZoom: _thinningMaxZoom,
      // La liste redescend à mi-hauteur au même moment (voir StationsSheet).
      sheetFraction: math.min(
        _sheetExtent.value,
        StationsSheet.initialFraction,
      ),
    );
  }

  /// Cadre [points] dans la partie de la carte que rien ne recouvre : sous
  /// la barre de filtres, au-dessus de la liste, à gauche des boutons.
  ///
  /// [sheetFraction] : part de l'écran que la liste couvrira. Par défaut, sa
  /// hauteur actuelle, plafonnée à la moitié : grande ouverte, on cadre pour
  /// la carte qu'on verra une fois la liste redescendue.
  void _fitVisibleArea(
    List<ll.LatLng> points, {
    required double maxZoom,
    double? sheetFraction,
  }) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final sheetArea = size.height - topInset - _searchRowHeight;
    final sheetHeight =
        (sheetFraction ?? math.min(_sheetExtent.value, 0.5)) * sheetArea;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: EdgeInsets.fromLTRB(
          32,
          topInset + _searchRowHeight + 16,
          // Les boutons flottants (favoris, trajet, position) occupent le
          // bord droit.
          80,
          sheetHeight + 24,
        ),
        maxZoom: maxZoom,
      ),
    );
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
      error: (err, _) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err.toString()))),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Seulement quand un filtre est posé : le retirer laisse la carte où
    // l'utilisateur l'a amenée.
    ref.listen(departmentFilterProvider, (previous, dep) {
      if (dep != null && dep != previous) _fitToFilteredStations();
    });
    ref.listen(highwayFilterProvider, (previous, highway) {
      if (highway != null && highway != previous) _fitToFilteredStations();
    });
    final layer = ref.watch(mapLayerProvider);
    final search = ref.watch(mapSearchProvider);
    final position = ref.watch(userLocationProvider).valueOrNull;
    final locationLoading = ref.watch(
      userLocationProvider.select((v) => v.isLoading),
    );
    final comparisonCount = ref.watch(
      comparisonProvider.select((ids) => ids.length),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    // La carte passe sous la barre d'état : ses icônes doivent rester
    // sombres, les tuiles étant claires quel que soit le thème.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
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
                // Publish the viewport as soon as the map is laid out: until
                // then the markers layer has no bounds to cull to and would
                // build every station in France.
                onMapReady: () => _publishCamera(_mapController.camera),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConfig.tileUrlTemplate,
                  userAgentPackageName: AppConfig.packageName,
                ),
                if (layer == MapLayer.stations)
                  const _StationMarkersLayer()
                else if (layer == MapLayer.bornes)
                  const _EvMarkersLayer(),
                if (position != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: ll.LatLng(position.latitude, position.longitude),
                        width: 22,
                        height: 22,
                        child: const _UserDot(),
                      ),
                    ],
                  ),
              ],
            ),
            // La liste s'arrête sous la ligne de recherche : ouverte en
            // grand, elle recouvre les filtres (qui s'effacent) mais jamais
            // la recherche ni le compte.
            Positioned.fill(
              top: topInset + _searchRowHeight,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _sheetExtent,
                      builder: (context, extent, child) {
                        final hidden = extent > 0.6;
                        return Positioned(
                          left: 12,
                          right: 12,
                          bottom: extent * constraints.maxHeight + 12,
                          child: IgnorePointer(
                            ignoring: hidden,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: hidden ? 0 : 1,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _BottomControls(
                        ev: layer == MapLayer.bornes,
                        showNearby: position != null,
                        comparisonCount: comparisonCount,
                        locationLoading: locationLoading,
                        onLocate: _locateMe,
                      ),
                    ),
                    StationsSheet(
                      availableHeight: constraints.maxHeight,
                      onFocus: _focusOn,
                      extent: _sheetExtent,
                      ev: layer == MapLayer.bornes,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Une seule ligne : loupe, filtres qui défilent entre les
                    // deux, compte. Dépliée, la recherche recouvre les filtres.
                    SizedBox(
                      height: _searchRowHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: _topButtonSize,
                                    ),
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: _searchExpanded,
                                      builder: (context, expanded, child) =>
                                          IgnorePointer(
                                            ignoring: expanded,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              opacity: expanded ? 0 : 1,
                                              child: child,
                                            ),
                                          ),
                                      child: const MapFilterBar(),
                                    ),
                                  ),
                                  _ExpandingSearch(
                                    expanded: _searchExpanded,
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    searching: search.searching,
                                    onChanged: ref
                                        .read(mapSearchProvider.notifier)
                                        .onQueryChanged,
                                    onClear: _clearSearch,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _MapButton(
                              icon: Icons.person_rounded,
                              tooltip: 'Compte',
                              size: _topButtonSize,
                              onTap: () => context.push('/compte'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SyncIndicator(),
                    if (search.results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _SearchResultsList(
                          results: search.results,
                          onSelect: _selectResult,
                        ),
                      ),
                    ValueListenableBuilder<double>(
                      valueListenable: _sheetExtent,
                      builder: (context, extent, child) {
                        final hidden =
                            search.results.isNotEmpty || extent > 0.6;
                        return IgnorePointer(
                          ignoring: hidden,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: hidden ? 0 : 1,
                            child: child,
                          ),
                        );
                      },
                      child: const PromoBanner(),
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

/// Hauteur de la ligne du haut (recherche, filtres, compte), marges
/// comprises : de quoi laisser passer l'ombre des pastilles.
const _searchRowHeight = 60.0;

/// Côté des boutons de la ligne du haut, aligné sur la hauteur des filtres.
const _topButtonSize = 40.0;

/// Ombre commune des commandes posées sur la carte : large et diffuse
/// plutôt qu'un liseré, pour qu'elles flottent sans alourdir.
const _floatingShadow = [
  BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 6)),
];

/// Les commandes du bas de la carte, juste au-dessus de la liste : à gauche
/// les raccourcis contextuels, à droite la colonne de navigation.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.ev,
    required this.showNearby,
    required this.comparisonCount,
    required this.locationLoading,
    required this.onLocate,
  });

  final bool ev;
  final bool showNearby;
  final int comparisonCount;
  final bool locationLoading;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comparisonCount > 0) ...[
                _MapPill(
                  onTap: () => context.push('/comparer'),
                  dark: true,
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white,
                    child: Text(
                      '$comparisonCount',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  label: 'Comparer',
                ),
                const SizedBox(height: 10),
              ],
              if (showNearby) ...[
                _MapPill(
                  onTap: () => context.push('/pres-de-moi'),
                  leading: const Icon(
                    Icons.savings_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: 'Le plus rentable autour de moi',
                ),
                const SizedBox(height: 10),
              ],
              _MapAttribution(ev: ev),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapButtonGroup(
              children: [
                _MapButton(
                  icon: Icons.star_rounded,
                  tooltip: 'Favoris',
                  flat: true,
                  onTap: () => context.push('/favoris'),
                ),
                _MapButton(
                  icon: Icons.alt_route_rounded,
                  tooltip: 'Trajet',
                  flat: true,
                  onTap: () => context.push('/trajet'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MapButton(
              icon: Icons.near_me_rounded,
              tooltip: 'Me localiser',
              loading: locationLoading,
              onTap: onLocate,
            ),
          ],
        ),
      ],
    );
  }
}

/// Position de l'utilisateur : un point bleu cerclé de blanc, à la manière
/// des applications de cartographie, plutôt qu'une icône de viseur.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x401A73E8), spreadRadius: 8),
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
    );
  }
}

class _StationMarkersLayer extends ConsumerWidget {
  const _StationMarkersLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stations = ref.watch(brandFilteredStationsProvider);
    final fuel = ref.watch(selectedFuelProvider);
    final favoriteIds =
        ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final brands =
        ref.watch(stationBrandsProvider).valueOrNull ??
        const <String, FuelBrand>{};
    final bounds = ref.watch(mapBoundsProvider);
    final zoom = ref.watch(mapZoomProvider);
    // Un département ou une autoroute choisi : l'utilisateur veut voir toutes
    // les stations de cette zone, pas seulement la moins chère de chaque case.
    final zoneFiltered =
        ref.watch(departmentFilterProvider) != null ||
        ref.watch(highwayFilterProvider) != null;

    // No viewport yet (map not laid out): building markers for the whole
    // national dataset here is what used to stall the first load.
    if (bounds == null || zoom == null) return const SizedBox.shrink();

    // Only build markers for stations near the visible viewport (plus a
    // padding margin).
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

    // Zoomed out over a region/the whole country: full price totems would
    // just overlap into noise, so show compact dots until the user zooms in
    // enough to make out individual stations.
    final showDetail = zoom >= _detailZoomThreshold;

    Marker markerFor(Station station) => Marker(
      point: ll.LatLng(station.lat, station.lng),
      width: showDetail ? 92 : _dotMarkerSize,
      height: showDetail ? 44 : _dotMarkerSize,
      child: showDetail
          ? _StationMarker(
              station: station,
              fuel: fuel,
              brand: brands[station.id],
              isFavorite: favoriteIds.contains(station.id),
              onTap: () => showStationSheet(context, station),
            )
          : _StationDot(
              color: fuel.color,
              brand: brands[station.id],
              isFavorite: favoriteIds.contains(station.id),
              onTap: () => showStationSheet(context, station),
            ),
    );

    final shown = markerStations(
      stations,
      zoom: zoom,
      zoneFiltered: zoneFiltered,
      fuelCode: fuel.code,
      favoriteIds: favoriteIds,
    );
    if (shown.mode == MarkerMode.plain) {
      return MarkerLayer(
        markers: [for (final s in shown.stations) markerFor(s)],
      );
    }

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(40, 40),
        markers: [for (final station in shown.stations) markerFor(station)],
        builder: (context, markers) => CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            '${markers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Comment [markerStations] dessine les stations qu'il retient.
enum MarkerMode {
  /// Chaque station à sa place, sans regroupement.
  plain,

  /// Regroupées en bulles numérotées là où elles se chevauchent.
  clustered,
}

/// Les stations du viewport à dessiner à [zoom], et comment.
///
/// - Vue large, sans filtre de zone : la moins chère de chaque case de
///   l'écran seulement ; les autres apparaissent en zoomant, à mesure que
///   les cases rétrécissent sur la carte.
/// - Département ou autoroute choisi ([zoneFiltered]) : toutes, les moins
///   chères en dernier pour être dessinées par-dessus.
/// - Assez zoomé pour les totems, en zone filtrée, ou au-delà de
///   [_thinningMaxZoom] : toutes, regroupées là où elles se chevauchent.
@visibleForTesting
({List<Station> stations, MarkerMode mode}) markerStations(
  List<Station> stations, {
  required double zoom,
  required bool zoneFiltered,
  required String fuelCode,
  required Set<String> favoriteIds,
}) {
  final showDetail = zoom >= _detailZoomThreshold;
  final showAll = zoneFiltered && stations.length <= _maxZoneMarkers;
  if (showAll && !showDetail) {
    double price(Station s) => s.prices[fuelCode] ?? double.infinity;
    return (
      stations: [...stations]..sort((a, b) => price(b).compareTo(price(a))),
      mode: MarkerMode.plain,
    );
  }
  if (!showAll && zoom < _thinningMaxZoom) {
    return (
      stations: _thinOut(
        stations,
        zoom: zoom,
        cellPx: showDetail ? _totemCellPx : _dotCellPx,
        fuelCode: fuelCode,
        favoriteIds: favoriteIds,
      ),
      mode: MarkerMode.plain,
    );
  }
  return (stations: stations, mode: MarkerMode.clustered);
}

/// Keeps at most one station per [cellPx]-wide square of the screen at
/// [zoom] — the cheapest for [fuelCode] — plus every favorite.
List<Station> _thinOut(
  List<Station> stations, {
  required double zoom,
  required double cellPx,
  required String fuelCode,
  required Set<String> favoriteIds,
}) {
  double price(Station s) => s.prices[fuelCode] ?? double.infinity;
  return _thinOnGrid(
    stations,
    zoom: zoom,
    cellPx: cellPx,
    lat: (s) => s.lat,
    lng: (s) => s.lng,
    isBetter: (a, b) => price(a) < price(b),
    keep: (s) => favoriteIds.contains(s.id),
  );
}

/// Keeps at most one of [items] per [cellPx]-wide square of the screen at
/// [zoom] — the one [isBetter] ranks first — plus every one [keep] accepts.
///
/// The grid is laid on the Web Mercator world at the whole zoom level, not
/// on the viewport, so panning doesn't reshuffle which item a cell keeps.
List<T> _thinOnGrid<T>(
  List<T> items, {
  required double zoom,
  required double cellPx,
  required double Function(T) lat,
  required double Function(T) lng,
  required bool Function(T a, T b) isBetter,
  bool Function(T)? keep,
}) {
  final worldPx = 256 * math.pow(2, zoom.floor());
  final best = <(int, int), T>{};
  final kept = <T>[];
  for (final item in items) {
    if (keep != null && keep(item)) {
      kept.add(item);
      continue;
    }
    final latRad = lat(item) * math.pi / 180;
    final x = (lng(item) + 180) / 360 * worldPx;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        worldPx;
    final cell = ((x / cellPx).floor(), (y / cellPx).floor());
    final current = best[cell];
    if (current == null || isBetter(item, current)) best[cell] = item;
  }
  return kept..addAll(best.values);
}

/// Les bornes du viewport à dessiner à [zoom], et comment : comme les
/// stations (voir [markerStations]), la plus puissante de chaque case de
/// l'écran en vue large, toutes, regroupées, à partir de [_thinningMaxZoom].
@visibleForTesting
({List<EvStation> stations, MarkerMode mode}) markerEvStations(
  List<EvStation> stations, {
  required double zoom,
}) {
  if (zoom >= _thinningMaxZoom) {
    return (stations: stations, mode: MarkerMode.clustered);
  }
  return (
    stations: _thinOnGrid(
      stations,
      zoom: zoom,
      cellPx: zoom >= _detailZoomThreshold ? _evIconCellPx : _evDotCellPx,
      lat: (e) => e.lat,
      lng: (e) => e.lng,
      isBetter: (a, b) => a.maxPowerKw > b.maxPowerKw,
    ),
    mode: MarkerMode.plain,
  );
}

class _EvMarkersLayer extends ConsumerWidget {
  const _EvMarkersLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bounds = ref.watch(mapBoundsProvider);
    final zoom = ref.watch(mapZoomProvider);
    if (bounds == null || zoom == null) return const SizedBox.shrink();

    // Comme pour les stations : seulement les bornes autour de l'écran, pas
    // les milliers chargées pour toute la zone.
    final padded = bounds.expanded(_viewportPadding);
    final evStations = [
      for (final e in ref.watch(filteredEvStationsProvider))
        if (e.lat >= padded.south &&
            e.lat <= padded.north &&
            e.lng >= padded.west &&
            e.lng <= padded.east)
          e,
    ];

    // Vue large : un simple point, comme les stations y deviennent des
    // pastilles ; le rond à éclair y déborderait des côtes et des frontières.
    final compact = zoom < _detailZoomThreshold;
    Marker markerFor(EvStation ev) => Marker(
      point: ll.LatLng(ev.lat, ev.lng),
      width: compact ? 22 : 44,
      height: compact ? 22 : 44,
      child: _EvMarker(
        station: ev,
        compact: compact,
        onTap: () => showEvStationSheet(context, ev),
      ),
    );

    final shown = markerEvStations(evStations, zoom: zoom);
    if (shown.mode == MarkerMode.plain) {
      // Les plus puissantes en dernier, dessinées par-dessus leurs voisines.
      final sorted = [...shown.stations]
        ..sort((a, b) => a.maxPowerKw.compareTo(b.maxPowerKw));
      return MarkerLayer(markers: [for (final e in sorted) markerFor(e)]);
    }

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(40, 40),
        markers: [for (final ev in shown.stations) markerFor(ev)],
        builder: (context, markers) => CircleAvatar(
          backgroundColor: const Color(0xFF2F8F5B),
          child: Text(
            '${markers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact stand-in for [_StationMarker] shown when the map is zoomed out
/// too far for full price totems to be legible — the brand's logo, without
/// the visual noise of dozens of price totems.
class _StationDot extends StatelessWidget {
  const _StationDot({
    required this.color,
    required this.brand,
    required this.isFavorite,
    required this.onTap,
  });

  /// Couleur du carburant sélectionné, portée par l'anneau : la même pour
  /// toutes les stations, elle rappelle le carburant comparé, pas l'enseigne.
  final Color color;

  /// Enseigne de la station, ou `null` quand elle n'a pas pu être reconnue.
  final FuelBrand? brand;

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = this.brand;
    final ring = isFavorite ? AppColors.accent : color;

    return GestureDetector(
      onTap: onTap,
      child: brand == null
          // Enseigne inconnue : la pastille pleine d'avant, faute de logo à
          // y mettre.
          ? Center(
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
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
              ),
            )
          : Center(
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: _dotRingWidth),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
                child: BrandLogo(
                  brand: brand,
                  size: _dotSize - 2 * _dotRingWidth,
                  shape: BrandLogoShape.circle,
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
  final FuelBrand? brand;
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
              top: -8,
              right: 0,
              child: BrandLogo(brand: brand!, size: 22),
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
  const _EvMarker({
    required this.station,
    required this.onTap,
    this.compact = false,
  });

  final EvStation station;
  final VoidCallback onTap;

  /// Un point de couleur sans éclair, pour la vue large.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: evPowerColor(station.maxPowerKw),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 2),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: evPowerColor(station.maxPowerKw),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Credits the map data sources, as OpenStreetMap's licence requires. A
/// small pill rather than flutter_map's corner widget, which the list sheet
/// would cover.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.ev});

  /// Whether the EV chargers layer (IRVE open data) is showing.
  final bool ev;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          ev
              ? '© OpenStreetMap · IRVE data.gouv.fr'
              : '© OpenStreetMap contributors',
          style: const TextStyle(fontSize: 10.5, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Bouton rond blanc posé sur la carte. [flat] le rend sans fond ni ombre,
/// pour l'aligner dans un [_MapButtonGroup].
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
    this.flat = false,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;
  final bool flat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(icon, color: AppColors.primary, size: size * 0.46),
        ),
      ),
    );
    if (flat) return Material(type: MaterialType.transparency, child: button);
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: _floatingShadow,
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: button,
      ),
    );
  }
}

/// Plusieurs [_MapButton] empilés dans une même gélule blanche.
class _MapButtonGroup extends StatelessWidget {
  const _MapButtonGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                width: 24,
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Gélule d'action posée sur la carte : blanche, ou bleu nuit ([dark]) pour
/// l'action du moment.
class _MapPill extends StatelessWidget {
  const _MapPill({
    required this.onTap,
    required this.leading,
    required this.label,
    this.dark = false,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _floatingShadow,
      ),
      child: Material(
        color: dark ? AppColors.primary : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: dark ? Colors.white : AppColors.primary,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La recherche, repliée en simple bouton loupe : elle se déplie sur toute
/// la largeur au toucher, et se replie quand on la quitte sans rien y avoir
/// laissé.
class _ExpandingSearch extends StatefulWidget {
  const _ExpandingSearch({
    required this.expanded,
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  /// Dépliée ou non : tenu par l'écran, qui la replie quand on touche la
  /// carte. Pas de repli sur perte de focus : sur le web, le clic même qui
  /// la déplie fait perdre le focus au champ tout juste créé.
  final ValueNotifier<bool> expanded;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_ExpandingSearch> createState() => _ExpandingSearchState();
}

class _ExpandingSearchState extends State<_ExpandingSearch> {
  static const _duration = Duration(milliseconds: 280);

  bool get _expanded => widget.expanded.value;

  @override
  void initState() {
    super.initState();
    widget.expanded.addListener(_onExpandedChange);
  }

  @override
  void dispose() {
    widget.expanded.removeListener(_onExpandedChange);
    super.dispose();
  }

  void _onExpandedChange() {
    setState(() {});
    if (!_expanded) widget.focusNode.unfocus();
  }

  void _expand() {
    widget.expanded.value = true;
    // Le champ existe dès l'image suivante : le focus est pris tout de
    // suite, sans attendre la fin de l'animation, pour ne perdre aucune
    // frappe.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.focusNode.requestFocus(),
    );
  }

  void _close() {
    widget.onClear();
    widget.expanded.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          width: _expanded ? constraints.maxWidth : _topButtonSize,
          height: _topButtonSize,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(_topButtonSize / 2)),
            boxShadow: _floatingShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            // Le champ est dessiné à sa largeur finale et rogné pendant que
            // la gélule s'élargit : il se dévoile au lieu de déborder.
            child: _expanded
                ? ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(_topButtonSize / 2),
                    ),
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: constraints.maxWidth,
                      maxWidth: constraints.maxWidth,
                      child: _field(context),
                    ),
                  )
                : _button(),
          ),
        ),
      ),
    );
  }

  Widget _button() => Tooltip(
    message: 'Rechercher',
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: _expand,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _topButtonSize,
          height: _topButtonSize,
          child: Icon(Icons.search_rounded, color: AppColors.primary, size: 19),
        ),
      ),
    ),
  );

  Widget _field(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          tooltip: 'Fermer la recherche',
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
          onPressed: _close,
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            textInputAction: TextInputAction.search,
            cursorColor: AppColors.primary,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.primary),
            decoration: InputDecoration(
              hintText: 'Adresse, ville ou code postal…',
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              filled: false,
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (widget.searching)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 12)
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.primary.withValues(alpha: 0.6),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                      widget.focusNode.requestFocus();
                    },
                  ),
          ),
      ],
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onSelect});

  final List<SearchHit> results;
  final ValueChanged<SearchHit> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: _floatingShadow,
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Blanc fixe, comme la gélule de recherche au-dessus : les commandes
        // posées sur la carte ne suivent pas le thème (voir AppColors).
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: results.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 56,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              final result = results[index];
              final isStation = result.kind == SearchHitKind.station;
              return ListTile(
                iconColor: AppColors.primary,
                textColor: AppColors.primary,
                subtitleTextStyle: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.primary.withValues(alpha: 0.6)),
                leading: Icon(
                  isStation
                      ? Icons.local_gas_station_rounded
                      : Icons.place_outlined,
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
