// Cherche l'icône d'application d'une enseigne sur l'App Store.
//
//   dart run tool/search_app_icons.dart Intermarché Casino
//   dart run tool/search_app_icons.dart --pays=be Colruyt
//
// Utile quand une enseigne n'a pas de symbole carré publié : l'icône de son
// application mobile en est un par construction, elle est officielle, et
// l'API de recherche d'Apple la sert en 512 px.
//
// Le script se contente de LISTER les candidats avec leur éditeur : c'est à
// l'œil humain de vérifier qu'il s'agit bien de l'app de l'enseigne et non
// d'un jeu ou d'une app de coupons homonyme.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _ua = 'MonCarburant/1.0 (contact@mon-carburant.com)';

Future<void> main(List<String> args) async {
  // Une enseigne étrangère (Colruyt est belge) n'est pas forcément publiée
  // sur la boutique française.
  var country = 'fr';
  final terms = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--pays=')) {
      country = arg.substring('--pays='.length);
    } else {
      terms.add(arg);
    }
  }
  if (terms.isEmpty) terms.addAll(['Intermarché', 'Casino', 'Colruyt']);
  for (final term in terms) {
    stdout.writeln('\n=== $term');
    final uri = Uri.parse('https://itunes.apple.com/search').replace(
      queryParameters: {
        'term': term,
        'country': country,
        'entity': 'software',
        'limit': '8',
      },
    );
    try {
      final r = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) {
        stdout.writeln('  HTTP ${r.statusCode}');
        continue;
      }
      final results =
          (jsonDecode(utf8.decode(r.bodyBytes))
                  as Map<String, dynamic>)['results']
              as List;
      for (final item in results) {
        final map = item as Map<String, dynamic>;
        stdout.writeln(
          '  ${(map['trackName'] as String? ?? '?').padRight(34)} '
          'par ${map['sellerName'] as String? ?? '?'}',
        );
        stdout.writeln('      ${map['artworkUrl512'] ?? map['artworkUrl100']}');
      }
    } catch (e) {
      stdout.writeln('  échec : $e');
    }
  }
}
