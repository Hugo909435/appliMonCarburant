import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// Reads/writes the parsed station list as a single JSON file on disk, so
/// the app has data to show immediately on next launch without waiting on
/// the network.
///
/// The background price check (price_alert_task.dart) writes it too, from
/// another isolate, possibly while the app is reading it: every write goes
/// through [_writeAtomically] so a reader only ever sees a whole file.
class StationCache {
  StationCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'stations-cache.json';
  static const _metaFileName = 'stations-cache-meta.json';

  final Future<Directory> Function() _directory;
  static final _random = Random();

  Future<File> _cacheFile() async {
    final dir = await _directory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _metaFile() async {
    final dir = await _directory();
    return File('${dir.path}/$_metaFileName');
  }

  Future<List<Map<String, dynamic>>?> read() => readAs(_identity);

  static Map<String, dynamic> _identity(Map<String, dynamic> json) => json;

  /// The cached stations, each turned into a [T] by [convert]. The file
  /// weighs several MB: it is read, decoded and converted in another
  /// isolate, which would otherwise freeze the UI for seconds at launch.
  Future<List<T>?> readAs<T>(T Function(Map<String, dynamic>) convert) async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final path = file.path;
      return await Isolate.run(() {
        final list = jsonDecode(File(path).readAsStringSync()) as List;
        return [for (final json in list) convert(json as Map<String, dynamic>)];
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> write(List<Map<String, dynamic>> stations) async {
    // No filesystem on web: fail silently rather than losing the just-fetched
    // data (the caller would otherwise treat this as a full refresh failure).
    try {
      await _deleteLeftovers();
      // Data first, date second, and readers go the other way round (see
      // StationsNotifier): one caught in between sees fresh prices with the
      // previous date, which at worst triggers one extra download — never
      // stale prices passed off as fresh.
      // Encodé hors du thread de l'interface : plusieurs Mo de JSON.
      final text = await Isolate.run(() => jsonEncode(stations));
      await _writeAtomically(await _cacheFile(), text);
      await _writeAtomically(
        await _metaFile(),
        jsonEncode({'lastUpdate': DateTime.now().toIso8601String()}),
      );
    } catch (_) {
      return;
    }
  }

  /// A temporary file older than this can't belong to a write in progress:
  /// its process died between writing and renaming it (app swiped away,
  /// background task stopped by the system).
  static const _leftoverAge = Duration(minutes: 30);

  /// Removes the temporary files such interrupted writes left behind. Each
  /// has a unique name and weighs 10+ MB, and nothing else ever purges this
  /// directory.
  Future<void> _deleteLeftovers() async {
    try {
      final dir = await _directory();
      final cutoff = DateTime.now().subtract(_leftoverAge);
      await for (final entity in dir.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is! File ||
            !name.startsWith('stations-cache') ||
            !name.endsWith('.tmp')) {
          continue;
        }
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // Already gone (another isolate cleaning up too) or locked.
        }
      }
    } catch (_) {
      // Housekeeping only: never let it fail the write.
    }
  }

  /// Writes [contents] to a temporary file next to [target], then renames it
  /// over [target]. A rename within a directory is atomic, so readers get
  /// either the old file or the new one, never half of it. The temporary
  /// name is unique, so two isolates writing at once can't mix their data.
  static Future<void> _writeAtomically(File target, String contents) async {
    final tmp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(1000000000)}.tmp',
    );
    try {
      await tmp.writeAsString(contents, flush: true);
      await tmp.rename(target.path);
    } catch (_) {
      // Don't leave a 10+ MB leftover behind on a failed write.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<DateTime?> lastUpdate() async {
    try {
      final meta = await _metaFile();
      if (!await meta.exists()) return null;
      final json =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      return DateTime.tryParse(json['lastUpdate'] as String);
    } catch (_) {
      return null;
    }
  }
}
