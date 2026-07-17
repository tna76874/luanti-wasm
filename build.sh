#!/bin/bash
set -e

# Standardmäßig suchen wir nach dem Image (force=false)
FORCE_BUILD=false

# --- 0. Argumente mit getopts parsen ---
while getopts "f" opt; do
  case [ "$opt" ] in
    f)
      FORCE_BUILD=true
      ;;
    *)
      echo "Nutzung: $0 [-f]"
      echo "  -f    Erzwingt den lokalen Bau des Docker-Images (ignoriert Remote-Pull)"
      exit 1
      ;;
  esac
done

# --- 1. Repository- und Image-Namen ermitteln ---
if [ -z "$GITHUB_REPOSITORY" ]; then
  REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
  if [ -n "$REMOTE_URL" ]; then
    GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  else
    GITHUB_REPOSITORY="luanti-wasm"
  fi
fi

IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}-builder"
TAG="latest"

echo "======================================================="
echo " 1/2 Vorbereitung des Docker-Images: ${IMAGE_NAME}:${TAG}"
echo "======================================================="

if [ "$FORCE_BUILD" = true ]; then
  echo "=> -f Flag aktiv: Überspringe Pull und baue Image direkt lokal..."
  echo "-------------------------------------------------------"
  ./build_docker.sh
  echo "-------------------------------------------------------"
else
  echo "=> Suche nach fertigem Image auf GitHub..."
  if docker pull "${IMAGE_NAME}:${TAG}" 2>/dev/null; then
    echo "=> Erfolg! Fertiges Image von GitHub geladen."
  else
    echo "=> Pull fehlgeschlagen. Baue Image lokal..."
    echo "-------------------------------------------------------"
    ./build_docker.sh
    echo "-------------------------------------------------------"
  fi
fi

echo ""
echo "======================================================="
echo " 2/2 Kopiere fertiges Web-Verzeichnis (www) auf Host..."
echo "======================================================="

rm -rf ./www

docker run --rm --entrypoint "" \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):/host" \
  "${IMAGE_NAME}:${TAG}" \
  cp -r /minetest-wasm/www /host/
  
echo "=> www/ extrahiert"

echo ""
echo "======================================================="
echo " Normalisiere Ordnerstruktur (UUID -> wasm)..."
echo "======================================================="

FOUND_UUID=""
for dir in ./www/*/; do
  if [ -f "${dir}luanti.js" ]; then
    FOUND_UUID=$(basename "$dir")
    mv "$dir" "./www/wasm"
    break
  fi
done

if [ -n "$FOUND_UUID" ]; then
  echo "=> Ordner '$FOUND_UUID' erfolgreich in 'wasm' umbenannt."
  
  # 1. UUID in der index.html ersetzen
  if [ -f "./www/index.html" ]; then
    sed -i "s/$FOUND_UUID/wasm/g" ./www/index.html
    echo "=> '$FOUND_UUID' in ./www/index.html erfolgreich durch 'wasm' ersetzt."
  else
    echo "WARNUNG: ./www/index.html wurde nicht gefunden!"
  fi

  # 2. RELEASE_DIR in der launcher.js anpassen
  LAUNCHER_PATH="./www/wasm/launcher.js"
  if [ -f "$LAUNCHER_PATH" ]; then
    # Ersetzt die spezifische Zuweisung der alten UUID durch 'wasm'
    sed -i "s/const RELEASE_DIR = '$FOUND_UUID';/const RELEASE_DIR = 'wasm';/g" "$LAUNCHER_PATH"
    echo "=> RELEASE_DIR in $LAUNCHER_PATH erfolgreich auf 'wasm' gesetzt."
  else
    echo "WARNUNG: $LAUNCHER_PATH wurde nicht gefunden!"
  fi

else
  echo "WARNUNG: Es wurde kein UUID-Ordner mit einer 'luanti.js' gefunden!"
fi