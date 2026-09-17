import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single address match returned by the geocoder.
class GeocodingResult {
  const GeocodingResult({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;
}

/// Free-text address search backed by Nominatim (OpenStreetMap), the same
/// data source as the map tiles — no API key required.
class GeocodingService {
  static const _url = 'https://nominatim.openstreetmap.org/search';

  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'countrycodes': 'fr',
        'limit': '5',
        'addressdetails': '0',
      },
    );

    final response = await http
        .get(uri, headers: {'User-Agent': 'mon-carburant-app/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return data
        .map(
          (e) => GeocodingResult(
            label: e['display_name'] as String,
            lat: double.parse(e['lat'] as String),
            lng: double.parse(e['lon'] as String),
          ),
        )
        .toList();
  }
}
