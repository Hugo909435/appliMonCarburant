import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ev_station.dart';

import '../../core/config/app_config.dart';

/// Fetches public EV charging stations from the official IRVE consolidated
/// feed (ODRÉ / data.gouv.fr, Licence Ouverte), scoped to a map viewport so
/// the app never has to pull the ~227k-record national file at once.
class IrveService {
  static const _url =
      'https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/bornes-irve/records';

  /// Fields shared by every charge point of a station: grouping on them
  /// returns one row per station (a few more when its plugs differ), where
  /// the plain records endpoint caps out at 100 charge points per request.
  /// Only what the map, its filters and the list need: the rest of a
  /// station's sheet comes from [fetchDetails] when it opens.
  static const _groupFields = [
    'id_station_itinerance',
    'nom_station',
    'nom_enseigne',
    'nom_operateur',
    'adresse_station',
    'consolidated_latitude',
    'consolidated_longitude',
    'prise_type_2',
    'prise_type_combo_ccs',
    'prise_type_chademo',
    'prise_type_ef',
    'prise_type_autre',
    'gratuit',
  ];

  /// Most groups the API returns for one grouped request.
  static const _maxGroups = 20000;

  /// Share of the requested span fetched on top of it on every side.
  static const _padding = 0.3;

  /// Most chargers kept in [_known] before it starts over.
  static const _maxKnown = 40000;

  /// Last fetch, reused while the map stays inside it (see [_Fetch.covers]).
  _Fetch? _last;

  /// Every charger fetched so far, by station id: a new fetch adds to what
  /// earlier ones brought, so the slower chargers found while zoomed in stay
  /// on the map once zoomed back out, and an area already seen shows at once.
  final _known = <String, EvStation>{};

  /// Bumped by every network fetch, so an older one that lands after a
  /// newer one doesn't overwrite [_last].
  var _fetchCount = 0;

  /// The filter [_known] and [_last] were fetched with.
  var _filter = const EvFilter();

  /// The chargers inside the given bounds. Over a wide area (a region, the
  /// whole country) there are more than [_maxGroups]: the most powerful
  /// come first, so the ones left out are the slowest.
  ///
  /// Only the chargers passing [filter] come back: the API applies it, so
  /// it holds over a whole region too.
  ///
  /// Closing [client] aborts the request, for when the map moved on before
  /// it answered.
  Future<List<EvStation>> fetchInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    EvFilter filter = const EvFilter(),
    http.Client? client,
  }) async {
    if (filter != _filter) {
      // Ce qui a été chargé avec l'ancien filtre n'est plus la bonne liste.
      _filter = filter;
      _known.clear();
      _last = null;
    }
    final last = _last;
    if (last != null && last.covers(south, west, north, east)) {
      return _knownIn(last.south, last.west, last.north, last.east);
    }

    // A margin around the requested area, so a short pan stays inside this
    // fetch instead of waiting on a new one.
    final latPad = (north - south) * _padding;
    final lngPad = (east - west) * _padding;
    final fetchSouth = south - latPad;
    final fetchNorth = north + latPad;
    final fetchWest = west - lngPad;
    final fetchEast = east + lngPad;

    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'select':
            '${_groupFields.join(',')},'
            'max(puissance_nominale) as puissance_max,'
            'count(*) as pdc',
        'group_by': _groupFields.join(','),
        'where': [
          'consolidated_latitude in [$fetchSouth..$fetchNorth]',
          'consolidated_longitude in [$fetchWest..$fetchEast]',
          if (!filter.isEmpty) filter.where,
        ].join(' and '),
        'order_by': 'puissance_max desc',
        'limit': '$_maxGroups',
      },
    );

    final fetch = ++_fetchCount;
    const headers = {'User-Agent': AppConfig.userAgent};
    final response =
        await (client == null
                ? http.get(uri, headers: headers)
                : client.get(uri, headers: headers))
            .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
        'Échec du chargement des bornes de recharge (HTTP ${response.statusCode})',
      );
    }

    // Up to ~11 MB of JSON over the whole country: decoded off the UI
    // thread, which it would otherwise freeze for a good half-second.
    final parsed = await Isolate.run(() => _parse(response.bodyBytes));
    // The filter changed while this was loading: its chargers are no longer
    // the ones asked for, and nobody is waiting on them any more.
    if (filter != _filter) return const [];

    if (_known.length + parsed.stations.length > _maxKnown) _known.clear();
    for (final station in parsed.stations) {
      _known[station.id] = station;
    }
    if (fetch == _fetchCount) {
      _last = _Fetch(
        south: fetchSouth,
        west: fetchWest,
        north: fetchNorth,
        east: fetchEast,
        complete: parsed.rowCount < _maxGroups,
      );
    }
    return _knownIn(fetchSouth, fetchWest, fetchNorth, fetchEast);
  }

  /// Every operator of the feed, the largest first: one small grouped
  /// request (~5 KB) for the ~370 spellings it has.
  Future<List<EvOperator>> fetchOperators() async {
    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'select': 'nom_operateur,count(*) as n',
        'group_by': 'nom_operateur',
        'limit': '$_maxGroups',
      },
    );
    final response = await http
        .get(uri, headers: const {'User-Agent': AppConfig.userAgent})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Échec du chargement des opérateurs (HTTP ${response.statusCode})',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    return EvOperator.merge({
      for (final row in (body['results'] as List).cast<Map<String, dynamic>>())
        if (row['nom_operateur'] is String)
          row['nom_operateur'] as String: (row['n'] as num).toInt(),
    });
  }

  /// The sheet-only details of the station [id]: those of its first
  /// charge point, like the other station-wide fields.
  Future<EvStationDetails> fetchDetails(String id) async {
    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'select': 'condition_acces,horaires,accessibilite_pmr',
        'where': 'id_station_itinerance = "${id.replaceAll('"', r'\"')}"',
        'limit': '1',
      },
    );
    final response = await http
        .get(uri, headers: const {'User-Agent': AppConfig.userAgent})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(
        'Échec du chargement de la borne (HTTP ${response.statusCode})',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final records = (body['results'] as List).cast<Map<String, dynamic>>();
    return records.isEmpty
        ? const EvStationDetails(
            accessCondition: '',
            hours: '',
            pmrAccessible: false,
          )
        : EvStationDetails.fromRecord(records.first);
  }

  List<EvStation> _knownIn(
    double south,
    double west,
    double north,
    double east,
  ) => [
    for (final e in _known.values)
      if (e.lat >= south && e.lat <= north && e.lng >= west && e.lng <= east) e,
  ];
}

