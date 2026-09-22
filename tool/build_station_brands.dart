// Regenerates assets/data/station_brands.json: the brand of each station
// of the official feed, matched against OpenStreetMap fuel stations.
//
// The official feed carries no brand, and querying OpenStreetMap from
// every phone is too slow (a nationwide Overpass query takes minutes), so
// the matching is done here once and shipped with the app. Re-run before a
// release to pick up new stations and brand changes:
//
//   dart run tool/build_station_brands.dart
//   dart run tool/build_station_brands.dart --osm fr.csv   (reuse a download)
//
// Brand data © OpenStreetMap contributors, ODbL.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mon_carburant_app/core/brands/brand_matching.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/data/services/gov_feed_parser.dart';

const _feedUrl = 'https://donnees.roulez-eco.fr/opendata/instantane';
const _overpassUrls = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];
// `out center` gives stations mapped as an area a single point, which the
// CSV ::lat/::lon columns then report.
const _overpassQuery =
    '[out:csv(::lat,::lon,brand,name;false;"\\t")][timeout:300];'
    'area["ISO3166-1"="FR"][admin_level=2]->.fr;'
    'nwr["amenity"="fuel"](area.fr);'
    'out center;';
const _output = 'assets/data/station_brands.json';

Future<void> main(List<String> args) async {
  final osmIndex = args.indexOf('--osm');
  final csv = osmIndex >= 0
      ? await File(args[osmIndex + 1]).readAsString()
      : await _downloadOsm();
  final pois = parseOverpassCsv(csv);
  stdout.writeln('OpenStreetMap : ${pois.length} stations');

  stdout.writeln('Téléchargement du flux officiel…');
  final feed = await http.get(Uri.parse(_feedUrl));
  if (feed.statusCode != 200) {
    throw HttpException('Flux officiel : HTTP ${feed.statusCode}');
  }
  final stations = parseGovFeed(feed.bodyBytes).map(Station.fromJson).toList();
  stdout.writeln('Flux officiel : ${stations.length} stations');

  final brands = matchStationBrands(stations, pois);
  final sorted = Map.fromEntries(
    brands.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  await File(_output).writeAsString(jsonEncode(sorted));

  final counts = <String, int>{};
  for (final key in brands.values) {
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final top = counts.entries.toList()..sort((a, b) => b.value - a.value);
  stdout
    ..writeln(
      '${brands.length}/${stations.length} stations avec enseigne '
      '(${(100 * brands.length / stations.length).round()} %) → $_output',
    )
    ..writeln(top.take(25).map((e) => '  ${e.value}\t${e.key}').join('\n'));
}

Future<String> _downloadOsm() async {
  for (final url in _overpassUrls) {
    stdout.writeln('OpenStreetMap ($url), patience : 1 à 3 minutes…');
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'User-Agent': 'mon-carburant-app/1.0 (build tool)'},
            body: {'data': _overpassQuery},
          )
          .timeout(const Duration(minutes: 6));
      final body = utf8.decode(response.bodyBytes);
      // Overpass reports overload as an HTML page, sometimes with HTTP 200.
      if (response.statusCode == 200 && RegExp(r'^-?\d').hasMatch(body)) {
        return body;
      }
      stderr.writeln('  échec (HTTP ${response.statusCode}), serveur suivant');
    } catch (e) {
      stderr.writeln('  échec ($e), serveur suivant');
    }
  }
  throw StateError('Aucun serveur Overpass disponible, réessayez plus tard.');
}
