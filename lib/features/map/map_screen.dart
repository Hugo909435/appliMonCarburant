import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/station.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';
import '../../shared/widgets/fuel_selector.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const _franceCenter = ll.LatLng(46.6, 2.5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final fuel = ref.watch(selectedFuelProvider);
    final position = ref.watch(userLocationProvider).valueOrNull;

    final withFuel = stations.where((s) => s.prices.containsKey(fuel.code)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Carte des stations')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          const FuelSelector(),
          const SizedBox(height: 12),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: position != null
                    ? ll.LatLng(position.latitude, position.longitude)
                    : _franceCenter,
                initialZoom: position != null ? 12 : 5.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.moncarburant.mon_carburant_app',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(40, 40),
                    markers: [
                      for (final station in withFuel)
                        Marker(
                          point: ll.LatLng(station.lat, station.lng),
                          width: 40,
                          height: 40,
                          child: _StationMarker(
                            station: station,
                            onTap: () => _showStationSheet(context, station),
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
                ),
                if (position != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: ll.LatLng(position.latitude, position.longitude),
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(userLocationProvider.notifier).requestLocation(),
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showStationSheet(BuildContext context, Station station) {
    final fuel = ProviderScope.containerOf(context).read(selectedFuelProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(station.ville, style: Theme.of(context).textTheme.titleLarge),
            Text(station.adresse),
            const SizedBox(height: 8),
            Text(
              formatPrice(station.prices[fuel.code]),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/station/${station.id}');
                },
                child: const Text('Voir la fiche'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({required this.station, required this.onTap});

  final Station station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.location_on, color: AppColors.accent, size: 34),
    );
  }
}
