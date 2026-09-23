import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/station.dart';
import '../data/services/geocoding_service.dart';
import 'stations_provider.dart';

/// Injecté plutôt qu'instancié : les écrans qui cherchent une adresse n'ont
/// pas à savoir d'où elle vient, et un test peut substituer le service sans
/// toucher au réseau.
final geocodingServiceProvider = Provider<GeocodingService>(
  (ref) => GeocodingService(),
);

/// Ce que la barre de recherche de la carte sait afficher.
enum SearchHitKind { station, address }

@immutable
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  final SearchHitKind kind;
  final String title;
  final String subtitle;
  final double lat;
  final double lng;
}

@immutable
class MapSearchState {
  const MapSearchState({this.results = const [], this.searching = false});

  final List<SearchHit> results;

  /// Vrai pendant que le géocodeur répond : les stations locales, elles, sont
  /// déjà affichées.
  final bool searching;

  bool get isEmpty => results.isEmpty;
}

/// En deçà, la recherche ramènerait la moitié de la France.
const _minQueryLength = 2;

/// Laisse le temps de finir de taper avant d'appeler le géocodeur, dont les
/// conditions d'utilisation plafonnent le débit.
const _debounce = Duration(milliseconds: 400);

/// Recherche de la carte : stations connues d'abord, adresses ensuite.
///
/// Vit hors du widget pour que l'enchaînement — anti-rebond, résultats locaux
/// immédiats, puis complément distant — soit testable sans monter la carte,
/// et pour que `HomeScreen` n'ait plus qu'à afficher un état.
class MapSearchNotifier extends Notifier<MapSearchState> {
  Timer? _debounceTimer;

  /// Chaque recherche prend un numéro. Une réponse du géocodeur qui revient
  /// après qu'une frappe plus récente est partie porte un numéro périmé et
  /// est jetée : sans ça, une requête lente écraserait un résultat plus
  /// récent.
  int _token = 0;

  @override
  MapSearchState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const MapSearchState();
  }

  void onQueryChanged(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
      clear();
      return;
    }
    _debounceTimer = Timer(_debounce, () => _run(query));
  }

  void clear() {
    _debounceTimer?.cancel();
    _token++;
    state = const MapSearchState();
  }

  Future<void> _run(String query) async {
    final token = ++_token;

    // Les stations sont déjà en mémoire : les afficher tout de suite plutôt
    // que d'attendre le réseau.
    final stations =
        ref.read(stationsProvider).valueOrNull ?? const <Station>[];
    final local = [
      for (final station in matchStations(stations, query))
        SearchHit(
          kind: SearchHitKind.station,
          title: station.ville,
          subtitle: station.adresse,
          lat: station.lat,
          lng: station.lng,
        ),
    ];
    state = MapSearchState(results: local, searching: true);

    List<GeocodingResult> addresses;
    try {
      addresses = await ref.read(geocodingServiceProvider).search(query);
    } catch (_) {
      // Le géocodeur est un complément : s'il tombe, les stations trouvées
      // localement restent affichées.
      addresses = const [];
    }
    if (token != _token) return;

    state = MapSearchState(
      results: [
        ...local,
        for (final address in addresses)
          SearchHit(
            kind: SearchHitKind.address,
            title: address.label.split(',').first,
            subtitle: address.label,
            lat: address.lat,
            lng: address.lng,
          ),
      ],
    );
  }
}

final mapSearchProvider = NotifierProvider<MapSearchNotifier, MapSearchState>(
  MapSearchNotifier.new,
);

/// Les stations correspondant à [query], au plus [limit].
///
/// Une requête entièrement numérique est lue comme un code postal — « 75 »
/// doit ramener Paris, pas les rues dont le numéro commence par 75.
@visibleForTesting
List<Station> matchStations(
  List<Station> stations,
  String query, {
  int limit = 5,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final isPostal = RegExp(r'^\d{2,5}$').hasMatch(q);
  final matches = isPostal
      ? stations.where((s) => s.cp.startsWith(q))
      : stations.where(
          (s) =>
              s.ville.toLowerCase().contains(q) ||
              s.adresse.toLowerCase().contains(q),
        );
  return matches.take(limit).toList();
}
