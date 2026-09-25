import 'package:flutter/material.dart';

/// Politique de confidentialité, lisible hors ligne depuis l'écran Compte.
///
/// Le texte doit rester le miroir exact de `docs/politique-confidentialite.md`,
/// qui est la version publiée sur le web — c'est l'URL que réclame App Store
/// Connect, et Apple compare les deux. Toute modification ici doit être
/// reportée là-bas, et inversement.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            "Mon Carburant ne vend, ne loue et ne partage aucune donnée "
            "personnelle. L'app ne contient ni publicité, ni traceur "
            'publicitaire, ni outil de mesure d’audience.',
            style: theme.textTheme.bodyLarge,
          ),
          for (final section in _sections) ...[
            const SizedBox(height: 28),
            Text(section.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(section.body, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Dernière mise à jour : septembre 2026.\n'
            'Questions ou demande de suppression : contact@mon-carburant.com',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const _sections = [
  _Section(
    'Votre position',
    "Elle sert uniquement à classer les stations par distance et à centrer la "
        "carte. Elle est utilisée sur votre appareil et n'est jamais "
        "enregistrée sur nos serveurs. Vous pouvez refuser l'accès à la "
        'position : le reste de l’app continue de fonctionner, la recherche '
        'par ville prend le relais.',
  ),
  _Section(
    'Prix des carburants',
    "Ils proviennent du flux open data officiel du gouvernement "
        '(donnees.roulez-eco.fr, Licence Ouverte). L’app le télécharge en '
        'entier et fait tous les calculs localement : aucune requête ne dit à '
        'qui que ce soit quelle station vous consultez.',
  ),
  _Section(
    'Cartes et itinéraires',
    "L’affichage de la carte, la recherche d’adresse et le calcul d’un trajet "
        'passent par des services OpenStreetMap. Ils reçoivent, le temps de '
        'la requête, votre adresse IP ainsi que la zone affichée, le texte '
        'recherché ou les points de départ et d’arrivée. Aucun identifiant de '
        'compte ne leur est transmis.',
  ),
  _Section(
    'Compte et favoris',
    "À la première ouverture, un compte anonyme est créé automatiquement "
        '(un identifiant aléatoire, sans nom ni e-mail) pour que vos favoris '
        'survivent à un redémarrage. Si vous vous connectez avec Apple ou '
        'Google, vos favoris sont rattachés à ce compte pour vous suivre d’un '
        'appareil à l’autre ; nous conservons alors l’adresse e-mail fournie '
        'par le fournisseur — avec Apple, ce peut être une adresse relais qui '
        'masque la vôtre. Vous déconnecter ramène l’app à un compte anonyme.',
  ),
  _Section(
    'Rapports de plantage',
    "Si l’app plante, un rapport technique est envoyé à Firebase Crashlytics "
        '(Google) : modèle d’appareil, version du système, version de l’app et '
        'l’état du code au moment de l’erreur. Ces rapports ne contiennent ni '
        'votre position, ni vos favoris, ni votre identité, et servent '
        'uniquement à corriger les bugs.',
  ),
  _Section(
    'Vos données de véhicule',
    "La consommation et la taille du réservoir que vous saisissez restent sur "
        'votre appareil.',
  ),
  _Section(
    'Vos droits',
    "Vous pouvez à tout moment vous déconnecter, révoquer l’accès à la "
        'position dans les réglages du système, ou supprimer votre compte et '
        'ses favoris depuis l’écran Compte (« Supprimer mon compte ») : la '
        'suppression est immédiate. Pour toute autre demande, écrivez à '
        'contact@mon-carburant.com.',
  ),
];
