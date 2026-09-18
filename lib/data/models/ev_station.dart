import 'dart:math' as math;

/// A public EV charging station, grouped from one or more individual
/// charge points (`id_station_itinerance`) in the IRVE consolidated feed.
class EvStation {
  const EvStation({
    required this.id,
    required this.name,
    required this.network,
    required this.address,
    required this.lat,
    required this.lng,
    required this.pointCount,
    required this.maxPowerKw,
    required this.plugTypes,
    required this.free,
    required this.accessCondition,
    required this.hours,
    required this.pmrAccessible,
  });

  final String id;
  final String name;

  /// Charging network operator, e.g. "TESLA SUPERCHARGER", "IZIVIA".
  final String network;
  final String address;
  final double lat;
  final double lng;
  final int pointCount;
  final double maxPowerKw;
  final List<String> plugTypes;
  final bool free;
  final String accessCondition;
  final String hours;
  final bool pmrAccessible;

  factory EvStation.fromRecords(String id, List<Map<String, dynamic>> rows) {
    final first = rows.first;
    final plugTypes = <String>{};
    var maxPower = 0.0;
    var pointCount = 0;
    for (final row in rows) {
      final power = double.tryParse('${row['puissance_nominale'] ?? ''}');
      if (power != null && power > maxPower) maxPower = power;
      if (_isTrue(row['prise_type_2'])) plugTypes.add('Type 2');
      if (_isTrue(row['prise_type_combo_ccs'])) plugTypes.add('Combo CCS');
      if (_isTrue(row['prise_type_chademo'])) plugTypes.add('CHAdeMO');
      if (_isTrue(row['prise_type_ef'])) plugTypes.add('Type EF');
      pointCount += int.tryParse('${row['nbre_pdc'] ?? ''}') ?? 1;
    }
    return EvStation(
      id: id,
      name: (first['nom_station'] as String?)?.trim().isNotEmpty == true
          ? first['nom_station'] as String
          : (first['nom_enseigne'] as String? ?? 'Borne de recharge'),
      network: first['nom_enseigne'] as String? ?? '',
      address: first['adresse_station'] as String? ?? '',
      lat: _asDouble(first['consolidated_latitude']),
      lng: _asDouble(first['consolidated_longitude']),
      pointCount: pointCount == 0 ? rows.length : pointCount,
      maxPowerKw: maxPower,
      plugTypes: plugTypes.toList(),
      free: _isTrue(first['gratuit']),
      accessCondition: first['condition_acces'] as String? ?? '',
      hours: first['horaires'] as String? ?? '',
      pmrAccessible: (first['accessibilite_pmr'] as String? ?? '')
          .toLowerCase()
          .contains('accessible'),
    );
  }

  double distanceKmTo(double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat);
    final dLng = _deg2rad(lng2 - lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  static bool _isTrue(dynamic v) =>
      v.toString().trim().toLowerCase() == 'true';

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}
