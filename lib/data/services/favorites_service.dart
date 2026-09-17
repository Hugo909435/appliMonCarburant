import 'package:shared_preferences/shared_preferences.dart';

abstract class FavoritesService {
  Future<Set<String>> load();
  Future<void> save(Set<String> ids);
}

class LocalFavoritesService implements FavoritesService {
  static const _key = 'favorite_station_ids';

  @override
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  @override
  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}
