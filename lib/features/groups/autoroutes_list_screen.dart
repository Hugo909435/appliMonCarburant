import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/derived_providers.dart';

class AutoroutesListScreen extends ConsumerWidget {
  const AutoroutesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highways = ref.watch(autoroutesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Autoroutes')),
      body: highways.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: highways.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hw = highways[index];
                return ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(hw.code),
                  trailing: Text('${hw.count} stations'),
                  onTap: () => context.push('/autoroute/${hw.code}', extra: hw.code),
                );
              },
            ),
    );
  }
}
