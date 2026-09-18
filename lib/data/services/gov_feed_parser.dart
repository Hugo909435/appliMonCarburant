import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/utils/dep_utils.dart';

/// Parses the government open-data feed (a ZIP containing one ISO-8859-1
/// encoded XML file) into plain JSON-able maps.
///
/// Runs inside a background isolate via [compute] — must stay a top-level
/// function and only use isolate-safe (non-Flutter) types.
List<Map<String, dynamic>> parseGovFeed(Uint8List zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final xmlFile = archive.files.firstWhere(
    (f) => f.name.toLowerCase().endsWith('.xml'),
  );
  final bytes = xmlFile.content as List<int>;
  final xmlText = latin1.decode(bytes);

  final doc = XmlDocument.parse(xmlText);
  final stations = <Map<String, dynamic>>[];

  for (final pdv in doc.findAllElements('pdv')) {
    final cp = (pdv.getAttribute('cp') ?? '').padLeft(5, '0');
    final dep = depFromCp(cp);
    if (dep == null) continue;

    final latRaw = double.tryParse(pdv.getAttribute('latitude') ?? '');
    final lngRaw = double.tryParse(pdv.getAttribute('longitude') ?? '');
    if (latRaw == null || lngRaw == null || latRaw == 0 || lngRaw == 0) {
      continue;
    }
    final lat = latRaw / 100000;
    final lng = lngRaw / 100000;

    final ville = _cleanText(pdv.getElement('ville')?.innerText);
    if (ville == null || ville.isEmpty) continue;
    final villeSlug = slugifyCity(ville);
    final adresse = _cleanText(pdv.getElement('adresse')?.innerText) ?? '';

    // Ruptures de stock en cours (fin == "" => toujours en rupture).
    final ruptures = <String>{};
    for (final r in pdv.findElements('rupture')) {
      if ((r.getAttribute('fin') ?? '').isEmpty) {
        final nom = r.getAttribute('nom');
        if (nom != null) ruptures.add(nom);
      }
    }

    final prices = <String, double>{};
    final priceUpdates = <String, String>{};
    for (final p in pdv.findElements('prix')) {
      final nom = p.getAttribute('nom');
      if (nom == null || ruptures.contains(nom)) continue;
      final valeur = double.tryParse(p.getAttribute('valeur') ?? '');
      if (valeur == null || valeur <= 0) continue;
      prices[nom] = double.parse(valeur.toStringAsFixed(3));
      priceUpdates[nom] = p.getAttribute('maj') ?? '';
    }
    if (prices.isEmpty) continue;

    final services = <String>[];
    final servicesEl = pdv.getElement('services');
    if (servicesEl != null) {
      for (final s in servicesEl.findElements('service')) {
        final text = s.innerText.trim();
        if (text.isNotEmpty) services.add(text);
      }
    }

    final horairesEl = pdv.getElement('horaires');
    final automate = horairesEl?.getAttribute('automate-24-24') == '1';
    final horaires = _parseHoraires(horairesEl);

    final pop = pdv.getAttribute('pop') == 'A' ? 'autoroute' : 'route';
    final highway = pop == 'autoroute' ? extractHighway(adresse) : null;

    stations.add({
      'id': pdv.getAttribute('id') ?? '',
      'cp': cp,
      'dep': dep,
      'ville': ville,
      '_villeSlug': villeSlug,
      'adresse': adresse,
      'lat': lat,
      'lng': lng,
      'pop': pop,
      'prices': prices,
      'priceUpdates': priceUpdates,
      'services': services,
      'horaires': horaires,
      'automate': automate,
      'highway': highway,
    });
  }

  _resolveCityNames(stations);

  return stations;
}