/// The stations of a grouped IRVE response, and how many rows it held.
({List<EvStation> stations, int rowCount}) _parse(Uint8List bytes) {
  final body = jsonDecode(utf8.decode(bytes)) as Map;
  final records = (body['results'] as List).cast<Map<String, dynamic>>();

  final byStation = <String, List<Map<String, dynamic>>>{};
  for (final row in records) {
    if (_isAbroad(row)) continue;
    final id =
        row['id_station_itinerance'] as String? ?? row.hashCode.toString();
    byStation.putIfAbsent(id, () => []).add(row);
  }

  return (
    stations: [
      for (final entry in byStation.entries)
        EvStation.fromRecords(entry.key, entry.value),
    ],
    rowCount: records.length,
  );
}

/// Areas clearly outside France (lat south/north, lng west/east), drawn
/// clear of the border so no French charger falls in one.
const _abroad = [
  (50.2, 51.6, 4.9, 6.5), // Belgique (Wallonie)
  (50.95, 51.6, 2.7, 4.9), // Belgique (Flandre)
  (49.53, 50.2, 5.9, 6.55), // Luxembourg
  (49.3, 55.0, 6.7, 15.0), // Allemagne (Sarre, Palatinat, au-delà)
  (46.2, 47.55, 7.65, 10.5), // Suisse
  (43.7, 46.2, 7.75, 19.0), // Italie
  (38.8, 41.3, 8.0, 10.0), // Sardaigne
  (35.0, 42.3, -10.0, 3.4), // Espagne
  (50.5, 60.0, -10.0, 1.5), // Royaume-Uni
];

/// Whether the feed's [row] is a charger abroad: some operators publish
/// their Belgian, Luxembourgish or Swiss stations in the French feed, and
/// its commune fields are too often blank to tell them apart.
bool _isAbroad(Map<String, dynamic> row) {
  final lat = (row['consolidated_latitude'] as num?)?.toDouble();
  final lng = (row['consolidated_longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return false;
  for (final (south, north, west, east) in _abroad) {
    if (lat >= south && lat <= north && lng >= west && lng <= east) {
      return true;
    }
  }
  return false;
}

class _Fetch {
  const _Fetch({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.complete,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  /// Whether every charger of the area came back, none cut by the limit.
  final bool complete;

  /// Whether this fetch can stand in for one of the given bounds: they lie
  /// inside it, and it holds every charger there — or, cut by the limit, it
  /// was for an area at most three times as tall (the viewport it was made
  /// for, padded), so a short pan doesn't refetch but zooming in brings the
  /// missing, slower chargers.
  bool covers(double s, double w, double n, double e) {
    final inside = s >= south && w >= west && n <= north && e <= east;
    return inside && (complete || (n - s) * 3 >= north - south);
  }
}
