class FuelStat {
  const FuelStat({
    required this.avg,
    required this.min,
    required this.max,
    required this.count,
  });

  final double avg;
  final double min;
  final double max;
  final int count;

  static FuelStat? fromPrices(Iterable<double> prices) {
    final list = prices.where((p) => p > 0).toList();
    if (list.isEmpty) return null;
    final sum = list.fold<double>(0, (a, b) => a + b);
    return FuelStat(
      avg: double.parse((sum / list.length).toStringAsFixed(3)),
      min: list.reduce((a, b) => a < b ? a : b),
      max: list.reduce((a, b) => a > b ? a : b),
      count: list.length,
    );
  }
}
