import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/platform_support.dart';
import '../../data/models/station.dart';
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

    return StationListScreen(
      title: 'Mes favoris',
      stations: favorites,
      emptyMessage: "Aucun favori pour l'instant.\nAppuyez sur l'étoile d'une station pour l'ajouter.",
      appBarActions: isWindowsDesktop ? null : const [AccountButton()],
    );
  }
}
