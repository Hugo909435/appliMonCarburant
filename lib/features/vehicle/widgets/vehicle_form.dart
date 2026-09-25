import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fuel_colors.dart';
import '../../../data/models/fuel_type.dart';
import '../../../providers/filters_provider.dart';
import '../../../providers/vehicle_provider.dart';

/// Carburant, consommation et taille du plein, enregistrés à chaque
/// changement. Partagé par l'écran « Mon véhicule » et l'accueil.
class VehicleForm extends ConsumerWidget {
  const VehicleForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
    final notifier = ref.read(vehicleProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carburant',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final fuel in FuelType.values)
                      _FuelChoice(
                        fuel: fuel,
                        selected: fuel == profile.fuel,
                        onTap: () {
                          notifier.save(profile.copyWith(fuel: fuel));
                          // La carte suit la voiture.
                          ref.read(selectedFuelProvider.notifier).state = fuel;
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              children: [
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
                  onChanged: (v) =>
                      notifier.save(profile.copyWith(fillLiters: v)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(1).replaceFirst('.', ',');
}

/// Pastille d'un carburant, à la couleur de son pistolet une fois choisie.
class _FuelChoice extends StatelessWidget {
  const _FuelChoice({
    required this.fuel,
    required this.selected,
    required this.onTap,
  });

  final FuelType fuel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? fuel.color : scheme.surfaceContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: fuel.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  fuel.label,
                  style: TextStyle(
                    color: selected ? Colors.white : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
