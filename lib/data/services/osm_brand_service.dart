import 'dart:convert';

import 'package:http/http.dart' as http;

/// A fuel POI from OpenStreetMap carrying a brand name, used only to enrich
/// government stations (which never carry a brand) with a visual brand tag.
class OsmFuelBrand {
  const OsmFuelBrand({required this.brand, required this.lat, required this.lng});

  final String brand;
  final double lat;
  final double lng;
}

/// Looks up fuel station brands from OpenStreetMap (Overpass API) for a map
/// viewport. Data © OpenStreetMap contributors, ODbL — attribution required
/// wherever this is shown.
class OsmBrandService {
  static const _url = 'https://overpass-api.de/api/interpreter';

  Future<List<OsmFuelBrand>> fetchInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final query =
        '[out:json][timeout:15];'
        'node["amenity"="fuel"]["brand"]($south,$west,$north,$east);'
        'out body;';

    final response = await http
        .post(
          Uri.parse(_url),
          headers: {'User-Agent': 'mon-carburant-app/1.0'},
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final elements = (body['elements'] as List).cast<Map<String, dynamic>>();

    return [
      for (final el in elements)
        if ((el['tags'] as Map?)?['brand'] != null)
          OsmFuelBrand(
            brand: (el['tags'] as Map)['brand'] as String,
            lat: (el['lat'] as num).toDouble(),
            lng: (el['lon'] as num).toDouble(),
          ),
    ];
  }
}
