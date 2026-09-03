import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/fuel_type.dart';
import '../../providers/filters_provider.dart';

class FuelSelector extends ConsumerWidget {
  const FuelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFuelProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final fuel in FuelType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(fuel.code),
                selected: selected == fuel,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: selected == fuel ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => ref.read(selectedFuelProvider.notifier).state = fuel,
              ),
            ),
        ],
      ),
    );
  }
}
