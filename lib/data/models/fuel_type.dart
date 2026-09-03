enum FuelType {
  gazole('Gazole', 'Gazole'),
  sp95('SP95', 'Sans-Plomb 95'),
  sp98('SP98', 'Sans-Plomb 98'),
  e10('E10', 'E10 (SP95-E10)'),
  e85('E85', 'E85 (Bioéthanol)'),
  gplc('GPLc', 'GPL');

  const FuelType(this.code, this.label);

  /// Code used by the government feed (`prix nom="..."`).
  final String code;
  final String label;

  static FuelType? fromCode(String code) {
    for (final f in FuelType.values) {
      if (f.code == code) return f;
    }
    return null;
  }
}
