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
echo " 1/4 Suche nach fertigem Image: ${IMAGE_NAME}:${TAG}"
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

echo ""
echo "======================================================="
echo " 2/4 Kopiere fertiges Web-Verzeichnis (www) auf Host..."
echo "======================================================="

# Lösche den alten lokalen www-Ordner, falls er existiert
rm -rf ./www

# Kopiert /luanti-wasm/www aus dem Container direkt in dein lokales Verzeichnis
docker run --rm --entrypoint "" -v "$(pwd):/host" "${IMAGE_NAME}:${TAG}" cp -r /luanti-wasm/www /host/

echo "=> www/ extrahiert"

echo ""
echo "======================================================="
echo " 3/4 Erkenne Release UUID..."
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

echo ""
echo "======================================================="
echo " 4/4 Führe Vite Frontend-Generator aus..."
echo "======================================================="

# --- 4. Vite Docker Image bauen (einmalig) ---
VITE_IMAGE="${IMAGE_NAME}-vite"
echo "=> Baue Vite-Generator Image: ${VITE_IMAGE}:latest"
docker build -t "${VITE_IMAGE}:latest" -f Dockerfile.vite .

# --- 5. Vite Container ausführen ---
echo "=> Vite generiert index.html mit UUID: $RELEASE_UUID"
docker run --rm \
  -e RELEASE_UUID="$RELEASE_UUID" \
  -v "$(pwd)/www:/app/www:ro" \
  -v "$(pwd)/custom_frontend/dist:/app/dist" \
  "${VITE_IMAGE}:latest"

# Kopiere Output von custom_frontend/dist nach www
echo "=> Kopiere Vite-Output zu www/"
if [ -d "custom_frontend/dist" ]; then
  # Lösche alte www und ersetze mit neuem Output
  rm -rf ./www
  mv custom_frontend/dist ./www
else
  echo "ERROR: Vite-Output nicht gefunden!"
  exit 1
fi

echo ""
echo "======================================================="
echo " ✓ Fertig! Frontend optimiert und bereit."
echo "======================================================="
echo "Release UUID: $RELEASE_UUID"
echo "Output: ./www/"
echo ""
echo "Dateien:"
ls -lh ./www/ | tail -5
