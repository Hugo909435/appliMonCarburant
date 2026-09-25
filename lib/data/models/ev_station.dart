import 'dart:math' as math;

/// The connectors the chargers filter offers, each with the IRVE field that
/// flags it. The feed has no Type 3 field: its `prise_type_autre` ("other")
/// is mostly legacy 3.7 kW Type 3 sockets, so it stands in for them.
const evPlugFields = {
  'Type 2': 'prise_type_2',
  'Combo CCS': 'prise_type_combo_ccs',
  'CHAdeMO': 'prise_type_chademo',
  'Domestique': 'prise_type_ef',
  'Type 3': 'prise_type_autre',
};

/// A public EV charging station, grouped from one or more individual
/// charge points (`id_station_itinerance`) in the IRVE consolidated feed.
class EvStation {
  const EvStation({
    required this.id,
    required this.name,
    required this.network,
    this.operatorName = '',
    required this.address,
    required this.lat,
    required this.lng,
    required this.pointCount,
    required this.maxPowerKw,
    required this.plugTypes,
    required this.free,
  });

  final String id;
  final String name;

  /// Charging network operator, e.g. "TESLA SUPERCHARGER", "IZIVIA".
  final String network;

  /// Company running the station (`nom_operateur`), e.g. "IZIVIA": what
  /// the operator filter matches, a cleaner list than [network].
  final String operatorName;
  final String address;
  final double lat;
  final double lng;
  final int pointCount;
  final double maxPowerKw;
  final List<String> plugTypes;
  final bool free;

  factory EvStation.fromRecords(String id, List<Map<String, dynamic>> rows) {
    final first = rows.first;
    final plugTypes = <String>{};
    var maxPower = 0.0;
    var pointCount = 0;
    for (final row in rows) {
      final power = evPowerKw(
        double.tryParse(
          '${row['puissance_max'] ?? row['puissance_nominale'] ?? ''}',
        ),
      );
      if (power != null && power > maxPower) maxPower = power;
      for (final MapEntry(key: label, value: field) in evPlugFields.entries) {
        if (_isTrue(row[field])) plugTypes.add(label);
      }
      // Grouped rows count their charge points in `pdc`.
      pointCount += (row['pdc'] as num?)?.toInt() ?? 1;
    }
    return EvStation(
      id: id,
      name: (first['nom_station'] as String?)?.trim().isNotEmpty == true
          ? first['nom_station'] as String
          : (first['nom_enseigne'] as String? ?? 'Borne de recharge'),
      network: first['nom_enseigne'] as String? ?? '',
      operatorName: (first['nom_operateur'] as String? ?? '').trim(),
      address: first['adresse_station'] as String? ?? '',
      lat: _asDouble(first['consolidated_latitude']),
      lng: _asDouble(first['consolidated_longitude']),
      pointCount: pointCount == 0 ? rows.length : pointCount,
      maxPowerKw: maxPower,
      plugTypes: plugTypes.toList(),
      free: _isTrue(first['gratuit']),
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

  // The feed mixes "true", "True", "TRUE" and "1".
  static bool _isTrue(dynamic v) {
    final s = v.toString().trim().toLowerCase();
    return s == 'true' || s == '1';
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

/// What a charger's sheet shows on top of its [EvStation], left out of the
/// map's fetch to keep it light and loaded when the sheet opens.
class EvStationDetails {
  const EvStationDetails({
    required this.accessCondition,
    required this.hours,
    required this.pmrAccessible,
  });

  final String accessCondition;
  final String hours;
  final bool pmrAccessible;

  factory EvStationDetails.fromRecord(Map<String, dynamic> row) =>
      EvStationDetails(
        accessCondition: row['condition_acces'] as String? ?? '',
        hours: row['horaires'] as String? ?? '',
        pmrAccessible: (row['accessibilite_pmr'] as String? ?? '')
            .toLowerCase()
            .contains('accessible'),
      );
}

/// Some operators publish their power in watts (22000 for 22 kW): anything
/// over [_wattsAbove] can't be kW, no charger is that powerful.
const _wattsAbove = 1000.0;

/// [power] from the feed in kW, whichever unit it was published in.
double? evPowerKw(double? power) =>
    power == null || power <= _wattsAbove ? power : power / 1000;

/// A charging operator of the feed. Some are published under several
/// spellings differing only in case ("LIDL France", "Lidl France"): they
/// are one operator here, [spellings] holding each as the feed has it.
class EvOperator {
  const EvOperator({
    required this.name,
    required this.spellings,
    required this.pointCount,
  });

  final String name;
  final List<String> spellings;

  /// Charge points it runs across France.
  final int pointCount;

  /// Merges [counts] (charge points per spelling) into operators, the
  /// largest first, each named after its most used spelling.
  static List<EvOperator> merge(Map<String, int> counts) {
    final byKey = <String, List<MapEntry<String, int>>>{};
    for (final entry in counts.entries) {
      final name = entry.key.trim();
      if (name.isEmpty) continue;
      // Raw spelling kept: the API matches it exactly.
      byKey.putIfAbsent(name.toLowerCase(), () => []).add(entry);
    }
    return [
      for (final group in byKey.values)
        EvOperator(
          name: (group..sort((a, b) => b.value.compareTo(a.value))).first.key
              .trim(),
          spellings: {for (final e in group) e.key}.toList(),
          pointCount: group.fold(0, (sum, e) => sum + e.value),
        ),
    ]..sort((a, b) => b.pointCount.compareTo(a.pointCount));
  }

  /// Whether a station run by [spelling] (as the feed has it) is ours.
  bool runs(String spelling) =>
      spelling.trim().toLowerCase() == name.toLowerCase();
}

/// What the chargers filter bar asks for. Applied by the API itself, so it
/// holds over a whole region too, where a fetch only brings the most
/// powerful chargers.
class EvFilter {
  const EvFilter({this.plug, this.evOperator, this.minPowerKw});

  /// A key of [evPlugFields], or null for any connector.
  final String? plug;
  final EvOperator? evOperator;
  final int? minPowerKw;

  bool get isEmpty => plug == null && evOperator == null && minPowerKw == null;

  /// The ODSQL conditions for this filter, joined with `and`; empty when
  /// nothing is filtered.
  String get where {
    String quoted(String s) =>
        '"${s.replaceAll(r'\', r'\').replaceAll('"', r'\"')}"';
    String flagged(String field) => '(lower($field) = "true" or $field = "1")';

    final plugField = evPlugFields[plug];
    final minKw = minPowerKw;
    return [
      if (plugField != null) flagged(plugField),
      if (evOperator != null)
        'nom_operateur in (${evOperator!.spellings.map(quoted).join(',')})',
      // Les puissances publiées en watts comptent aussi (voir evPowerKw).
      if (minKw != null)
        '((puissance_nominale >= $minKw and '
            'puissance_nominale <= $_wattsAbove) or '
            'puissance_nominale >= ${minKw * 1000})',
    ].join(' and ');
  }

  /// Whether [station] passes, for the chargers fetched before the filter
  /// changed and still shown while the new ones load.
  bool accepts(EvStation station) =>
      (plug == null || station.plugTypes.contains(plug)) &&
      (evOperator == null || evOperator!.runs(station.operatorName)) &&
      (minPowerKw == null || station.maxPowerKw >= minPowerKw!);

  @override
  bool operator ==(Object other) => other is EvFilter && other.where == where;

  @override
  int get hashCode => where.hashCode;
}
