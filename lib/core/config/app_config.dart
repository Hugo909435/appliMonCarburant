import 'package:flutter/foundation.dart';

/// Points de terminaison réseau, surchargeables au build.
///
/// Les valeurs par défaut sont les serveurs publics de démonstration
/// d'OpenStreetMap. Elles conviennent au développement, mais leurs conditions
/// d'utilisation interdisent le trafic d'une app publiée : la fondation OSM
/// demande explicitement qu'une application n'utilise pas `tile.openstreetmap.org`
/// comme fond de carte par défaut, et le serveur de démo d'OSRM n'accepte
/// aucun usage soutenu. Une app qui les garderait se ferait bloquer, et la
/// carte deviendrait grise chez tous les utilisateurs en même temps.
///
/// Avant publication, pointer vers une infrastructure à soi ou un fournisseur
/// commercial :
///
/// ```bash
/// flutter build ipa \
///   --dart-define=MC_TILE_URL='https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}.png?key=CLE' \
///   --dart-define=MC_TILE_ATTRIBUTION='© MapTiler © OpenStreetMap' \
///   --dart-define=MC_OSRM_URL='https://eu1.locationiq.com/v1/directions/driving?key=CLE' \
///   --dart-define=MC_NOMINATIM_URL='https://eu1.locationiq.com/v1/search?key=CLE'
/// ```
///
/// Les fournisseurs commerciaux passent leur clé dans l'URL : les services
/// conservent la requête de l'URL de base (voir [endpoint]).
///
/// `tool/build_release.sh` regroupe ces options ; [usesPublicDemoServices]
/// permet de vérifier, à l'exécution, qu'un build de production ne les a pas
/// oubliées.
class AppConfig {
  const AppConfig._();

  static const _defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _defaultOsrmUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const _defaultNominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  /// Gabarit d'URL des tuiles de la carte.
  static const tileUrlTemplate = String.fromEnvironment(
    'MC_TILE_URL',
    defaultValue: _defaultTileUrl,
  );

  /// Crédit affiché sur la carte. Le fournisseur de tuiles impose souvent
  /// d'y figurer à côté d'OpenStreetMap.
  static const tileAttribution = String.fromEnvironment(
    'MC_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );

  /// Racine du service d'itinéraire (API OSRM v1).
  static const osrmBaseUrl = String.fromEnvironment(
    'MC_OSRM_URL',
    defaultValue: _defaultOsrmUrl,
  );

  /// Racine du géocodage d'adresses (API Nominatim).
  static const nominatimBaseUrl = String.fromEnvironment(
    'MC_NOMINATIM_URL',
    defaultValue: _defaultNominatimUrl,
  );

  /// URL d'appel d'un service : [base] prolongée de [path], avec [query]
  /// ajoutée à la requête que [base] porte déjà (la clé d'API d'un
  /// fournisseur, typiquement) au lieu de la remplacer.
  static Uri endpoint(
    String base, {
    String path = '',
    Map<String, String> query = const {},
  }) {
    final uri = Uri.parse(base);
    return uri.replace(
      path: '${uri.path}$path',
      queryParameters: {...uri.queryParameters, ...query},
    );
  }

  /// Active les emplacements publicitaires (voir `AdSlot`). Éteint par
  /// défaut : tant qu'aucune régie n'est branchée, un build de release
  /// n'affiche rien à leur place.
  static const adsEnabled = bool.fromEnvironment('MC_ADS');

  /// Identifiant du paquet, transmis à flutter_map.
  static const packageName = 'com.moncarburant.monCarburantApp';

  /// En-tête `User-Agent` de toutes les requêtes sortantes. Les services
  /// OpenStreetMap exigent qu'une application s'identifie et laisse un moyen
  /// de la joindre ; un agent générique est un motif de blocage.
  static const userAgent =
      'MonCarburant/1.0 (+https://mon-carburant.com; contact@mon-carburant.com)';

  /// Vrai tant qu'au moins un service pointe encore sur un serveur public de
  /// démonstration. Sert de garde-fou avant publication.
  static bool get usesPublicDemoServices =>
      tileUrlTemplate == _defaultTileUrl ||
      osrmBaseUrl == _defaultOsrmUrl ||
      nominatimBaseUrl == _defaultNominatimUrl;

  /// Prévient au démarrage d'un build de release encore branché sur les
  /// serveurs de démo — l'erreur est invisible en test et ne se manifeste
  /// qu'une fois l'app entre les mains des utilisateurs.
  static void warnIfMisconfigured() {
    if (kReleaseMode && usesPublicDemoServices) {
      debugPrint(
        'ATTENTION : build de release utilisant les serveurs publics de '
        'démonstration OpenStreetMap. Voir AppConfig et docs/publication-ios.md.',
      );
    }
  }
}
