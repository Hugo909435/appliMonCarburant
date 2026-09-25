import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/brands/brand_catalog.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/price_deals.dart';
import '../models/fuel_type.dart';
import '../models/station.dart';
import 'notification_service.dart';

/// Alertes « votre carburant est bien moins cher que d'habitude dans une
/// station favorite » (voir [findPriceDeals] pour la règle).
///
/// À chaque téléchargement du flux, que ce soit app ouverte
/// ([StationsNotifier]) ou par la tâche de fond (`price_alert_task.dart`),
/// on relève le prix des favoris et on le compare à leur habitude.
///
/// Tout passe par [SharedPreferencesAsync], qui ne garde rien en mémoire :
/// la tâche de fond tourne dans un autre isolate, et le cache de
/// [SharedPreferences] ferait lire à l'app un historique périmé, donc la
/// même bonne affaire signalée deux fois.
class PriceAlertService {
  PriceAlertService({
    SharedPreferencesAsync? prefs,
    NotificationService? notifier,
  }) : _injectedPrefs = prefs,
       _notifier = notifier ?? NotificationService.instance;

  static const _enabledKey = 'price_alerts_enabled';
  static const _favoritesKey = 'price_alerts_favorite_ids';
  static const _fuelKey = 'price_alerts_fuel';
  static const _historyKey = 'price_alerts_history';
  static const _lastNotifiedKey = 'price_alerts_last_notified_day';

  /// Id fixe : une nouvelle alerte remplace la précédente plutôt que de
  /// s'empiler dans le centre de notifications.
  static const _notificationId = 1;

  final SharedPreferencesAsync? _injectedPrefs;

  /// Créé au premier usage : le constructeur échoue là où le stockage n'a
  /// pas d'implémentation (tests), et l'app doit démarrer quand même.
  late final SharedPreferencesAsync _prefs =
      _injectedPrefs ?? SharedPreferencesAsync();
  final NotificationService _notifier;

  Future<bool> isEnabled() async => await _prefs.getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool enabled) async =>
      _prefs.setBool(_enabledKey, enabled);

  /// Copie locale des favoris et du carburant suivi : la tâche de fond n'a
  /// ni Firebase ni Riverpod pour les retrouver (favoris d'un compte
  /// connecté, rangés dans Firestore).
  Future<void> syncFavorites(Set<String> ids) async =>
      _prefs.setStringList(_favoritesKey, ids.toList());

  Future<void> syncFuel(FuelType fuel) async =>
      _prefs.setString(_fuelKey, fuel.code);

  /// Relève le prix des favoris dans [stations], notifie les nouvelles
  /// bonnes affaires si les alertes sont actives (une notification par jour
  /// au plus), et renvoie les bonnes affaires trouvées.
  Future<List<PriceDeal>> check(List<Station> stations, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final favorites = (await _prefs.getStringList(_favoritesKey) ?? const [])
        .toSet();
    final fuel =
        FuelType.fromCode(await _prefs.getString(_fuelKey) ?? '') ??
        FuelType.gazole;

    final current = <String, double>{
      for (final s in stations)
        if (favorites.contains(s.id) && s.prices[fuel.code] != null)
          s.id: s.prices[fuel.code]!,
    };

    final stored = _readHistory(await _prefs.getString(_historyKey));
    // Changement de carburant : l'habitude de l'ancien ne vaut rien pour le
    // nouveau, on repart de zéro.
    final history = stored.fuel == fuel.code
        ? stored.history
        : const FavoritePriceHistory();
    final enabled = await isEnabled();
    final alreadyNotifiedToday =
        await _prefs.getString(_lastNotifiedKey) == dayKey(today);

    final result = findPriceDeals(
      history: history,
      current: current,
      favorites: favorites,
      today: today,
      notify: enabled && !alreadyNotifiedToday,
    );
    await _prefs.setString(
      _historyKey,
      jsonEncode({'fuel': fuel.code, ...result.history.toJson()}),
    );

    final deals = result.deals;
    if (deals.isNotEmpty) {
      final byId = {for (final s in stations) s.id: s};
      final names = await _stationNames(deals, byId);
      await _notifier.show(
        id: _notificationId,
        title: _title(deals, fuel),
        body: _body(deals, names),
      );
      await _prefs.setString(_lastNotifiedKey, dayKey(today));
    }
    return deals;
  }

  static ({String? fuel, FavoritePriceHistory history}) _readHistory(
    String? raw,
  ) {
    if (raw == null) return (fuel: null, history: const FavoritePriceHistory());
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        fuel: json['fuel'] as String?,
        history: FavoritePriceHistory.fromJson(json),
      );
    } catch (_) {
      return (fuel: null, history: const FavoritePriceHistory());
    }
  }

  /// « Total, Lyon » quand l'enseigne est connue, sinon l'adresse.
  static Future<Map<String, String>> _stationNames(
    List<PriceDeal> deals,
    Map<String, Station> byId,
  ) async {
    Map<String, dynamic> brands = const {};
    try {
      brands = jsonDecode(
        await rootBundle.loadString('assets/data/station_brands.json'),
      ) as Map<String, dynamic>;
    } catch (_) {
      // Sans enseigne, l'adresse suffit à reconnaître la station.
    }
    return {
      for (final deal in deals)
        deal.stationId: _stationName(
          byId[deal.stationId],
          brandForKey(brands[deal.stationId] as String? ?? '')?.name,
        ),
    };
  }

  static String _stationName(Station? station, String? brand) {
    if (station == null) return 'Station favorite';
    // Déjà mis en forme par le lecteur du flux (« Aix-en-Provence ») : le
    // repasser en minuscules casserait tirets, accents et particules.
    final city = station.ville;
    return brand != null ? '$brand, $city' : '${station.adresse}, $city';
  }

  static String _cents(double euros) => '${(euros * 100).round()} cts';

  static String _title(List<PriceDeal> deals, FuelType fuel) =>
      deals.length == 1
      ? '${fuel.code} : -${_cents(deals.first.saving)} par rapport '
            'à d’habitude'
      : '${fuel.code} moins cher que d’habitude dans ${deals.length} '
            'stations favorites';

  static String _body(List<PriceDeal> deals, Map<String, String> names) => deals
      .map(
        (d) =>
            '${names[d.stationId]} : ${formatPrice(d.price)}/L '
            '(${formatPrice(d.usualPrice)} d’habitude)',
      )
      .join('\n');
}
