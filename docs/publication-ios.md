# Publier Mon Carburant sur l'App Store

Tout ce qui pouvait être préparé sans Mac l'a été. Ce document liste ce qui
reste, dans l'ordre où il faut le faire. Les étapes marquées **Mac** exigent
un Mac avec Xcode ; les autres se font depuis un navigateur.

> ⚠️ **L'app n'a jamais été compilée sur iOS.** Le code cible iOS depuis le
> début, mais aucun build n'a encore eu lieu. Prévoyez du temps à l'étape 4 :
> c'est là que se révèlent les incompatibilités de pods, pas avant.

---

## 1. Compte et identifiants — *navigateur*

- [ ] Adhérer à l'**Apple Developer Program** (99 $/an, validation 24–48 h,
      plus long pour une entité morale qui doit fournir un numéro D-U-N-S).
- [ ] Dans **Certificates, Identifiers & Profiles**, créer l'App ID
      `com.moncarburant.monCarburantApp` et y cocher la capacité
      **Sign In with Apple**. Sans cette case, la signature échoue avec
      « provisioning profile doesn't support the Sign In with Apple
      capability ».
- [ ] Dans **App Store Connect**, créer la fiche de l'app (nom, langue
      principale : français, bundle ID ci-dessus).

## 2. Firebase — *navigateur*

- [ ] Console Firebase → projet `moncarburant-89937` → **Authentication →
      Sign-in method** : activer le fournisseur **Apple** (en plus de Google
      et Anonyme, déjà actifs).
- [ ] **Paramètres du projet** → app iOS → télécharger
      **GoogleService-Info.plist** et le déposer dans `ios/Runner/`.
      Le fichier est volontairement ignoré par git, comme son équivalent
      Android.
- [ ] Vérifier que l'app iOS est bien enregistrée avec le bundle ID
      `com.moncarburant.monCarburantApp` — il doit correspondre à `iosBundleId`
      dans `lib/firebase_options.dart`.

## 3. Services cartographiques — *navigateur*

C'est le point le plus facile à oublier, et il ne se voit qu'une fois l'app
entre les mains des utilisateurs.

L'app utilise par défaut les serveurs publics de démonstration
d'OpenStreetMap. Leurs conditions d'utilisation **interdisent** le trafic
d'une application publiée : la fondation OSM demande explicitement qu'une app
n'utilise pas `tile.openstreetmap.org` comme fond de carte, et le serveur de
démo d'OSRM n'accepte aucun usage soutenu. Une app qui les garderait se ferait
bloquer, et la carte deviendrait grise chez tout le monde en même temps.

- [ ] Choisir un fournisseur de tuiles (offre gratuite généralement suffisante
      pour un lancement : MapTiler, Stadia Maps, Thunderforest…) ou héberger
      son propre serveur.
- [ ] Faire de même pour le routage (OSRM auto-hébergé, ou une API commerciale)
      et le géocodage (Nominatim auto-hébergé, ou l'API Adresse de
      data.gouv.fr, gratuite et sans quota strict pour la France).
- [ ] Créer `tool/.env.release` (non versionné) :

      MC_TILE_URL=https://tuiles.exemple.fr/{z}/{x}/{y}.png
      MC_OSRM_URL=https://osrm.exemple.fr/route/v1/driving
      MC_NOMINATIM_URL=https://geocode.exemple.fr/search

Ces trois URL sont les seules à changer ; voir `lib/core/config/app_config.dart`.

## 4. Premier build iOS — *Mac*

```bash
git clone <ce dépôt> && cd appliMonCarburant
flutter pub get
./tool/ios_apply_google_config.sh   # remplit Info.plist depuis GoogleService-Info.plist
cd ios && pod install && cd ..
flutter build ios --release --no-codesign
```

- [ ] Ajouter `GoogleService-Info.plist` à la cible Runner dans Xcode
      (clic droit sur le dossier `Runner` → *Add Files to "Runner"*, en
      cochant *Copy items if needed* et la cible **Runner**). Le déposer dans
      le dossier ne suffit pas : Firebase ne le trouverait pas à l'exécution.
- [ ] Ouvrir `ios/Runner.xcworkspace`, onglet **Signing & Capabilities** :
      sélectionner l'équipe. **Sign In with Apple** doit déjà apparaître dans
      la liste des capacités — c'est `Runner/Runner.entitlements`, déjà
      référencé par le projet.
- [ ] Tester sur un appareil réel : géolocalisation, connexion Apple,
      connexion Google, itinéraire vers une station, synchronisation des
      favoris entre deux appareils.

### Crashlytics — *Mac*

Les rapports remontent sans configuration, mais restent illisibles sans les
symboles. Dans Xcode, cible Runner → **Build Phases** → **+** → *New Run
Script Phase*, la placer **après** « Thin Binary », la nommer
« Crashlytics » et y mettre :

