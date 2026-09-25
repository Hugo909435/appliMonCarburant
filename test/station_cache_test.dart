import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/services/station_cache.dart';

void main() {
  late Directory dir;
  late StationCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('station_cache_test');
    cache = StationCache(directory: () async => dir);
  });

  tearDown(() async {
    // Sous Windows, l'antivirus tient parfois un instant le fichier qu'on
    // vient d'écrire : la suppression échoue (« répertoire non vide »). On
    // réessaie, et un dossier temporaire oublié ne fait pas échouer le test.
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await dir.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  List<Map<String, dynamic>> stations(int count, String tag) => [
    for (var i = 0; i < count; i++) {'id': '$tag$i', 'ville': 'Lyon'},
  ];

  test('reads back what was written, with its date', () async {
    await cache.write(stations(3, 'a'));

    expect(await cache.read(), stations(3, 'a'));
    expect(await cache.lastUpdate(), isNotNull);
  });

  test('leaves no temporary file behind', () async {
    await cache.write(stations(3, 'a'));
    await cache.write(stations(5, 'b'));

    final names = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(names, {'stations-cache.json', 'stations-cache-meta.json'});
  });

  test('clears old leftovers of interrupted writes, not recent ones', () async {
    final old = File('${dir.path}/stations-cache.json.1-1.tmp')
      ..writeAsStringSync('partial');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    // Peut-être l'écriture en cours d'un autre isolate : on n'y touche pas.
    final recent = File('${dir.path}/stations-cache.json.2-2.tmp')
      ..writeAsStringSync('partial');

    await cache.write(stations(3, 'a'));

    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
  });

  // Garde-fou plutôt que preuve : le conflit dépend du minutage, qu'un test
  // ne sait pas provoquer à coup sûr (l'ancienne écriture directe passait
  // aussi ce test la plupart du temps).
  test('concurrent writes and reads never see a partial file', () async {
    final a = stations(20000, 'a');
    final b = stations(20000, 'b');
    await cache.write(a);

    final reads = <List<Map<String, dynamic>>?>[];
    await Future.wait([
      cache.write(b),
      cache.write(a),
      for (var i = 0; i < 20; i++) cache.read().then(reads.add),
    ]);

    // Chaque lecture voit une liste entière, jamais un JSON tronqué (null).
    for (final read in reads) {
      expect(read, isNotNull);
      expect(read, hasLength(20000));
    }
    expect(await cache.read(), hasLength(20000));
  });
}
