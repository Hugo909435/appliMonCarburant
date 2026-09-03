import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/station.dart';
import '../../providers/stations_provider.dart';

class DepartmentsListScreen extends ConsumerWidget {
  const DepartmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsDataProvider);
    final stations = ref.watch(stationsProvider).valueOrNull ?? const <Station>[];

    final counts = <String, int>{};
    for (final s in stations) {
      counts[s.dep] = (counts[s.dep] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Départements')),
      body: departmentsAsync.when(
        data: (departments) {
          final entries = departments.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final dept = entries[index];
              final count = counts[dept.num] ?? 0;
              return ListTile(
                title: Text('${dept.name} (${dept.num})'),
                subtitle: Text(dept.region),
                trailing: Text('$count stations'),
                onTap: () => context.push(
                  '/departement/${dept.num}',
                  extra: '${dept.name} (${dept.num})',
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Impossible de charger les départements.')),
      ),
    );
  }
}
