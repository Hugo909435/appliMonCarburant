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
///   --dart-define=MC_TILE_URL=https://{s}.tuiles.exemple.fr/{z}/{x}/{y}.png \
///   --dart-define=MC_OSRM_URL=https://osrm.exemple.fr/route/v1/driving \
///   --dart-define=MC_NOMINATIM_URL=https://geocode.exemple.fr/search
/// ```
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
