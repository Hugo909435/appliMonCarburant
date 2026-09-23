import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ev_station.dart';

import '../../core/config/app_config.dart';

/// Fetches public EV charging stations from the official IRVE consolidated
/// feed (ODRÉ / data.gouv.fr, Licence Ouverte), scoped to a map viewport so
/// the app never has to pull the ~227k-record national file at once.
class IrveService {
  static const _url =
      'https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/bornes-irve/records';

  static const _fields = [
    'id_station_itinerance',
    'nom_station',
    'nom_enseigne',
    'adresse_station',
    'consolidated_latitude',
    'consolidated_longitude',
    'nbre_pdc',
    'puissance_nominale',
    'prise_type_2',
    'prise_type_combo_ccs',
    'prise_type_chademo',
    'prise_type_ef',
    'gratuit',
    'condition_acces',
    'horaires',
    'accessibilite_pmr',
  ];

  Future<List<EvStation>> fetchInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'select': _fields.join(','),
        'where':
            'consolidated_latitude in [$south..$north] and '
            'consolidated_longitude in [$west..$east]',
        'limit': '100',
      },
    );

    final response = await http
        .get(uri, headers: const {'User-Agent': AppConfig.userAgent})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Échec du chargement des bornes de recharge (HTTP ${response.statusCode})',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final records = (body['results'] as List).cast<Map<String, dynamic>>();

    final byStation = <String, List<Map<String, dynamic>>>{};
    for (final row in records) {
      final id =
          row['id_station_itinerance'] as String? ?? row.hashCode.toString();
      byStation.putIfAbsent(id, () => []).add(row);
    }

    return [
      for (final entry in byStation.entries)
        EvStation.fromRecords(entry.key, entry.value),
    ];
  }
}
