#!/bin/bash
set -e

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
echo " Suche nach fertigem Image: ${IMAGE_NAME}:${TAG}"
echo "======================================================="

# --- 2. Versuchen das Image zu pullen, andernfalls lokal bauen ---
if docker pull "${IMAGE_NAME}:${TAG}" 2>/dev/null; then
  echo "=> Erfolg! Fertiges Image von GitHub geladen."
else
  echo "=> Pull fehlgeschlagen. Baue Image lokal..."
  echo "-------------------------------------------------------"
  ./build_docker.sh
  echo "-------------------------------------------------------"
fi

echo "======================================================="
echo " Kopiere fertiges Web-Verzeichnis (www) auf den Host..."
echo "======================================================="

# Lösche den alten lokalen www-Ordner, falls er existiert
rm -rf ./www

# Kopiert /luanti-wasm/www aus dem Container direkt in dein lokales Verzeichnis
docker run --rm --entrypoint "" -v "$(pwd):/host" "${IMAGE_NAME}:${TAG}" cp -r /luanti-wasm/www /host/

echo "======================================================="
echo " Extrahiere Release UUID aus www-Struktur..."
echo "======================================================="

# --- 3. UUID aus der www-Verzeichnisstruktur auslesen ---
# Erwartet: www/{12-char-uuid}/luanti.js
RELEASE_UUID=""
for dir in www/*/; do
  if [ -f "${dir}luanti.js" ]; then
    RELEASE_UUID=$(basename "$dir")
    echo "=> Gefundene UUID: $RELEASE_UUID"
    break
  fi
done

if [ -z "$RELEASE_UUID" ]; then
  echo "ERROR: Konnte UUID nicht ermitteln. Struktur sollte sein: www/{UUID}/luanti.js"
  exit 1
fi

echo "======================================================="
echo " Führe Vite Frontend-Generator aus..."
echo "======================================================="

# --- 4. Vite aufrufen mit UUID als Environment-Variable ---
cd custom_frontend

# Stelle sicher, dass node_modules existiert
if [ ! -d "node_modules" ]; then
  echo "=> Installiere Dependencies..."
  npm install --no-save
fi

# Kopiere www-Verzeichnis in custom_frontend/www (für Vite Input)
cp -r ../www ./www-build 2>/dev/null || true

# Vite ausführen - generiert neue index.html, kopiert static files
echo "=> Vite generiert index.html mit UUID: $RELEASE_UUID"
RELEASE_UUID="$RELEASE_UUID" npm run build

# Neue www vom Vite-Output zurück in Root kopieren
rm -rf ../www
cp -r dist ../www

# Aufräumen
rm -rf www-build dist

cd ..

echo "======================================================="
echo " ✓ Fertig! Frontend optimiert und bereit."
echo "======================================================="
echo "Release UUID: $RELEASE_UUID"
echo "Output: ./www/"
echo ""
echo "Struktur:"
find ./www -type f -name "*.js" -o -name "*.html" -o -name "*.wasm" | head -10
