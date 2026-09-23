import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/route_corridor.dart';
import '../../core/config/app_config.dart';

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.duration,
  });

  final List<RoutePoint> points;
  final double distanceKm;
  final Duration duration;
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Driving itinerary backed by OSRM (OpenStreetMap data, no API key).
///
/// The server is [AppConfig.osrmBaseUrl]; see that class for why the public
/// demo instance it defaults to must not ship in a published build.
class RoutingService {
  static const _baseUrl = AppConfig.osrmBaseUrl;

  Future<RouteResult> route(RoutePoint from, RoutePoint to) async {
    final uri = Uri.parse(
      '$_baseUrl/${from.lng},${from.lat};${to.lng},${to.lat}',
    ).replace(queryParameters: {'overview': 'full', 'geometries': 'geojson'});

    final http.Response response;
    try {
      response = await http
          .get(uri, headers: const {'User-Agent': AppConfig.userAgent})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const RoutingException(
        "Impossible de calculer l'itinéraire. Vérifiez votre connexion.",
      );
    }
    if (response.statusCode != 200) {
      throw const RoutingException(
        "Le service d'itinéraire est indisponible pour le moment.",
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final routes = data['routes'] as List?;
    if (data['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw const RoutingException('Aucun itinéraire routier trouvé.');
    }
    final best = routes.first as Map;
    final coords = (best['geometry'] as Map)['coordinates'] as List;
    return RouteResult(
      points: [
        for (final c in coords)
          RoutePoint(
            ((c as List)[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
      ],
      distanceKm: (best['distance'] as num) / 1000,
      duration: Duration(seconds: (best['duration'] as num).round()),
    );
  }
}
