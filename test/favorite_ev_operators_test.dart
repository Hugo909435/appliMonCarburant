import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/data/models/ev_station.dart';
import 'package:mon_carburant_app/providers/filters_provider.dart';
import 'package:mon_carburant_app/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lidl = EvOperator(
  name: 'LIDL France',
  spellings: ['LIDL France', 'Lidl France'],
  pointCount: 10689,
);
const _izivia = EvOperator(
  name: 'IZIVIA',
  spellings: ['IZIVIA'],
  pointCount: 16467,
);

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('un opérateur mis en favori le reste après un redémarrage', () async {
    final first = await _container();
    first.read(favoriteEvOperatorsProvider.notifier).toggle(_lidl);
    expect(
      first.read(favoriteEvOperatorsProvider.notifier).isFavorite(_lidl),
      isTrue,
    );
    await pumpEventQueue();

    final relaunched = await _container();
    final favorites = relaunched.read(favoriteEvOperatorsProvider.notifier);
    expect(favorites.isFavorite(_lidl), isTrue);
    expect(favorites.isFavorite(_izivia), isFalse);
  });

  test('toucher à nouveau l’étoile retire le favori', () async {
    final container = await _container();
    final favorites = container.read(favoriteEvOperatorsProvider.notifier);
    favorites.toggle(_izivia);
    favorites.toggle(_izivia);
    expect(favorites.isFavorite(_izivia), isFalse);
    expect(container.read(favoriteEvOperatorsProvider), isEmpty);
  });
}
