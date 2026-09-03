import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/fuel_type.dart';

class PriceHistoryPoint {
  const PriceHistoryPoint({required this.date, required this.prices});

  final DateTime date;
  final Map<String, double> prices;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'prices': prices,
      };

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) => PriceHistoryPoint(
        date: DateTime.parse(json['date'] as String),
        prices: Map<String, double>.from(
          (json['prices'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        ),
      );
}

/// Builds a local price-history trend since the app can't read the
/// website's own build-time history (not published as a live endpoint) and
/// pulls straight from the government instant feed instead: one point is
/// appended per calendar day, capped to the last 90 days.
class PriceHistoryService {
  static const _key = 'national_price_history';
  static const _maxDays = 90;

  Future<List<PriceHistoryPoint>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(PriceHistoryPoint.fromJson).toList();
  }

  Future<void> recordToday(Map<FuelType, double?> nationalAverages) async {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final points = await load();
    points.removeWhere((p) => p.date == todayKey);

    final prices = <String, double>{
      for (final entry in nationalAverages.entries)
        if (entry.value != null) entry.key.code: entry.value!,
    };
    points.add(PriceHistoryPoint(date: todayKey, prices: prices));
    points.sort((a, b) => a.date.compareTo(b.date));
    final trimmed = points.length > _maxDays
        ? points.sublist(points.length - _maxDays)
        : points;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trimmed.map((p) => p.toJson()).toList()));
  }
}
