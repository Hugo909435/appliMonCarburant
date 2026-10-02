import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/config/app_config.dart';

void main() {
  test('endpoint keeps the API key carried by the base URL', () {
    final uri = AppConfig.endpoint(
      'https://eu1.locationiq.com/v1/directions/driving?key=abc',
      path: '/2.35,48.85;4.83,45.76',
      query: {'overview': 'full', 'geometries': 'geojson'},
    );
    expect(uri.path, '/v1/directions/driving/2.35,48.85;4.83,45.76');
    expect(uri.queryParameters, {
      'key': 'abc',
      'overview': 'full',
      'geometries': 'geojson',
    });
  });

  test('endpoint works on a base URL without query', () {
    final uri = AppConfig.endpoint(
      'https://nominatim.openstreetmap.org/search',
      query: {'q': 'Lyon'},
    );
    expect(
      uri.toString(),
      'https://nominatim.openstreetmap.org/search?q=Lyon',
    );
  });
}
