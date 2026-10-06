import 'package:flutter/foundation.dart';

/// Points de terminaison réseau, surchargeables au build.
///
/// Les valeurs par défaut sont les serveurs publics de démonstration
/// d'OpenStreetMap. Elles conviennent au développement, mais leurs conditions
/// d'utilisation interdisent le trafic d'une app publiée : la fondation OSM
/// demande qu'une application n'utilise pas `tile.openstreetmap.org` comme
/// fond de carte, et le serveur de démo d'OSRM n'accepte aucun usage soutenu.
///
/// Avant publication, pointer vers des fournisseurs (offres gratuites à
/// usage commercial permis) :
///
/// ```bash
/// flutter build ipa \
///   --dart-define=MC_TILE_URL='https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}{r}.png?apiKey=CLE' \
///   --dart-define=MC_TILE_ATTRIBUTION='Powered by Geoapify © OpenStreetMap' \
///   --dart-define=MC_OSRM_URL='https://eu1.locationiq.com/v1/directions/driving?key=CLE' \
///   --dart-define=MC_NOMINATIM_URL='https://eu1.locationiq.com/v1/search?key=CLE'
/// ```
///
/// Les fournisseurs passent leur clé dans l'URL : les services conservent la
/// requête de l'URL de base (voir [endpoint]).
///
/// `tool/build_release.sh` regroupe ces options ; [usesPublicDemoServices]
/// permet de vérifier, à l'exécution, qu'un build de production ne les a pas
/// oubliées.
class AppConfig {
  const AppConfig._();

  static const _defaultOsrmUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const _defaultNominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  static const _defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gabarit d'URL des tuiles raster du fond de carte. `{r}` y est remplacé
  /// par `@2x` sur les écrans haute densité, quand le fournisseur en sert.
  static const tileUrlTemplate = String.fromEnvironment(
    'MC_TILE_URL',
    defaultValue: _defaultTileUrl,
  );

  /// Crédit affiché sur la carte. Le fournisseur de tuiles impose d'y
  /// figurer à côté d'OpenStreetMap.
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

  /// Identifiant du formulaire Formspree de « Signaler un problème » (la fin
  /// de son URL, `formspree.io/f/<id>`). Le service transfère les messages à
  /// une adresse que l'app ne connaît pas, et qui reste donc cachée aux
  /// utilisateurs. Vide : l'entrée n'est pas proposée.
  static const feedbackFormId = String.fromEnvironment('MC_FEEDBACK_FORM');

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

  /// Géocodage servi par LocationIQ, dont l'offre gratuite exige un lien
  /// « Search by LocationIQ.com » visible près des résultats.
  static bool get usesLocationIq => nominatimBaseUrl.contains('locationiq.com');

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
