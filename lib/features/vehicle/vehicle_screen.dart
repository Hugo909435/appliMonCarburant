import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/fill_cost.dart';
import '../../core/utils/formatters.dart';
import '../../providers/vehicle_provider.dart';

class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
    final notifier = ref.read(vehicleProvider.notifier);
    final theme = Theme.of(context);
    // Worked example so the user sees what the numbers change.
    final example = computeFillCost(
      pricePerLiter: 1.80,
      liters: profile.fillLiters,
      consumptionL100: profile.consumptionL100,
      detourKm: 5,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mon véhicule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Ces réglages servent à calculer le coût réel d'un plein, trajet "
            "jusqu'à la station compris.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _SliderSetting(
            label: 'Consommation',
            valueLabel: '${_fmt(profile.consumptionL100)} L/100 km',
            value: profile.consumptionL100,
            min: 3,
            max: 15,
            divisions: 24,
            onChanged: (v) =>
                notifier.save(profile.copyWith(consumptionL100: v)),
          ),
          const SizedBox(height: 16),
          _SliderSetting(
            label: 'Quantité habituelle à chaque plein',
            valueLabel: '${profile.fillLiters.round()} L',
            value: profile.fillLiters,
            min: 10,
            max: 90,
            divisions: 16,
            onChanged: (v) => notifier.save(profile.copyWith(fillLiters: v)),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Exemple : une station à 5 km, à 1,80 €/L, vous coûte '
                '${formatEuros(example.tripCost)} de trajet aller-retour '
                '(${example.tripKm.round()} km de route environ), en plus des '
                '${formatEuros(example.fuelCost)} du plein.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(1).replaceFirst('.', ',');
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
