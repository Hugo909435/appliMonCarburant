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

## iOS

Le code cible iOS dès le départ mais n'a pas été compilé/testé (nécessite un
Mac avec Xcode).

## Itinéraire

« Plein sur mon trajet » utilise le serveur de démo public d'OSRM
(`lib/data/services/routing_service.dart`), qui ne tolère pas un usage
intensif : à remplacer par une instance auto-hébergée avant une mise en
production à grande échelle.
