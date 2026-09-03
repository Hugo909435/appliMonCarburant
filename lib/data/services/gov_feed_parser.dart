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
  final xmlFile = archive.files.firstWhere((f) => f.name.toLowerCase().endsWith('.xml'));
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
    if (latRaw == null || lngRaw == null || latRaw == 0 || lngRaw == 0) continue;
    final lat = latRaw / 100000;
    final lng = lngRaw / 100000;

    final ville = _cleanText(pdv.getElement('ville')?.innerText);
    if (ville == null || ville.isEmpty) continue;
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
      'ville': _titleCaseCity(ville),
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

  return stations;
}

String? _cleanText(String? raw) {
  if (raw == null) return null;
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _particules = {
  'de', 'du', 'des', 'd', 'la', 'le', 'les', 'l', 'sur', 'sous', 'en', 'et',
  'au', 'aux', 'lès', 'lez', 'sainte-', 'a', 'à', 'the',
};

/// Presentable case for city names: the feed ships a mix of ALL CAPS and
/// mixed case. "MONTREAL du GERS" -> "Montreal du Gers".
String _titleCaseCity(String raw) {
  final lower = raw.toLowerCase();
  final parts = lower.split(RegExp(r"([\s\-'’])"));
  var wordIndex = 0;
  final out = StringBuffer();
  for (final part in parts) {
    if (part.isEmpty) continue;
    if (RegExp(r"^[\s\-'’]$").hasMatch(part)) {
      out.write(part);
      continue;
    }
    final isFirst = wordIndex == 0;
    wordIndex++;
    if (!isFirst && _particules.contains(part)) {
      out.write(part);
    } else {
      out.write(part[0].toUpperCase() + part.substring(1));
    }
  }
  return out.toString();
}

String _normalizeHeure(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final m = RegExp(r'^(\d{1,2})[.:h]?(\d{2})?$').firstMatch(raw.trim().replaceAll(',', '.'));
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
