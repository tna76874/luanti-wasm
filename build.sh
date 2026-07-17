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

# Kopiert /minetest-wasm/www aus dem Container direkt in dein lokales Verzeichnis
docker run --rm --entrypoint "" -v "$(pwd):/host" "${IMAGE_NAME}:${TAG}" cp -r /minetest-wasm/www /host/

echo "======================================================="
echo " Fertig! Die Web-Dateien liegen jetzt in ./www/"
echo "======================================================="