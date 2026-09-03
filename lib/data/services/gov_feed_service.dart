import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gov_feed_parser.dart';

/// Downloads the live government open-data feed and parses it off the main
/// isolate. Same public source the website's own daily build script uses:
/// https://donnees.roulez-eco.fr/opendata/instantane (Licence Ouverte / Open Licence).
class GovFeedService {
  static const _url = 'https://donnees.roulez-eco.fr/opendata/instantane';

  Future<List<Map<String, dynamic>>> fetchStations() async {
    final response = await http
        .get(Uri.parse(_url), headers: {'User-Agent': 'mon-carburant-app/1.0'})
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Échec du téléchargement des données (HTTP ${response.statusCode})');
    }
    final bytes = response.bodyBytes;
    return compute(parseGovFeed, Uint8List.fromList(bytes));
  }
}
