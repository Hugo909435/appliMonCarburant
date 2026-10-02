import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

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

/// Free-text address search from a Nominatim-compatible API
/// (OpenStreetMap data, like the map tiles).
class GeocodingService {
  static const _url = AppConfig.nominatimBaseUrl;

  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // `json` rather than `jsonv2`: hosted Nominatim-compatible APIs
    // (LocationIQ) only accept the former, and both carry the fields read
    // below.
    final uri = AppConfig.endpoint(
      _url,
      query: {
        'q': trimmed,
        'format': 'json',
        'countrycodes': 'fr',
        'limit': '5',
        'addressdetails': '0',
      },
    );

    final response = await http
        .get(uri, headers: const {'User-Agent': AppConfig.userAgent})
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
