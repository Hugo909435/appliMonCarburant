import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/derived_providers.dart';
import '../../shared/widgets/ad_slot.dart';

class AutoroutesListScreen extends ConsumerWidget {
  const AutoroutesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highways = ref.watch(autoroutesListProvider);
    // Une liste où l'on cherche une ligne précise : annonces espacées.
    final ads = InFeedAds(highways.length, first: 5, every: 20);

    return Scaffold(
      appBar: AppBar(title: const Text('Autoroutes')),
      body: highways.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: ads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (ads.isAd(index)) return const AdSlot();
                final hw = highways[ads.itemIndex(index)];
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    leading: const Icon(Icons.route_outlined),
                    title: Text(
                      hw.code,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      '${hw.count} stations',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () =>
                        context.push('/autoroute/${hw.code}', extra: hw.code),
                  ),
                );
              },
            ),
    );
  }
}
