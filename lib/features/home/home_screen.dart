import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/fuel_type.dart';
import '../../providers/derived_providers.dart';
import '../../providers/filters_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stations_provider.dart';
import '../../providers/stats_provider.dart';
import '../../shared/widgets/stats_summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    context.push('/search?q=${Uri.encodeComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);
    final lastUpdate = ref.watch(lastUpdateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Carburant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Favoris',
            onPressed: () => context.push('/favoris'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(stationsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SearchCard(controller: _searchController, onSearch: _search),
            const SizedBox(height: 16),
            _NearMeButton(),
            const SizedBox(height: 24),
            stationsAsync.when(
              data: (stations) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Prix moyen en France', style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.push('/national'),
                        child: const Text('Détails'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatsSummaryCard(stats: ref.watch(nationalStatsProvider)),
                  if (lastUpdate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Données mises à jour ${formatRelativeDate(lastUpdate)} · ${stations.length} stations',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _ErrorCard(
                message: 'Impossible de charger les prix carburant.',
                onRetry: () => ref.read(stationsProvider.notifier).refresh(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Explorer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ShortcutGrid(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/carte'),
        icon: const Icon(Icons.map),
        label: const Text('Carte'),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trouver une station', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Code postal ou ville',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
            ),
            const SizedBox(height: 12),
            const _FuelSelectorInline(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSearch,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                child: const Text('Rechercher'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelSelectorInline extends ConsumerWidget {
  const _FuelSelectorInline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFuelProvider);
    return DropdownButtonFormField<FuelType>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Carburant',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final fuel in FuelType.values)
          DropdownMenuItem(value: fuel, child: Text(fuel.label)),
      ],
      onChanged: (value) {
        if (value != null) ref.read(selectedFuelProvider.notifier).state = value;
      },
    );
  }
}

class _NearMeButton extends ConsumerWidget {
  const _NearMeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(userLocationProvider);
    final nearby = ref.watch(nearbyStationsProvider);

    return OutlinedButton.icon(
      onPressed: locationState.isLoading
          ? null
          : () async {
              await ref.read(userLocationProvider.notifier).requestLocation();
              if (nearby.isNotEmpty && context.mounted) context.push('/pres-de-moi');
            },
      icon: locationState.isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location),
      label: const Text('Stations près de moi'),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.map_outlined, 'Départements', '/departements'),
      (Icons.terrain_outlined, 'Régions', '/regions'),
      (Icons.route_outlined, 'Autoroutes', '/autoroutes'),
      (Icons.trending_up, 'Tendance des prix', '/national'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        for (final (icon, label, route) in items)
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => context.push(route),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
