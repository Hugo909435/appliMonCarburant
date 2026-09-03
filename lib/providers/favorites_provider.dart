import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/favorites_service.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) => FavoritesService());

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(favoritesServiceProvider).load();

  Future<void> toggle(String stationId) async {
    final current = state.valueOrNull ?? <String>{};
    final updated = {...current};
    if (!updated.remove(stationId)) updated.add(stationId);
    state = AsyncData(updated);
    await ref.read(favoritesServiceProvider).save(updated);
  }

  bool isFavorite(String stationId) => (state.valueOrNull ?? const {}).contains(stationId);
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