```
"${PODS_ROOT}/FirebaseCrashlytics/run"
```

Avec, dans *Input Files* :

```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

### Crashlytics côté Android — *à vérifier au premier build*

Les rapports Dart remontent déjà sans rien faire de plus. En revanche, la
remontée symbolisée du code natif et l'envoi automatique du fichier de mapping
demandent le plugin Gradle, qui n'a **pas** été ajouté ici : sa version doit
s'accorder avec AGP 9.1.0, et ce projet n'est pas compilable sous Windows pour
le vérifier. À faire au premier build Android, en relevant la version courante
sur https://firebase.google.com/docs/crashlytics/get-started?platform=android :

```kotlin
// android/settings.gradle.kts
id("com.google.firebase.crashlytics") version "<version>" apply false

// android/app/build.gradle.kts, dans le bloc plugins
id("com.google.firebase.crashlytics")
```

## 5. Éléments de la fiche App Store — *navigateur*

- [ ] **Politique de confidentialité** : obligatoire. Publier le contenu de
      `docs/politique-confidentialite.md` sur
      `https://mon-carburant.com/confidentialite` et coller l'URL dans App
      Store Connect. Le texte doit rester identique à celui affiché dans
      l'app (`lib/features/privacy/privacy_screen.dart`).
- [ ] **Déclarations de confidentialité** (« nutrition labels ») — à saisir
      exactement comme dans `ios/Runner/PrivacyInfo.xcprivacy` :

      | Donnée              | Liée à l'identité | Suivi | Finalité           |
      |---------------------|-------------------|-------|--------------------|
      | Position précise    | Non               | Non   | Fonctionnement     |
      | Identifiant         | Oui               | Non   | Fonctionnement     |
      | Adresse e-mail      | Oui               | Non   | Fonctionnement     |
      | Données de plantage | Non               | Non   | Fonctionnement     |

- [ ] **Captures d'écran**, obligatoires pour deux tailles seulement :
      iPhone 6,9" (1320 × 2868) et iPhone 6,5" (1242 × 2688). Les tailles
      iPad ne sont exigées que si l'app est proposée sur iPad.
- [ ] **Nom** (30 car. max) et **sous-titre** (30 car. max). Par exemple :
      « Mon Carburant » / « Prix des carburants en France ».
- [ ] **Description**, **mots-clés**, **URL de support**.
- [ ] **Classification d'âge** : questionnaire, réponse « Aucun » partout →
      4+.
- [ ] **Droits d'auteur** et coordonnées de contact.

## 6. Notes pour la revue — *navigateur*

Apple rejette régulièrement les apps de géolocalisation faute d'explication.
À coller dans le champ *Notes* :

> L'application affiche les prix des carburants en France à partir du flux
> open data officiel du gouvernement (donnees.roulez-eco.fr, Licence Ouverte).
> La position sert uniquement à trier les stations par distance et à centrer
> la carte ; elle n'est jamais transmise à nos serveurs. Aucun compte n'est
> requis : l'app est entièrement utilisable sans connexion. La connexion,
> facultative, ne sert qu'à synchroniser les favoris entre appareils, et
> « Se connecter avec Apple » y est proposé au même niveau que Google.

- [ ] Aucun compte de démonstration n'est nécessaire — le préciser.

## 7. Envoi

```bash
./tool/build_release.sh ios
```

- [ ] Envoyer l'archive avec Transporter ou Xcode → Organizer.
- [ ] Passer par **TestFlight** d'abord : l'installer sur un vrai iPhone et
      refaire le tour des fonctionnalités. C'est le seul moyen de voir l'app
      telle que la verra le validateur.
- [ ] Soumettre pour revue. Comptez 24–48 h, davantage pour une première
      soumission.

---

## Points de rejet fréquents, et où on en est

| Motif | État |
|---|---|
| Icône ou écran de lancement laissés par défaut | ✅ Icône et splash sur mesure, générés par `tool/generate_branding.dart` |
| Transparence dans l'icône 1024 | ✅ Aplatie (`remove_alpha_ios`) |
| Connexion tierce sans « Se connecter avec Apple » (règle 4.8) | ✅ Implémenté, affiché en premier |
| Politique de confidentialité manquante | ✅ Rédigée ; reste à la publier en ligne (étape 5) |
| Manifeste de confidentialité absent | ✅ `ios/Runner/PrivacyInfo.xcprivacy` |
| Usage de la position mal expliqué | ✅ `NSLocationWhenInUseUsageDescription` détaillé, + notes de revue |
| Conformité export non renseignée | ✅ `ITSAppUsesNonExemptEncryption = false` |
| App qui ne fonctionne pas sans compte | ✅ Session anonyme par défaut |
