import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapBounds {
  const MapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;
}

/// The map's current visible bounds, updated (debounced) as the user pans
/// or zooms. Null until the map has rendered once.
final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);
