import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/station.dart';

/// A handful of fixture stations bundled with the app, used only as a
/// development fallback when the live government feed is unreachable (e.g.
/// rate-limited by repeated dev reloads). Never used in release builds —
/// see [StationRepository.refresh].
class SampleStationsService {
  static const _assetPath = 'assets/data/sample_stations.json';

  Future<List<Station>> load() async {
    final text = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(text) as List;
    return list.cast<Map<String, dynamic>>().map(Station.fromJson).toList();
  }
}
