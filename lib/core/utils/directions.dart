import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre l'app de plans du système sur un itinéraire vers [lat]/[lng].
///
/// Chaque plateforme a sa porte d'entrée, et se tromper coûte cher : le schéma
/// `geo:` d'Android n'existe pas sur iOS, où il envoyait l'utilisateur sur
/// Google Maps dans Safari au lieu de Plans. Les candidats sont donc essayés
/// dans l'ordre, du plus natif au plus universel, et le dernier — une URL
/// https — aboutit toujours.
Future<void> openDirectionsTo(double lat, double lng, {String? label}) async {
  for (final uri in directionsUris(lat, lng, label)) {
    if (await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }
}

/// Les URL essayées, dans l'ordre. Exposée pour que les tests vérifient
/// qu'iOS ne retombe jamais sur `geo:` — l'erreur est invisible depuis
/// Windows, où aucune des deux plateformes ne s'exécute.
@visibleForTesting
List<Uri> directionsUris(double lat, double lng, String? label) {
  final point = '$lat,$lng';
  return switch (defaultTargetPlatform) {
    // maps.apple.com est un lien universel : iOS l'intercepte et ouvre Plans
    // sans passer par le navigateur, sans déclaration dans Info.plist.
    TargetPlatform.iOS || TargetPlatform.macOS => [
      Uri.parse('https://maps.apple.com/?daddr=$point&dirflg=d'),
    ],
    TargetPlatform.android => [
      Uri.parse(
        'geo:$point?q=${Uri.encodeComponent(label == null ? point : '$point($label)')}',
      ),
      _googleMapsFallback(point),
    ],
    _ => [_googleMapsFallback(point)],
  };
}

Uri _googleMapsFallback(String point) =>
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$point');
