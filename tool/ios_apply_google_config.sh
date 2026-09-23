#!/usr/bin/env bash
# Renseigne dans ios/Runner/Info.plist les deux valeurs que Google Sign-In lit
# sur iOS, en les recopiant depuis GoogleService-Info.plist :
#
#   GIDClientID          <- CLIENT_ID
#   CFBundleURLSchemes   <- REVERSED_CLIENT_ID   (retour de l'aller-retour OAuth)
#
# À lancer sur le Mac, depuis la racine du projet, après avoir déposé
# GoogleService-Info.plist dans ios/Runner/ :
#
#   ./tool/ios_apply_google_config.sh
#
# Le script est idempotent : on peut le relancer après chaque `flutter clean`
# ou après avoir retéléchargé le fichier depuis la console Firebase.

set -euo pipefail

INFO_PLIST="ios/Runner/Info.plist"
GOOGLE_PLIST="ios/Runner/GoogleService-Info.plist"
PLISTBUDDY="/usr/libexec/PlistBuddy"

if [[ ! -f "$GOOGLE_PLIST" ]]; then
  echo "✗ $GOOGLE_PLIST introuvable." >&2
  echo "  Console Firebase > Paramètres du projet > l'app iOS" >&2
  echo "  'com.moncarburant.monCarburantApp' > Télécharger GoogleService-Info.plist," >&2
  echo "  puis déposez le fichier dans ios/Runner/ (et ajoutez-le à la cible" >&2
  echo "  Runner dans Xcode : clic droit sur le dossier Runner > Add Files)." >&2
  exit 1
fi

if [[ ! -x "$PLISTBUDDY" ]]; then
  echo "✗ PlistBuddy introuvable : ce script doit tourner sur macOS." >&2
  exit 1
fi

CLIENT_ID=$("$PLISTBUDDY" -c "Print :CLIENT_ID" "$GOOGLE_PLIST" 2>/dev/null || true)
REVERSED_CLIENT_ID=$("$PLISTBUDDY" -c "Print :REVERSED_CLIENT_ID" "$GOOGLE_PLIST" 2>/dev/null || true)

if [[ -z "$CLIENT_ID" || -z "$REVERSED_CLIENT_ID" ]]; then
  echo "✗ CLIENT_ID / REVERSED_CLIENT_ID absents de $GOOGLE_PLIST." >&2
  echo "  C'est le signe qu'aucun client OAuth iOS n'existe pour cette app." >&2
  echo "  Dans la console Firebase, activez le fournisseur Google sous" >&2
  echo "  Authentication > Sign-in method, puis retéléchargez le fichier." >&2
  exit 1
fi

"$PLISTBUDDY" -c "Set :GIDClientID $CLIENT_ID" "$INFO_PLIST"
"$PLISTBUDDY" -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $REVERSED_CLIENT_ID" "$INFO_PLIST"

echo "✓ GIDClientID        = $CLIENT_ID"
echo "✓ CFBundleURLSchemes = $REVERSED_CLIENT_ID"
echo
echo "Info.plist est configuré. Ces deux identifiants ne sont pas des secrets"
echo "(ils sont lisibles dans le bundle de toute app publiee) : committez"
echo "Info.plist normalement. GoogleService-Info.plist, lui, reste ignore par"
echo "git, comme google-services.json cote Android."
