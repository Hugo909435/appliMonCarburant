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

/// The map's current zoom level, updated (debounced) alongside
/// [mapBoundsProvider]. Null until the map has rendered once.
final mapZoomProvider = StateProvider<double?>((ref) => null);

extension MapBoundsPadding on MapBounds {
  /// Grows the bounds by [factor] of their own span on every side, so
  /// markers just outside the visible viewport are still built ahead of a
  /// pan, instead of popping in only once it settles.
  MapBounds expanded(double factor) {
    final latPad = (north - south) * factor;
    final lngPad = (east - west) * factor;
    return MapBounds(
      south: south - latPad,
      west: west - lngPad,
      north: north + latPad,
      east: east + lngPad,
    );
  }
}
