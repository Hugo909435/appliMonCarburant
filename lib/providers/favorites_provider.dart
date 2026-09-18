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
  // deliberately cleared from the cloud afterwards. Scoped per uid so that
  // switching accounts on the same device still migrates the new account's
  // local favorites instead of being skipped because a *different* user
  // already migrated once.
  static String _migratedKey(String uid) => 'favorites_migrated_v1_$uid';

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
    final migratedKey = _migratedKey(service.uid);
    final alreadyMigrated = prefs.getBool(migratedKey) ?? false;
    final remote = await service.load();
    if (alreadyMigrated) return remote;

    await prefs.setBool(migratedKey, true);
    final local = await LocalFavoritesService().load();
    if (local.isEmpty) return remote;

    final merged = {...remote, ...local};
    await service.save(merged);
    return merged;
  }

  Future<void> toggle(String stationId) async {
    final previous = state.valueOrNull ?? <String>{};
    final updated = {...previous};
    if (!updated.remove(stationId)) updated.add(stationId);
    state = AsyncData(updated);
    try {
      await ref.read(favoritesServiceProvider).save(updated);
    } catch (_) {
      // Persist failed (offline, permissions, ...): roll back the optimistic
      // update instead of leaving the UI showing a favorite that never made
      // it to storage. Callers invoke this fire-and-forget from onTap, so
      // there's no one to rethrow to.
      if (state.valueOrNull == updated) state = AsyncData(previous);
    }
  }

  bool isFavorite(String stationId) =>
      (state.valueOrNull ?? const {}).contains(stationId);
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
