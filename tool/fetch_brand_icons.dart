// Récupère l'icône officielle du site d'une enseigne (apple-touch-icon,
// favicon…), qui est presque toujours le symbole carré de la marque — celui
// qui reste lisible sur un marqueur de carte, contrairement au logotype long.
//
//   dart run tool/fetch_brand_icons.dart
//
// Les fichiers atterrissent dans tool/icons_recuperees/ et NON dans
// assets/logos/ : il faut les regarder avant de remplacer quoi que ce soit.
//
// Ces icônes sont des marques déposées de leurs propriétaires, reprises
// uniquement pour identifier l'enseigne d'une station (cf. assets/logos/LISEZMOI.txt).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Sites officiels, par clé d'enseigne. Plusieurs candidats : les groupes
/// changent de domaine, et certains refusent les requêtes non navigateur.
const _sites = <String, List<String>>{
  'leclerc': ['https://www.e.leclerc/', 'https://www.leclercdrive.fr/'],
  'intermarche': ['https://www.intermarche.com/'],
  'casino': [
    'https://www.casino-supermarches.fr/',
    'https://www.geantcasino.fr/',
  ],
  'colruyt': ['https://www.colruyt.fr/', 'https://colruyt.be/'],
  'spar': ['https://www.spar.fr/', 'https://www.spar-international.com/'],
};

const _ua =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/125.0 Safari/537.36';

Future<void> main() async {
  final outDir = Directory('tool/icons_recuperees')..createSync(recursive: true);

  for (final entry in _sites.entries) {
    stdout.writeln('\n=== ${entry.key}');
    var done = false;
    for (final site in entry.value) {
      if (done) break;
      final icons = await _iconsOf(site);
      if (icons.isEmpty) {
        stdout.writeln('  $site : aucune icône trouvée');
        continue;
      }
      for (final icon in icons) {
        final bytes = await _get(icon);
        if (bytes == null || bytes.length < 500) continue;
        // En dessous de 128 px, agrandir à 256 donnerait une bouillie pire
        // que le logotype qu'on cherche à remplacer.
        final side = _pngSide(bytes);
        if (side != null && side < 128) {
          stdout.writeln('  (ignoré, ${side}px) $icon');
          continue;
        }
        final ext = _extensionOf(icon, bytes);
        final file = File('${outDir.path}/${entry.key}$ext');
        file.writeAsBytesSync(bytes);
        stdout.writeln('  -> ${file.path}  (${bytes.length} o)  $icon');
        done = true;
        break;
      }
    }
    if (!done) stdout.writeln('  ÉCHEC : rien de récupérable');
  }
  stdout.writeln('\nRegardez tool/icons_recuperees/ avant de remplacer quoi que ce soit.');
}

/// URL des icônes déclarées par la page, la plus grande d'abord.
///
/// Le manifeste web est la meilleure piste : les sites y déclarent des icônes
/// de 192 et 512 px, là où les balises `<link>` pointent souvent sur un
/// favicon de 32 px, inutilisable à 256.
Future<List<String>> _iconsOf(String site) async {
  final bytes = await _get(site);
  if (bytes == null) return const [];
  final html = utf8.decode(bytes, allowMalformed: true);

  final found = <int, String>{};

  final manifest = RegExp(
    r'''<link[^>]*rel\s*=\s*["']manifest["'][^>]*>''',
    caseSensitive: false,
  ).firstMatch(html)?.group(0);
  if (manifest != null) {
    final href = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(manifest)?.group(1);
    if (href != null) {
      final url = Uri.parse(site).resolve(href);
      final raw = await _get(url.toString());
      if (raw != null) {
        try {
          final icons =
              (jsonDecode(utf8.decode(raw, allowMalformed: true))
                      as Map<String, dynamic>)['icons']
                  as List<dynamic>?;
          for (final icon in icons ?? const []) {
            final map = icon as Map<String, dynamic>;
            final src = map['src'] as String?;
            if (src == null) continue;
            final size =
                int.tryParse(
                  (map['sizes'] as String? ?? '').split('x').first,
                ) ??
                0;
            found[size] = url.resolve(src).toString();
          }
        } catch (_) {
          // manifeste illisible : on se rabat sur les balises <link>
        }
      }
    }
  }
  final linkTag = RegExp(r'<link\b[^>]*>', caseSensitive: false);
  for (final tag in linkTag.allMatches(html).map((m) => m.group(0)!)) {
    final rel = RegExp(
      r'''rel\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1)?.toLowerCase();
    if (rel == null || !rel.contains('icon')) continue;
    if (rel.contains('mask-icon')) continue; // SVG monochrome, inutilisable
    final href = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1);
    if (href == null) continue;
    final sizes = RegExp(
      r'''sizes\s*=\s*["'](\d+)x\d+["']''',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1);
    // Une apple-touch-icon sans taille déclarée fait 180 px par convention.
    final size = int.tryParse(sizes ?? '') ??
        (rel.contains('apple') ? 180 : 32);
    found[size] = Uri.parse(site).resolve(href).toString();
  }

  final sizes = found.keys.toList()..sort((a, b) => b.compareTo(a));
  final urls = [for (final s in sizes) found[s]!];
  // Repli : chemins conventionnels, du plus grand au plus petit.
  for (final path in const [
    '/android-chrome-512x512.png',
    '/icon-512x512.png',
    '/android-chrome-192x192.png',
    '/apple-touch-icon.png',
    '/favicon.ico',
  ]) {
    urls.add(Uri.parse(site).resolve(path).toString());
  }
  return urls;
}

Future<List<int>?> _get(String url) async {
  try {
    final r = await http
        .get(Uri.parse(url), headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 25));
    return r.statusCode == 200 ? r.bodyBytes : null;
  } catch (_) {
    return null;
  }
}

/// Côté d'un PNG, lu dans son en-tête IHDR. Null si ce n'est pas un PNG.
int? _pngSide(List<int> b) {
  if (b.length < 24 || b[0] != 0x89 || b[1] != 0x50) return null;
  final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
  final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
  return w < h ? w : h;
}

String _extensionOf(String url, List<int> bytes) {
  if (bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E) {
    return '.png';
  }
  if (bytes.length > 4 && bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01) {
    return '.ico';
  }
  if (url.toLowerCase().contains('.svg')) return '.svg';
  return '.bin';
}
