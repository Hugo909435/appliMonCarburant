# Annonce « prix coûtant »

Un bandeau discret peut signaler une opération à prix coûtant en cours.
Son contenu vit **dans Firestore, pas dans l'application** : il se modifie
depuis la console Firebase, prend effet en quelques secondes sur les
téléphones déjà installés, et ne demande **aucune mise à jour sur les
stores**.

## Où ça se règle

Console Firebase → projet `moncarburant-89937` → **Firestore Database** →
collection `config` → document `prix_coutant`.

Si le document n'existe pas encore, créez-le : collection `config`,
identifiant de document `prix_coutant`.

## Les champs

| Champ         | Type    | Obligatoire | Rôle |
|---------------|---------|-------------|------|
| `actif`       | boolean | oui         | `true` affiche le bandeau, `false` l'éteint immédiatement. |
| `id`          | string  | oui         | Identifiant de la campagne, ex. `leclerc-oct-2026`. Voir « Faire réapparaître » ci-dessous. |
| `titre`       | string  | non         | Ligne en gras. Par défaut : « Opération prix coûtant ». |
| `message`     | string  | oui         | Le texte, sur 2 lignes maximum à l'écran. Restez court. |
| `debut`       | timestamp | non       | Avant cette date, rien ne s'affiche. |
| `fin`         | timestamp | non       | Après cette date, le bandeau disparaît tout seul. |
| `lienUrl`     | string  | non         | Si renseigné, le bandeau devient cliquable et ouvre ce lien. |
| `lienLibelle` | string  | non         | Texte du lien. Par défaut : « En savoir plus ». |

Un document incomplet ou mal saisi (`id` ou `message` vide, date
illisible) se traduit par « pas d'annonce » — jamais par un plantage.

### Exemple

```
actif       : true
id          : "leclerc-oct-2026"
titre       : "Prix coûtant ce week-end"
message     : "E.Leclerc et Carrefour vendent le carburant à prix coûtant du 3 au 5 octobre."
debut       : 2 octobre 2026 à 18:00
fin         : 5 octobre 2026 à 20:00
lienUrl     : "https://www.e.leclerc/operation-carburant"
lienLibelle : "Voir les conditions"
```

## Les gestes courants

**Lancer une annonce** — remplir les champs, mettre `actif` à `true`.

**L'arrêter tout de suite** — passer `actif` à `false`. Le bandeau
disparaît des applications ouvertes sans rien faire d'autre.

**L'arrêter toute seule** — renseigner `fin`. C'est le plus sûr : pas
besoin de penser à revenir éteindre l'annonce.

**Faire réapparaître le bandeau après une nouvelle opération** — changer
l'`id`. Une annonce fermée par un utilisateur ne lui est plus jamais
remontrée *pour ce même id* ; un nouvel id repart de zéro pour tout le
monde. Corriger une faute de frappe sans changer l'`id` met donc le texte
à jour sans réimposer le bandeau à ceux qui l'avaient fermé.

## Côté utilisateur

Le bandeau s'insère au-dessus de la barre de navigation, sur l'accueil et
les favoris. Il ne recouvre rien, ne demande aucune validation, et se
ferme d'une croix ou d'un balayage latéral. Une fois fermé, il ne revient
pas.

## Règles de sécurité

`firestore.rules` ouvre `config/{docId}` en lecture publique et interdit
l'écriture depuis l'application : le contenu est public, et seule la
console peut le modifier. Après modification du fichier, recopiez-le dans
l'onglet **Rules** de Firestore.
