# Politique de confidentialité — Mon Carburant

*Dernière mise à jour : septembre 2026.*

> Ce texte est la version à publier sur le web : App Store Connect en exige
> l'URL. Il doit rester le miroir exact de l'écran affiché dans l'app
> (`lib/features/privacy/privacy_screen.dart`) — Apple compare les deux.
> Toute modification ici doit être reportée là-bas, et inversement.

Mon Carburant ne vend, ne loue et ne partage aucune donnée personnelle.
L'application ne contient ni publicité, ni traceur publicitaire, ni outil de
mesure d'audience.

## Votre position

Elle sert uniquement à classer les stations par distance et à centrer la
carte. Elle est utilisée sur votre appareil et n'est jamais enregistrée sur
nos serveurs. Vous pouvez refuser l'accès à la position : le reste de l'app
continue de fonctionner, la recherche par ville prend le relais.

## Prix des carburants

Ils proviennent du flux open data officiel du gouvernement
(`donnees.roulez-eco.fr`, Licence Ouverte). L'app le télécharge en entier et
fait tous les calculs localement : aucune requête ne dit à qui que ce soit
quelle station vous consultez.

## Cartes et itinéraires

L'affichage de la carte, la recherche d'adresse et le calcul d'un trajet
passent par des services OpenStreetMap. Ils reçoivent, le temps de la
requête, votre adresse IP ainsi que la zone affichée, le texte recherché ou
les points de départ et d'arrivée. Aucun identifiant de compte ne leur est
transmis.

## Compte et favoris

À la première ouverture, un compte anonyme est créé automatiquement (un
identifiant aléatoire, sans nom ni e-mail) pour que vos favoris survivent à un
redémarrage. Si vous vous connectez avec Apple ou Google, vos favoris sont
rattachés à ce compte pour vous suivre d'un appareil à l'autre ; nous
conservons alors l'adresse e-mail fournie par le fournisseur — avec Apple, ce
peut être une adresse relais qui masque la vôtre. Vous déconnecter ramène
l'app à un compte anonyme.

Ces données sont hébergées chez Google Firebase (Firebase Authentication et
Cloud Firestore).

## Rapports de plantage

Si l'app plante, un rapport technique est envoyé à Firebase Crashlytics
(Google) : modèle d'appareil, version du système, version de l'app et l'état
du code au moment de l'erreur. Ces rapports ne contiennent ni votre position,
ni vos favoris, ni votre identité, et servent uniquement à corriger les bugs.

## Vos données de véhicule

La consommation et la taille du réservoir que vous saisissez restent sur votre
appareil.

## Vos droits

Conformément au RGPD, vous disposez d'un droit d'accès, de rectification,
d'effacement et de portabilité de vos données. Vous pouvez à tout moment vous
déconnecter, révoquer l'accès à la position dans les réglages du système, ou
demander la suppression de votre compte et de ses favoris en écrivant à
**contact@mon-carburant.com**. La suppression est effective sous 30 jours.

Vous pouvez également introduire une réclamation auprès de la CNIL
(www.cnil.fr).

## Responsable du traitement

Mon Carburant — contact@mon-carburant.com
