import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/platform_support.dart';
import '../data/services/favorites_service.dart';
import '../data/services/firestore_favorites_service.dart';
import 'auth_provider.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  if (isWindowsDesktop) return LocalFavoritesService();
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return LocalFavoritesService();
  return FirestoreFavoritesService(user.uid);
});

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  // Guards the one-time upload of pre-existing local favorites into a user's
  // new Firestore doc, so it never re-runs and resurrects favorites the user
  // deliberately cleared from the cloud afterwards.
  static const _migratedKey = 'favorites_migrated_v1';

  @override
  Future<Set<String>> build() async {
    final service = ref.watch(favoritesServiceProvider);
    if (service is FirestoreFavoritesService) {
      return _loadWithMigration(service);
    }
    return service.load();
  }

  Future<Set<String>> _loadWithMigration(
    FirestoreFavoritesService service,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    final remote = await service.load();
    if (alreadyMigrated) return remote;

    await prefs.setBool(_migratedKey, true);
    final local = await LocalFavoritesService().load();
    if (local.isEmpty) return remote;

    final merged = {...remote, ...local};
    await service.save(merged);
    return merged;
  }

  Future<void> toggle(String stationId) async {
    final current = state.valueOrNull ?? <String>{};
    final updated = {...current};
    if (!updated.remove(stationId)) updated.add(stationId);
    state = AsyncData(updated);
    await ref.read(favoritesServiceProvider).save(updated);
  }

  bool isFavorite(String stationId) =>
      (state.valueOrNull ?? const {}).contains(stationId);
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
