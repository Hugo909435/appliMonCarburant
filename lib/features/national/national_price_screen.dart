import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/price_history_service.dart';
import '../../providers/stations_provider.dart' show priceHistoryServiceProvider;
import '../../providers/stats_provider.dart';
import '../../shared/widgets/fuel_selector.dart';
import '../../shared/widgets/stats_summary_card.dart';
import '../../providers/filters_provider.dart';

final _priceHistoryProvider = FutureProvider<List<PriceHistoryPoint>>((ref) {
  return ref.watch(priceHistoryServiceProvider).load();
});

class NationalPriceScreen extends ConsumerWidget {
  const NationalPriceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(nationalStatsProvider);
    final historyAsync = ref.watch(_priceHistoryProvider);
    final fuel = ref.watch(selectedFuelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prix moyen en France')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatsSummaryCard(stats: stats),
          const SizedBox(height: 24),
          Text('Tendance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Historique constitué localement depuis l'installation de l'app "
            '(un point par jour).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const FuelSelector(),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (points) {
              final withFuel = points.where((p) => p.prices.containsKey(fuel.code)).toList();
              if (withFuel.length < 2) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      "Pas encore assez de données pour tracer une tendance.\n"
                      'Revenez dans quelques jours.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: AppColors.accent,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        spots: [
                          for (var i = 0; i < withFuel.length; i++)
                            FlSpot(i.toDouble(), withFuel[i].prices[fuel.code]!),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => const Text("Impossible de charger l'historique des prix."),
          ),
        ],
      ),
    );
  }
}
