// Cherche des logos d'enseigne sur Wikimedia Commons et liste les candidats
// avec leurs dimensions, pour pouvoir choisir les versions carrées.
//
//   dart run tool/search_commons_logos.dart "E.Leclerc logo"
//
// Commons rend les SVG à la taille demandée : un fichier vectoriel donne donc
// un PNG net à 512 px, là où le favicon d'un site plafonne à 32.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _api = 'https://commons.wikimedia.org/w/api.php';
const _ua = 'MonCarburant/1.0 (contact@mon-carburant.com)';

Future<void> main(List<String> args) async {
  final queries = args.isNotEmpty
      ? args
      : [
          'E.Leclerc logo',
          'Intermarché logo',
          'Casino supermarchés logo',
        ];

  for (final query in queries) {
    stdout.writeln('\n=== $query');
    final search = await _json({
      'action': 'query',
      'list': 'search',
      'srsearch': 'filetype:bitmap|drawing $query',
      'srnamespace': '6',
      'srlimit': '12',
      'format': 'json',
    });
    final hits =
        ((search?['query'] as Map<String, dynamic>?)?['search'] as List?) ??
        const [];
    if (hits.isEmpty) {
      stdout.writeln('  rien trouvé');
      continue;
    }

    final titles = [for (final h in hits) (h as Map)['title'] as String];
    final info = await _json({
      'action': 'query',
      'titles': titles.join('|'),
      'prop': 'imageinfo',
      'iiprop': 'url|size',
      'iiurlwidth': '512',
      'format': 'json',
    });
    final pages =
        (info?['query'] as Map<String, dynamic>?)?['pages']
            as Map<String, dynamic>?;
    for (final page in (pages ?? {}).values) {
      final map = page as Map<String, dynamic>;
      final ii = (map['imageinfo'] as List?)?.first as Map<String, dynamic>?;
      if (ii == null) continue;
      final w = ii['width'] as int;
      final h = ii['height'] as int;
      final ratio = w / h;
      // Un symbole est à peu près carré ; au-delà, c'est un logotype long,
      // exactement ce qu'on cherche à éviter.
      final verdict = ratio < 1.6 ? '  <== CARRÉ' : '';
      stdout.writeln(
        '  ${(map['title'] as String).padRight(52)} '
        '${w}x$h  r=${ratio.toStringAsFixed(2)}$verdict',
      );
      if (verdict.isNotEmpty) {
        stdout.writeln('      ${ii['thumburl']}');
      }
    }
  }
}

Future<Map<String, dynamic>?> _json(Map<String, String> params) async {
  try {
    final r = await http
        .get(
          Uri.parse(_api).replace(queryParameters: params),
          headers: {'User-Agent': _ua},
        )
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
