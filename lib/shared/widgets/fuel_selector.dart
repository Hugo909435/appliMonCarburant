import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/fuel_colors.dart';
import '../../data/models/fuel_type.dart';
import '../../providers/filters_provider.dart';

/// Horizontal row of fuel-type pills, color-coded like the labels on a
/// pump nozzle so drivers can match a fuel to a color at a glance.
class FuelSelector extends ConsumerWidget {
  const FuelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFuelProvider);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FuelType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final fuel = FuelType.values[index];
          final isSelected = fuel == selected;
          final color = fuel.color;
          return _FuelPill(
            label: fuel.code,
            color: color,
            isSelected: isSelected,
            onTap: () => ref.read(selectedFuelProvider.notifier).state = fuel,
          );
        },
      ),
    );
  }
}

class _FuelPill extends StatelessWidget {
  const _FuelPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Pleines et sans contour, comme les filtres de la carte : seule la
    // pastille choisie prend la couleur de son carburant.
    return Material(
      color: isSelected ? color : scheme.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSelected)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
