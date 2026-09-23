# Mon Carburant — app

Application Flutter (Android + iOS) reprenant l'outil de comparateur de prix
carburant de [mon-carburant.com](https://mon-carburant.com) : recherche par
ville/code postal, carte des stations, stations à proximité (GPS), fiche
station (prix, horaires, services, itinéraire), listes département/région/
autoroute avec statistiques, prix moyen national et tendance, favoris.

Le blog éditorial du site n'est pas repris dans cette v1.

## Données

Les prix viennent directement du flux open data officiel
(`https://donnees.roulez-eco.fr/opendata/instantane`, Licence Ouverte), le
même que celui utilisé par le site. Le téléchargement (ZIP) et le parsing
(XML) se font côté app, dans un isolate séparé pour ne pas bloquer l'UI, avec
mise en cache locale pour un démarrage instantané.

Le flux officiel ne contient pas l'enseigne (Total, Leclerc, etc.) par
station. Elle est déduite d'OpenStreetMap par un script, et le résultat est
embarqué dans l'app (`assets/data/station_brands.json`, ~80 % des
stations). À relancer avant chaque publication pour suivre les nouvelles
stations :

```bash
dart run tool/build_station_brands.dart
```

Les logos officiels (`assets/logos/`, 19 enseignes) s'affichent sur la carte,
les listes et les fiches ; les autres enseignes ont un badge à leurs couleurs
(sources et ajout d'un logo : `assets/logos/LISEZMOI.txt`).

## Démarrer

```bash
flutter pub get
flutter run
```

## Structure

```
lib/
├── core/            # thème, utilitaires (formatage, calcul département)
├── data/
│   ├── models/      # Station, Department, FuelType, FuelStat
│   ├── services/    # téléchargement/parsing du flux, cache, favoris, localisation
│   └── repositories/
├── providers/       # état Riverpod (stations, filtres, favoris, stats, position)
├── features/        # écrans (accueil, carte, recherche, fiche station, groupes...)
├── shared/widgets/  # composants réutilisés entre écrans
└── router/          # go_router
```

## Marque

L'icône et l'écran de démarrage descendent tous d'un seul dessin vectoriel,
dans `tool/generate_branding.dart`. Après l'avoir modifié :

```bash
flutter test tool/generate_branding.dart   # redessine assets/branding/
dart run flutter_launcher_icons            # décline les icônes
dart run flutter_native_splash:create      # décline l'écran de démarrage
```

## Services réseau

Les URL des tuiles, du routage et du géocodage sont regroupées dans
`lib/core/config/app_config.dart` et surchargeables au build par
`--dart-define`. Les valeurs par défaut sont les serveurs publics de
démonstration d'OpenStreetMap : pratiques en développement, **interdits pour
une app publiée** par leurs conditions d'utilisation. `tool/build_release.sh`
impose de les remplacer.

## Publication

`docs/publication-ios.md` détaille tout ce qui reste à faire pour l'App Store.
L'essentiel côté code est prêt ; le premier build iOS demande un Mac et n'a
pas encore eu lieu.

```bash
./tool/build_release.sh ios       # archive App Store
./tool/build_release.sh android   # bundle Play Store
```