/// Same commune often appears under several spellings across its stations
/// ("BOURG-EN-BRESSE", "Bourg en Bresse", "NIMES" vs "Nîmes"): for each
/// group of stations sharing the same slug, keep whichever raw variant
/// carries the most accents/hyphens/apostrophes (ties broken by frequency,
/// then alphabetically), title-case it, and apply it to every station in
/// the group.
void _resolveCityNames(List<Map<String, dynamic>> stations) {
  final variantCounts = <String, Map<String, int>>{};
  for (final s in stations) {
    final slug = s['_villeSlug'] as String;
    final raw = s['ville'] as String;
    final counts = variantCounts.putIfAbsent(slug, () => {});
    counts[raw] = (counts[raw] ?? 0) + 1;
  }

  final resolvedNames = <String, String>{};
  for (final entry in variantCounts.entries) {
    final variants = entry.value.entries.toList()
      ..sort((a, b) {
        final scoreDiff = _scoreVariant(b.key) - _scoreVariant(a.key);
        if (scoreDiff != 0) return scoreDiff;
        final countDiff = b.value - a.value;
        if (countDiff != 0) return countDiff;
        return a.key.compareTo(b.key);
      });
    resolvedNames[entry.key] = _titleCaseCity(variants.first.key);
  }

  for (final s in stations) {
    final slug = s.remove('_villeSlug') as String;
    s['ville'] = resolvedNames[slug]!;
  }
}

int _scoreVariant(String v) {
  final accents = RegExp(r'[À-ÖØ-öø-ÿ]').allMatches(v).length * 10;
  final hyphens = RegExp('-').allMatches(v).length * 5;
  final apostrophes = RegExp(r"['’]").allMatches(v).length * 5;
  return accents + hyphens + apostrophes;
}

const _accentFold = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// URL-safe, accent-free identifier for a commune name, used only to group
/// stations that refer to the same city under different spellings.
String slugifyCity(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentFold[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String? _cleanText(String? raw) {
  if (raw == null) return null;
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _particules = {
  'de',
  'du',
  'des',
  'd',
  'la',
  'le',
  'les',
  'l',
  'sur',
  'sous',
  'en',
  'et',
  'au',
  'aux',
  'lès',
  'lez',
  'sainte-',
  'a',
  'à',
  'the',
};

/// Presentable case for city names: the feed ships a mix of ALL CAPS and
/// mixed case. "MONTREAL du GERS" -> "Montreal du Gers".
///
/// Capitalizes each run of letters/digits in place and leaves separators
/// (spaces, hyphens, apostrophes) untouched — unlike JavaScript, Dart's
/// `String.split` with a capturing-group RegExp does NOT return the
/// separators alongside the parts, so rebuilding the string that way here
/// silently drops every space and hyphen ("Neuville-sur-Ain" becomes
/// "NeuvillesurAin"). `replaceAllMapped` avoids the problem entirely.
String _titleCaseCity(String raw) {
  final lower = raw.toLowerCase();
  var wordIndex = 0;
  return lower.replaceAllMapped(RegExp(r"[^\s\-'’]+"), (match) {
    final word = match.group(0)!;
    final isFirst = wordIndex == 0;
    wordIndex++;
    if (!isFirst && _particules.contains(word)) return word;
    return word[0].toUpperCase() + word.substring(1);
  });
}

String _normalizeHeure(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final m = RegExp(r'^(\d{1,2})[.:h]?(\d{2})?$')
      .firstMatch(raw.trim().replaceAll(',', '.'));
  if (m == null) return '';
  final h = int.parse(m.group(1)!);
  final min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
  if (h < 0 || h > 24 || min < 0 || min > 59) return '';
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

/// 7 entries (Mon..Sun): "07:00-20:00" style slot list, "F" if closed, or
/// null if the station declares nothing for that day.
List<String?>? _parseHoraires(XmlElement? horairesEl) {
  if (horairesEl == null) return null;
  final jours = horairesEl.findElements('jour').toList();
  if (jours.isEmpty) return null;

  final out = List<String?>.filled(7, null);
  var hasContent = false;

  for (final j in jours) {
    final id = int.tryParse(j.getAttribute('id') ?? '');
    if (id == null || id < 1 || id > 7) continue;

    if (j.getAttribute('ferme') == '1') {
      out[id - 1] = 'F';
      hasContent = true;
      continue;
    }

    final slots = <String>[];
    for (final h in j.findElements('horaire')) {
      final open = _normalizeHeure(h.getAttribute('ouverture'));
      final close = _normalizeHeure(h.getAttribute('fermeture'));
      if (open.isNotEmpty && close.isNotEmpty) slots.add('$open-$close');
    }
    if (slots.isNotEmpty) {
      out[id - 1] = slots.join(',');
      hasContent = true;
    }
  }

  return hasContent ? out : null;
}
