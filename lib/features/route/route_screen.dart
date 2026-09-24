import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme/app_theme.dart';
import '../../core/theme/fuel_colors.dart';
import '../../core/utils/fill_cost.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/route_corridor.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/station.dart';
import '../../data/services/routing_service.dart';
import '../../providers/routing_provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../shared/widgets/fuel_selector.dart';
import '../../shared/widgets/station_list_tile.dart';
import '../../shared/widgets/station_sheet.dart';
import '../../core/config/app_config.dart';
import 'place_picker_sheet.dart';
import '../../shared/widgets/ad_slot.dart';

enum _RouteSort { realCost, alongRoute }

class _Candidate {
  const _Candidate(this.onRoute, this.price, this.cost);
  final StationOnRoute onRoute;
  final double price;
  final FillCost cost;
  Station get station => onRoute.station;
}

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  PickedPlace _from = PickedPlace.myLocation;
  PickedPlace? _to;
  double _corridorKm = 2;
  _RouteSort _sort = _RouteSort.realCost;

  bool _loading = false;
  String? _error;
  RouteResult? _route;
  List<StationOnRoute> _stationsOnRoute = const [];

  Future<void> _pick({required bool from}) async {
    final place = await showPlacePicker(
      context,
      title: from ? 'Départ' : 'Arrivée',
      offerMyLocation: true,
    );
    if (place == null || !mounted) return;
    setState(() => from ? _from = place : _to = place);
    await _compute();
  }

  void _swap() {
    final to = _to;
    if (to == null) return;
    setState(() {
      _to = _from;
      _from = to;
    });
    _compute();
  }

  Future<RoutePoint?> _resolve(PickedPlace place) async {
    if (!place.isMyLocation) return RoutePoint(place.lat!, place.lng!);
    var position = ref.read(userLocationProvider).valueOrNull;
    if (position == null) {
      await ref.read(userLocationProvider.notifier).requestLocation();
      position = ref.read(userLocationProvider).valueOrNull;
    }
    if (position == null) return null;
    return RoutePoint(position.latitude, position.longitude);
  }

  Future<void> _compute() async {
    final to = _to;
    if (to == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await _resolve(_from);
      final b = await _resolve(to);
      if (a == null || b == null) {
        throw const RoutingException(
          "Position indisponible : autorisez la localisation ou saisissez "
          'une adresse de départ.',
        );
      }
      final route = await ref.read(routingServiceProvider).route(a, b);
      if (!mounted) return;
      setState(() {
        _route = route;
        _loading = false;
      });
      _refilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Re-runs only the corridor search, e.g. when the corridor width
  /// changes, without asking OSRM for the route again.
  void _refilter() {
    final route = _route;
    if (route == null) return;
    final stations =
        ref.read(stationsProvider).valueOrNull ?? const <Station>[];
    setState(() {
      _stationsOnRoute = stationsAlongRoute(
        route: route.points,
        stations: stations,
        corridorKm: _corridorKm,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fuel = ref.watch(selectedFuelProvider);
    final vehicle = ref.watch(vehicleProfileProvider);

    final candidates = [
      for (final s in _stationsOnRoute)
        if (s.station.prices[fuel.code] case final price?)
          _Candidate(
            s,
            price,
            computeFillCost(
              pricePerLiter: price,
              liters: vehicle.fillLiters,
              consumptionL100: vehicle.consumptionL100,
              detourKm: s.offRouteKm,
            ),
          ),
    ];
    final byCost = [...candidates]
      ..sort((a, b) => a.cost.total.compareTo(b.cost.total));
    final listed = _sort == _RouteSort.realCost ? byCost : candidates;
    final ads = InFeedAds(listed.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Plein sur mon trajet')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _RouteForm(
              from: _from,
              to: _to,
              onPickFrom: () => _pick(from: true),
              onPickTo: () => _pick(from: false),
              onSwap: _swap,
            ),
          ),
          const SliverToBoxAdapter(child: FuelSelector()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('Écart max. avec la route'),
                  const Spacer(),
                  for (final km in const [1.0, 2.0, 5.0])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('${km.round()} km'),
                        selected: _corridorKm == km,
                        onSelected: (_) {
                          setState(() => _corridorKm = km);
                          _refilter();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(hasScrollBody: false, child: _Message(_error!))
          else if (_route == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                "Choisissez une destination pour voir les stations les moins "
                'chères le long de votre trajet.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: _RouteMap(
                route: _route!,
                best: byCost.take(3).toList(),
                fuel: fuel,
              ),
            ),
            SliverToBoxAdapter(
              child: _Summary(
                route: _route!,
                candidates: candidates,
                best: byCost.firstOrNull,
                fillLiters: vehicle.fillLiters,
              ),
            ),
            if (candidates.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SegmentedButton<_RouteSort>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _RouteSort.realCost,
                        label: Text('Coût réel'),
                      ),
                      ButtonSegment(
                        value: _RouteSort.alongRoute,
                        label: Text('Ordre du trajet'),
                      ),
                    ],
                    selected: {_sort},
                    onSelectionChanged: (s) => setState(() => _sort = s.first),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: ads.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (ads.isAd(index)) return const AdSlot();
                  final c = listed[ads.itemIndex(index)];
                  return StationListTile(
                    station: c.station,
                    fuel: fuel,
                    footer: _CandidateLine(candidate: c),
                    onTap: () => showStationSheet(context, c.station),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteForm extends StatelessWidget {
  const _RouteForm({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
  });

  final PickedPlace from;
  final PickedPlace? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _PlaceButton(
                  icon: Icons.trip_origin_rounded,
                  label: from.label,
                  onTap: onPickFrom,
                ),
                const SizedBox(height: 8),
                _PlaceButton(
                  icon: Icons.place_rounded,
                  label: to?.label ?? 'Où allez-vous ?',
                  placeholder: to == null,
                  onTap: onPickTo,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Inverser',
            onPressed: to == null ? null : onSwap,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.placeholder = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: placeholder
                    ? onSurface.withValues(alpha: 0.5)
                    : onSurface,
                fontWeight: placeholder ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.route,
    required this.best,
    required this.fuel,
  });

  final RouteResult route;
  final List<_Candidate> best;
  final FuelType fuel;

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in route.points) ll.LatLng(p.lat, p.lng)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            // A new route must re-fit the camera, which MapOptions only
            // applies on first build.
            key: ValueKey(route),
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(28),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.tileUrlTemplate,
                userAgentPackageName: AppConfig.packageName,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4,
                    color: AppColors.primary,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (var i = best.length - 1; i >= 0; i--)
                    Marker(
                      point: ll.LatLng(
                        best[i].station.lat,
                        best[i].station.lng,
                      ),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => showStationSheet(context, best[i].station),
                        child: CircleAvatar(
                          backgroundColor: fuel.color,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('Itinéraire OSRM'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.route,
    required this.candidates,
    required this.best,
    required this.fillLiters,
  });

  final RouteResult route;
  final List<_Candidate> candidates;
  final _Candidate? best;
  final double fillLiters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = route.duration.inHours;
    final minutes = route.duration.inMinutes % 60;
    final header =
        '${route.distanceKm.round()} km · '
        '${hours > 0 ? '$hours h ' : ''}${minutes.toString().padLeft(hours > 0 ? 2 : 1, '0')} min · '
        '${candidates.length} station${candidates.length > 1 ? 's' : ''}';

    final best = this.best;
    // Motorway stations are the "default" choice on a long trip: they're
    // the benchmark the savings figure is measured against.
    final highway = candidates.where((c) => c.station.isAutoroute).toList();
    final reference = highway.isNotEmpty ? highway : candidates;
    final referenceAvg = reference.isEmpty
        ? null
        : reference.map((c) => c.price).reduce((a, b) => a + b) /
              reference.length;
    final saving = best == null || referenceAvg == null
        ? null
        : referenceAvg * fillLiters - best.cost.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(header, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (best == null)
                const Text(
                  "Aucune station ne vend ce carburant près de l'itinéraire. "
                  "Essayez d'élargir l'écart avec la route.",
                )
              else ...[
                Text(
                  'Meilleur plein : ${best.station.ville}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${formatPrice(best.price)}/L · au km '
                  '${best.onRoute.kmFromStart.round()} · '
                  '${formatEuros(best.cost.total)} le plein de '
                  '${fillLiters.round()} L, détour compris',
                ),
                if (saving != null && saving >= 0.5) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Soit ${formatEuros(saving)} de moins que la moyenne des '
                    '${highway.isNotEmpty ? "stations d'autoroute" : 'stations'} '
                    'du trajet (${formatPrice(referenceAvg)}/L).',
                    style: const TextStyle(
                      color: AppColors.good,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateLine extends StatelessWidget {
  const _CandidateLine({required this.candidate});

  final _Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final r = candidate.onRoute;
    return Text(
      [
        'km ${r.kmFromStart.round()}',
        if (candidate.station.isAutoroute)
          'autoroute'
        else
          'à ${formatDistance(r.offRouteKm)} de la route',
        'plein ${formatEuros(candidate.cost.total)}',
      ].join(' · '),
      style: TextStyle(fontSize: 12.5, color: onSurface.withValues(alpha: 0.8)),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
