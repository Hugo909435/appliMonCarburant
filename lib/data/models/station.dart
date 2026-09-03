import 'dart:math' as math;

/// A single day's opening hours, e.g. "07:00-20:00,21:00-23:00", or "F" if
/// the station declares itself closed that day, or null if unknown.
typedef DayHours = String?;

class Station {
  const Station({
    required this.id,
    required this.cp,
    required this.dep,
    required this.ville,
    required this.adresse,
    required this.lat,
    required this.lng,
    required this.pop,
    required this.prices,
    required this.priceUpdates,
    required this.services,
    required this.horaires,
    required this.automate,
    this.highway,
  });

  final String id;
  final String cp;
  final String dep;
  final String ville;
  final String adresse;
  final double lat;
  final double lng;

  /// 'route' or 'autoroute' (from the feed's `pop` attribute: R/A).
  final String pop;

  /// Fuel code -> price in euros.
  final Map<String, double> prices;

  /// Fuel code -> last update timestamp (raw string from the feed).
  final Map<String, String> priceUpdates;

  final List<String> services;

  /// 7 entries, index 0 = Monday ... 6 = Sunday.
  final List<DayHours>? horaires;

  final bool automate;

  /// Highway code extracted from the address (e.g. "A6"), only for pop == 'autoroute'.
  final String? highway;

  bool get isAutoroute => pop == 'autoroute';

  DateTime? get lastUpdate {
    final dates = priceUpdates.values.where((d) => d.isNotEmpty).toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return DateTime.tryParse(dates.last);
  }

  double distanceKmTo(double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat);
    final dLng = _deg2rad(lng2 - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cp': cp,
        'dep': dep,
        'ville': ville,
        'adresse': adresse,
        'lat': lat,
        'lng': lng,
        'pop': pop,
        'prices': prices,
        'priceUpdates': priceUpdates,
        'services': services,
        'horaires': horaires,
        'automate': automate,
        'highway': highway,
      };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as String,
        cp: json['cp'] as String,
        dep: json['dep'] as String,
        ville: json['ville'] as String,
        adresse: json['adresse'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        pop: json['pop'] as String,
        prices: Map<String, double>.from(
          (json['prices'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        ),
        priceUpdates: Map<String, String>.from(json['priceUpdates'] as Map),
        services: List<String>.from(json['services'] as List),
        horaires: (json['horaires'] as List?)?.map((e) => e as String?).toList(),
        automate: json['automate'] as bool,
        highway: json['highway'] as String?,
      );
}
