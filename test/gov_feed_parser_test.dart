import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/station.dart';
import 'package:mon_carburant_app/data/services/gov_feed_parser.dart';

/// Wraps [pdvs] in a feed ZIP like the one roulez-eco.fr serves.
Uint8List _feed(String pdvs) {
  final xml = latin1.encode(
    '<?xml version="1.0" encoding="ISO-8859-1"?><pdv_liste>$pdvs</pdv_liste>',
  );
  final archive = Archive()
    ..addFile(ArchiveFile('PrixCarburants_instantane.xml', xml.length, xml));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _pdv(String id, String body) =>
    '<pdv id="$id" latitude="4671100" longitude="-131600" cp="85280" pop="R">'
    '<adresse>Rue Nationale</adresse><ville>La Ferrière</ville>$body</pdv>';

void main() {
  test('keeps a station whose every fuel is temporarily out of stock', () {
    final stations = parseGovFeed(
      _feed(
        _pdv(
          '85280002',
          '<prix nom="Gazole" id="1" maj="2026-09-10 08:00:00" valeur="1.659"/>'
              '<rupture id="1" nom="Gazole" debut="2026-09-18 08:04:13" fin="" type="temporaire"/>'
              '<rupture id="6" nom="SP95" debut="2026-09-16 10:57:35" fin="" type="temporaire"/>'
              '<rupture id="3" nom="E85" debut="2017-09-05 06:37:00" fin="" type="definitive"/>',
        ),
      ),
    ).map(Station.fromJson).toList();

    expect(stations, hasLength(1));
    expect(stations.single.isOutOfStock, isTrue);
    expect(stations.single.shortages, ['Gazole', 'SP95']);
  });

  test('drops a station with nothing on sale and no temporary shortage', () {
    final stations = parseGovFeed(
      _feed(
        _pdv(
          '1',
          '<rupture id="3" nom="E85" debut="2017-09-05 06:37:00" fin="" type="definitive"/>',
        ),
      ),
    );
    expect(stations, isEmpty);
  });

  test('a station with a price is not out of stock', () {
    final stations = parseGovFeed(
      _feed(
        _pdv(
          '2',
          '<prix nom="Gazole" id="1" maj="2026-10-01 08:00:00" valeur="1.659"/>'
              '<rupture id="6" nom="SP95" debut="2026-09-16 10:57:35" fin="" type="temporaire"/>',
        ),
      ),
    ).map(Station.fromJson).toList();
    expect(stations.single.isOutOfStock, isFalse);
    expect(stations.single.prices, {'Gazole': 1.659});
  });

  test('a station cached before shortages existed still loads', () {
    final json = parseGovFeed(
      _feed(_pdv('3', '<prix nom="Gazole" id="1" maj="" valeur="1.6"/>')),
    ).single..remove('shortages');
    expect(Station.fromJson(json).shortages, isEmpty);
  });
}
