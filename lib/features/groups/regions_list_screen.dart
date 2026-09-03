import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/station.dart';
import '../../providers/stations_provider.dart';

class RegionsListScreen extends ConsumerWidget {
  const RegionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsDataProvider);
    final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];

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
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final count = counts[entry.key] ?? 0;
              return ListTile(
                title: Text(entry.value),
                trailing: Text('$count stations'),
                onTap: () => context.push('/region/${entry.key}', extra: entry.value),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
      ),
    );
  }
}
