import 'dart:math' as math;

import '../../data/models/station.dart';

/// A point of a route polyline.
class RoutePoint {
  const RoutePoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// A station found close enough to a route to be worth stopping at.
class StationOnRoute {
  const StationOnRoute({
    required this.station,
    required this.offRouteKm,
    required this.kmFromStart,
  });

  final Station station;

  /// Straight-line distance between the station and the closest point of
  /// the route.
  final double offRouteKm;

  /// How far along the route that closest point is, from the departure.
  final double kmFromStart;
}

const _earthRadiusKm = 6371.0;
const _kmPerDegLat = 111.32;

/// Fast equirectangular distance: accurate to well under 1 % at the few-km
/// scale we care about, and much cheaper than haversine when it runs
/// millions of times.
double _approxKm(double lat1, double lng1, double lat2, double lng2) {
  final x = (lng2 - lng1) * math.cos((lat1 + lat2) / 2 * math.pi / 180);
  final y = lat2 - lat1;
  return math.sqrt(x * x + y * y) * math.pi / 180 * _earthRadiusKm;
}

class _Sample {
  const _Sample(this.lat, this.lng, this.km);
  final double lat;
  final double lng;
  final double km;
}

/// Stations within [corridorKm] of [route], ordered along the route.
///
/// The polyline is resampled every [stepKm] and the samples are bucketed
/// into a coarse lat/lng grid, so each station only gets compared with the
/// handful of samples around it instead of the whole route: a Paris → Nice
/// run against every station in France stays in the tens of milliseconds.
List<StationOnRoute> stationsAlongRoute({
  required List<RoutePoint> route,
  required Iterable<Station> stations,
  required double corridorKm,
  double stepKm = 0.5,
}) {
  if (route.length < 2) return const [];

  final samples = _resample(route, stepKm);

  // One cell must be at least as wide as the corridor so checking a cell
  // and its 8 neighbours can never miss a match. Longitude degrees shrink
  // with latitude; France's northernmost point (~51.1°N) is the worst case.
  final cellDeg = math.max(
    0.05,
    corridorKm / (_kmPerDegLat * math.cos(51.5 * math.pi / 180)),
  );
  final grid = <(int, int), List<_Sample>>{};
  var minLat = double.infinity, maxLat = -double.infinity;
  var minLng = double.infinity, maxLng = -double.infinity;
  for (final s in samples) {
    grid.putIfAbsent(_cell(s.lat, s.lng, cellDeg), () => []).add(s);
    minLat = math.min(minLat, s.lat);
    maxLat = math.max(maxLat, s.lat);
    minLng = math.min(minLng, s.lng);
    maxLng = math.max(maxLng, s.lng);
  }
  minLat -= cellDeg;
  maxLat += cellDeg;
  minLng -= cellDeg;
  maxLng += cellDeg;

  final results = <StationOnRoute>[];
  for (final station in stations) {
    if (station.lat < minLat ||
        station.lat > maxLat ||
        station.lng < minLng ||
        station.lng > maxLng) {
      continue;
    }
    final (cx, cy) = _cell(station.lat, station.lng, cellDeg);
    _Sample? best;
    var bestKm = double.infinity;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = grid[(cx + dx, cy + dy)];
        if (bucket == null) continue;
        for (final s in bucket) {
          final d = _approxKm(station.lat, station.lng, s.lat, s.lng);
          if (d < bestKm) {
            bestKm = d;
            best = s;
          }
        }
      }
    }
    if (best != null && bestKm <= corridorKm) {
      results.add(
        StationOnRoute(
          station: station,
          offRouteKm: bestKm,
          kmFromStart: best.km,
        ),
      );
    }
  }
  results.sort((a, b) => a.kmFromStart.compareTo(b.kmFromStart));
  return results;
}

(int, int) _cell(double lat, double lng, double cellDeg) =>
    ((lat / cellDeg).floor(), (lng / cellDeg).floor());

/// Evenly spaced points along the polyline, each tagged with its distance
/// from the start. Always keeps the first and last points.
List<_Sample> _resample(List<RoutePoint> route, double stepKm) {
  final out = <_Sample>[_Sample(route.first.lat, route.first.lng, 0)];
  var travelled = 0.0;
  var nextAt = stepKm;
  for (var i = 1; i < route.length; i++) {
    final a = route[i - 1];
    final b = route[i];
    final segKm = _approxKm(a.lat, a.lng, b.lat, b.lng);
    if (segKm == 0) continue;
    while (nextAt <= travelled + segKm) {
      final t = (nextAt - travelled) / segKm;
      out.add(
        _Sample(
          a.lat + (b.lat - a.lat) * t,
          a.lng + (b.lng - a.lng) * t,
          nextAt,
        ),
      );
      nextAt += stepKm;
    }
    travelled += segKm;
  }
  out.add(_Sample(route.last.lat, route.last.lng, travelled));
  return out;
}
