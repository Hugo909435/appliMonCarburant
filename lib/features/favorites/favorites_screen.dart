import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/platform_support.dart';
import '../../data/models/station.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/stations_provider.dart';
import '../../shared/widgets/station_list_screen.dart';
import 'widgets/account_button.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds =
        ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final stations =
        ref.watch(stationsProvider).valueOrNull ?? const <Station>[];
    final favorites = stations
        .where((s) => favoriteIds.contains(s.id))
        .toList();

    final user = ref.watch(currentUserProvider).valueOrNull;
    final isLinked = ref.read(authServiceProvider).isLinkedWithGoogle(user);

    return StationListScreen(
      title: 'Mes favoris',
      stations: favorites,
      emptyMessage: "Aucun favori pour l'instant.\nAppuyez sur l'étoile d'une station pour l'ajouter.",
      appBarActions: isWindowsDesktop ? null : const [AccountButton()],
      banner: isLinked ? null : _SignInReminder(onTap: () => context.push('/compte')),
    );
  }
}

class _SignInReminder extends StatelessWidget {
  const _SignInReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connectez-vous pour ne pas perdre vos favoris.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
