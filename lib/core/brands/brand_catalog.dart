import 'package:flutter/material.dart';

import 'brand_rules.dart';

/// A fuel station brand as displayed: its [key] (see brand_rules.dart, also
/// the name of an optional logo file `assets/logos/<key>.png`) and the
/// colors of the badge drawn when no logo file is provided.
class FuelBrand {
  const FuelBrand({
    required this.key,
    required this.name,
    required this.short,
    required this.background,
    this.foreground = Colors.white,
    this.border,
  });

  final String key;
  final String name;

  /// Text drawn inside the badge (initials or short wordmark).
  final String short;
  final Color background;
  final Color foreground;
  final Color? border;

  bool get isKnown => !key.startsWith(kOtherBrandPrefix);

  @override
  bool operator ==(Object other) => other is FuelBrand && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Main brands of French fuel stations, in their usual colors.
const _catalog = {
  'totalenergies': FuelBrand(
    key: 'totalenergies',
    name: 'TotalEnergies',
    short: 'TE',
    background: Color(0xFFE4002B),
  ),
  'leclerc': FuelBrand(
    key: 'leclerc',
    name: 'E.Leclerc',
    short: 'E.L',
    background: Color(0xFF005BAC),
  ),
  'ecomarche': FuelBrand(
    key: 'ecomarche',
    name: 'Ecomarché',
    short: 'eco',
    background: Color(0xFFE3001B),
  ),
  'intermarche': FuelBrand(
    key: 'intermarche',
    name: 'Intermarché',
    short: 'ITM',
    background: Color(0xFFE3001B),
  ),
  'carrefour': FuelBrand(
    key: 'carrefour',
    name: 'Carrefour',
    short: 'C',
    background: Colors.white,
    foreground: Color(0xFF1E4B9B),
    border: Color(0xFFE1000F),
  ),
  'systemeu': FuelBrand(
    key: 'systemeu',
    name: 'Système U',
    short: 'U',
    background: Color(0xFF1D4F91),
  ),
  'auchan': FuelBrand(
    key: 'auchan',
    name: 'Auchan',
    short: 'A',
    background: Color(0xFFE2001A),
  ),
  'esso': FuelBrand(
    key: 'esso',
    name: 'Esso',
    short: 'Esso',
    background: Colors.white,
    foreground: Color(0xFFE31937),
    border: Color(0xFF0A3D91),
  ),
  'bp': FuelBrand(
    key: 'bp',
    name: 'BP',
    short: 'bp',
    background: Color(0xFF009A44),
    foreground: Color(0xFFFFE600),
  ),
  'shell': FuelBrand(
    key: 'shell',
    name: 'Shell',
    short: 'Shell',
    background: Color(0xFFFFD100),
    foreground: Color(0xFFDD1D21),
  ),
  'avia': FuelBrand(
    key: 'avia',
    name: 'Avia',
    short: 'AVIA',
    background: Color(0xFFE30613),
  ),
  'dyneff': FuelBrand(
    key: 'dyneff',
    name: 'Dyneff',
    short: 'DYN',
    // Rouge du logo : le bleu qui figurait ici n'appartient pas à l'enseigne.
    background: Color(0xFFE52612),
  ),
  'casino': FuelBrand(
    key: 'casino',
    name: 'Casino',
    short: 'CAS',
    background: Color(0xFF009B48),
  ),
  'netto': FuelBrand(
    key: 'netto',
    name: 'Netto',
    short: 'N',
    background: Color(0xFFFFE600),
    foreground: Color(0xFFE2001A),
  ),
  'eni': FuelBrand(
    key: 'eni',
    name: 'Eni',
    short: 'eni',
    background: Color(0xFFFFD100),
    foreground: Colors.black,
  ),
  'cora': FuelBrand(
    key: 'cora',
    name: 'Cora',
    short: 'cora',
    background: Color(0xFFE2001A),
  ),
  'colruyt': FuelBrand(
    key: 'colruyt',
    name: 'Colruyt',
    short: 'COL',
    background: Color(0xFFE30613),
  ),
  'vito': FuelBrand(
    key: 'vito',
    name: 'Vito',
    short: 'VITO',
    background: Color(0xFF0093D0),
  ),
  'elan': FuelBrand(
    key: 'elan',
    name: 'Elan',
    short: 'élan',
    background: Color(0xFF0072BC),
  ),
  'spar': FuelBrand(
    key: 'spar',
    name: 'Spar',
    short: 'SPAR',
    background: Color(0xFF00843D),
  ),
};

const _otherPalette = [
  Color(0xFF546E7A),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
  Color(0xFF00897B),
  Color(0xFF8E24AA),
];

/// Display info for a brand key: the catalog entry, or a neutral badge
/// with the initial for brands outside the catalog.
FuelBrand? brandForKey(String key) {
  final known = _catalog[key];
  if (known != null) return known;
  if (!key.startsWith(kOtherBrandPrefix)) return null;
  final name = key.substring(kOtherBrandPrefix.length).trim();
  if (name.isEmpty) return null;
  return FuelBrand(
    key: key,
    name: name,
    short: name[0].toUpperCase(),
    background:
        _otherPalette[name.codeUnits.fold(0, (a, b) => a + b) %
            _otherPalette.length],
  );
}
