/// Recognizes fuel station brands from OpenStreetMap `brand` / `name` tags.
///
/// Pure Dart (no Flutter import) so the offline brand builder in `tool/`
/// can use it; colors and display live in brand_catalog.dart.
library;

class _Rule {
  const _Rule(this.key, this.patterns, {this.exact = const []});
  final String key;

  /// Whole words/phrases searched in the normalized value.
  final List<String> patterns;

  /// Values that only count when they are the entire string (e.g. "U").
  final List<String> exact;
}

/// Order matters: the first match wins.
const _rules = [
  _Rule('totalenergies', [
    'totalenergies',
    'total energies',
    'total access',
    'total',
  ]),
  _Rule('leclerc', ['leclerc']),
  _Rule('ecomarche', ['ecomarche']),
  _Rule('intermarche', ['intermarche', 'itm']),
  _Rule('carrefour', ['carrefour']),
  _Rule(
    'systemeu',
    ['systeme u', 'super u', 'hyper u', 'u express', 'station u', 'magasins u'],
    exact: ['u'],
  ),
  _Rule('auchan', ['auchan']),
  _Rule('esso', ['esso']),
  _Rule('bp', ['bp']),
  _Rule('shell', ['shell']),
  _Rule('avia', ['avia']),
  _Rule('dyneff', ['dyneff']),
  _Rule('casino', ['casino', 'geant']),
  _Rule('netto', ['netto']),
  _Rule('eni', ['eni', 'agip']),
  _Rule('cora', ['cora']),
  _Rule('colruyt', ['colruyt']),
  _Rule('vito', ['vito']),
  _Rule('elan', ['elan']),
  _Rule('spar', ['spar']),
];

/// Values mappers use to say "no brand".
const _noBrand = {
  'independent',
  'independant',
  'sans enseigne',
  'none',
  'no',
  'aucune',
};

/// Prefix of keys for brands outside the catalog: `other:<name as tagged>`.
const kOtherBrandPrefix = 'other:';

/// Brand key for an OSM `brand` (or, failing that, `name`) value: a
/// catalog key such as "leclerc", `other:<value>` for an unknown value of
/// the `brand` tag ([isBrandTag]), or null. A bare unknown `name` is
/// ignored: it's usually just "Station service".
String? brandKeyFor(String raw, {required bool isBrandTag}) {
  final norm = normalizeBrandText(raw);
  if (norm.isEmpty || _noBrand.contains(norm)) return null;
  // Padding with spaces turns "contains a whole word" into a plain
  // substring test: " total " matches "total access" but not "totalement".
  final padded = ' $norm ';
  for (final r in _rules) {
    if (r.exact.contains(norm)) return r.key;
    for (final p in r.patterns) {
      if (padded.contains(' $p ')) return r.key;
    }
  }
  return isBrandTag ? '$kOtherBrandPrefix${raw.trim()}' : null;
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
};

/// Lowercase, accent-free, words separated by single spaces.
String normalizeBrandText(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
