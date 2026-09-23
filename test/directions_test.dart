import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/directions.dart';

/// Ces règles ne peuvent être vérifiées ni sur Windows ni sur le web : elles
/// dépendent de la plateforme cible, que seul `debugDefaultTargetPlatformOverride`
/// permet de simuler ici.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('itinéraire', () {
    test('iOS ouvre Plans, jamais le schéma geo: qu\'il ne connaît pas', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final uris = directionsUris(48.8566, 2.3522, 'Paris');

      expect(uris, hasLength(1));
      expect(uris.single.host, 'maps.apple.com');
      expect(uris.single.queryParameters['daddr'], '48.8566,2.3522');
      expect(uris.any((u) => u.scheme == 'geo'), isFalse);
    });

    test('Android tente geo: puis retombe sur une URL universelle', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final uris = directionsUris(48.8566, 2.3522, 'Paris');

      expect(uris.first.scheme, 'geo');
      expect(uris.first.toString(), contains('Paris'));
      expect(uris.last.scheme, 'https');
    });

    test("le libellé d'une station est encodé, virgules comprises", () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final uri = directionsUris(1.5, -2.25, 'Saint-Étienne, centre').first;

      expect(uri.toString(), isNot(contains(' ')));
      expect(Uri.decodeComponent(uri.toString()), contains('Saint-Étienne'));
    });

    test('une plateforme sans app de plans dédiée reste fonctionnelle', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final uris = directionsUris(48.8566, 2.3522, null);

      expect(uris, hasLength(1));
      expect(uris.single.scheme, 'https');
    });
  });
}
