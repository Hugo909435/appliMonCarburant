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
station : le site l'obtient via un script séparé qui n'est pas disponible
ici. Le filtre par enseigne n'est donc pas présent dans cette v1.

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
