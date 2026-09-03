import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Reads/writes the parsed station list as a single JSON file on disk, so
/// the app has data to show immediately on next launch without waiting on
/// the network.
class StationCache {
  static const _fileName = 'stations-cache.json';
  static const _metaFileName = 'stations-cache-meta.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _metaFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  Future<List<Map<String, dynamic>>?> read() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      final list = jsonDecode(text) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(List<Map<String, dynamic>> stations) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(stations));
    final meta = await _metaFile();
    await meta.writeAsString(jsonEncode({'lastUpdate': DateTime.now().toIso8601String()}));
  }

  Future<DateTime?> lastUpdate() async {
    try {
      final meta = await _metaFile();
      if (!await meta.exists()) return null;
      final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      return DateTime.tryParse(json['lastUpdate'] as String);
    } catch (_) {
      return null;
    }
  }
}
