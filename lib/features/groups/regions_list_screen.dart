import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/station.dart';
import '../../providers/stations_provider.dart';

class RegionsListScreen extends ConsumerWidget {
  const RegionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsDataProvider);
    final stations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Régions')),
      body: departmentsAsync.when(
        data: (departments) {
          final regions = <String, String>{}; // slug -> name
          for (final dept in departments.values) {
            regions[dept.regionSlug] = dept.region;
          }
          final counts = <String, int>{};
          for (final s in stations) {
            final dept = departments[s.dep];
            if (dept == null) continue;
            counts[dept.regionSlug] = (counts[dept.regionSlug] ?? 0) + 1;
          }

          final entries = regions.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final count = counts[entry.key] ?? 0;
              return Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: const Icon(
                    Icons.terrain_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    '$count stations',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () =>
                      context.push('/region/${entry.key}', extra: entry.value),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            const Center(child: Text('Impossible de charger les régions.')),
      ),
    );
  }
}
