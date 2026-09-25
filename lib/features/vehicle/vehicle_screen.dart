import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/fill_cost.dart';
import '../../core/utils/formatters.dart';
import '../../providers/vehicle_provider.dart';
import 'widgets/vehicle_form.dart';

class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            'Ces réglages choisissent le carburant affiché sur la carte et '
            "servent à calculer le coût réel d'un plein, trajet jusqu'à la "
            'station compris.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          const VehicleForm(),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
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
}
