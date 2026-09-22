import '../../data/models/station.dart';
import 'brand_rules.dart';

/// A fuel station from OpenStreetMap: position plus its `brand` and `name`
/// tags (either may be empty).
class OsmFuelPoi {
  const OsmFuelPoi(this.lat, this.lng, this.brand, this.name);
  final double lat;
  final double lng;
  final String brand;
  final String name;
}

/// Parses Overpass CSV output: one `lat<TAB>lon<TAB>brand<TAB>name` line
/// per station, no header.
List<OsmFuelPoi> parseOverpassCsv(String csv) {
  final pois = <OsmFuelPoi>[];
  for (final line in csv.split('\n')) {
    final cols = line.split('\t');
    if (cols.length < 4) continue;
    final lat = double.tryParse(cols[0]);
    final lng = double.tryParse(cols[1]);
    if (lat == null || lng == null) continue;
    pois.add(OsmFuelPoi(lat, lng, cols[2].trim(), cols[3].trim()));
  }
  return pois;
}

/// Government and OSM coordinates for the same station usually agree
/// within a few dozen meters, but rural stations can be off by a couple of
/// hundred. The mutual-nearest rule below is what keeps this radius from
/// tagging a station with its neighbour's brand.
const kBrandMatchMaxKm = 0.3;

/// Brand key (see [brandKeyFor]) of each station id, from OpenStreetMap.
///
/// A station and an OSM fuel station are paired only when each is the
/// other's closest, within [maxKm]: if the true station is missing from
/// OSM, the neighbour 250 m away is still closer to its own government
/// station and won't be borrowed. Stations with no such pair, or whose OSM
/// twin has no recognizable brand, are left out.
Map<String, String> matchStationBrands(
  List<Station> stations,
  List<OsmFuelPoi> pois, {
  double maxKm = kBrandMatchMaxKm,
}) {
  // ~1.1 km cells, wider than any match: each point only needs comparing
  // with the other set's points in its own cell and the 8 around it.
  const cell = 0.01;
  (int, int) cellOf(double lat, double lng) =>
      ((lat / cell).floor(), (lng / cell).floor());

  final poiGrid = <(int, int), List<int>>{};
  for (var i = 0; i < pois.length; i++) {
    poiGrid.putIfAbsent(cellOf(pois[i].lat, pois[i].lng), () => []).add(i);
  }
  final stationGrid = <(int, int), List<int>>{};
  for (var i = 0; i < stations.length; i++) {
    stationGrid
        .putIfAbsent(cellOf(stations[i].lat, stations[i].lng), () => [])
        .add(i);
  }

  int? nearest(
    double lat,
    double lng,
    Map<(int, int), List<int>> grid,
    double Function(int) distanceTo,
  ) {
    final (cx, cy) = cellOf(lat, lng);
    int? best;
    var bestKm = maxKm;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in grid[(cx + dx, cy + dy)] ?? const <int>[]) {
          final d = distanceTo(i);
          if (d <= bestKm) {
            bestKm = d;
            best = i;
          }
        }
      }
    }
    return best;
  }

  final result = <String, String>{};
  for (var si = 0; si < stations.length; si++) {
    final s = stations[si];
    final pi = nearest(
      s.lat,
      s.lng,
      poiGrid,
      (i) => s.distanceKmTo(pois[i].lat, pois[i].lng),
    );
    if (pi == null) continue;
    final poi = pois[pi];
    final back = nearest(
      poi.lat,
      poi.lng,
      stationGrid,
      (i) => stations[i].distanceKmTo(poi.lat, poi.lng),
    );
    if (back != si) continue;
    final key = poi.brand.isNotEmpty
        ? brandKeyFor(poi.brand, isBrandTag: true)
        : brandKeyFor(poi.name, isBrandTag: false);
    if (key != null) result[s.id] = key;
  }
  return result;
}
