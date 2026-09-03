/// Extracts a French department number (e.g. "01", "2A", "971") from a
/// 5-digit postal code, mirroring the government open-data convention.
String? depFromCp(String? cp) {
  if (cp == null || cp.isEmpty) return null;
  final str = cp.padLeft(5, '0');
  if (str.startsWith('97')) return str.substring(0, 3);
  if (str.startsWith('20')) {
    final num = int.tryParse(str.substring(2)) ?? 0;
    return num < 200 ? '2A' : '2B';
  }
  return str.substring(0, 2);
}

/// Extracts a highway number (e.g. "A6", "A75") from a station address,
/// only meaningful for stations flagged as `pop == 'autoroute'`.
String? extractHighway(String? adresse) {
  if (adresse == null || adresse.isEmpty) return null;
  final withA = RegExp(r'\bA[\s-]?(\d{1,3})(?!\d)', caseSensitive: false).firstMatch(adresse);
  if (withA != null) return 'A${withA.group(1)}';
  final spelled = RegExp(r'\bAUTOROUTE\s+(\d{1,3})\b', caseSensitive: false).firstMatch(adresse);
  if (spelled != null) return 'A${spelled.group(1)}';
  return null;
}
