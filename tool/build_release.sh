#!/usr/bin/env bash
# Construit l'archive à envoyer à l'App Store, en injectant les points de
# terminaison de production (voir lib/core/config/app_config.dart).
#
#   ./tool/build_release.sh            # iOS  -> build/ios/ipa
#   ./tool/build_release.sh android    # Android -> build/app/outputs/bundle
#
# Les URL se lisent dans tool/.env.release, un fichier local non versionné :
#
#   MC_TILE_URL=https://tuiles.exemple.fr/{z}/{x}/{y}.png
#   MC_OSRM_URL=https://osrm.exemple.fr/route/v1/driving
#   MC_NOMINATIM_URL=https://geocode.exemple.fr/search
#
# Sans ce fichier, le build utiliserait les serveurs publics de démonstration
# d'OpenStreetMap, dont les conditions interdisent le trafic d'une app
# publiée. Le script refuse donc de continuer plutôt que de produire une
# archive qui se ferait bloquer une fois en ligne.

set -euo pipefail

cd "$(dirname "$0")/.."
PLATFORM="${1:-ios}"
ENV_FILE="tool/.env.release"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "✗ $ENV_FILE introuvable — voir l'en-tête de ce script." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

for var in MC_TILE_URL MC_OSRM_URL MC_NOMINATIM_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo "✗ $var non défini dans $ENV_FILE." >&2
    exit 1
  fi
done

DEFINES=(
  --dart-define=MC_TILE_URL="$MC_TILE_URL"
  --dart-define=MC_OSRM_URL="$MC_OSRM_URL"
  --dart-define=MC_NOMINATIM_URL="$MC_NOMINATIM_URL"
)

echo "→ Rafraîchissement des enseignes depuis OpenStreetMap"
dart run tool/build_station_brands.dart

echo "→ Analyse et tests"
flutter analyze
flutter test

case "$PLATFORM" in
  ios)
    echo "→ flutter build ipa"
    flutter build ipa --release "${DEFINES[@]}"
    echo
    echo "✓ Archive dans build/ios/ipa/. Ouvrez-la avec Transporter, ou"
    echo "  Xcode > Window > Organizer pour l'envoyer à App Store Connect."
    ;;
  android)
    echo "→ flutter build appbundle"
    flutter build appbundle --release "${DEFINES[@]}"
    echo
    echo "✓ Bundle dans build/app/outputs/bundle/release/."
    ;;
  *)
    echo "✗ Plateforme inconnue : $PLATFORM (attendu : ios ou android)" >&2
    exit 1
    ;;
esac
