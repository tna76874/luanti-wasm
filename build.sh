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
echo " Suche nach Builder-Image: ${IMAGE_NAME}:${TAG}"
echo "======================================================="

# --- 2. Versuchen das Image zu pullen, andernfalls lokal bauen ---
if docker pull "${IMAGE_NAME}:${TAG}" 2>/dev/null; then
  echo "=> Erfolg! Vorgebautes Image erfolgreich von GitHub geladen."
else
  echo "=> Pull fehlgeschlagen (oder Image existiert noch nicht im GitHub-Repository)."
  echo "=> Baue das Builder-Image stattdessen lokal..."
  echo "-------------------------------------------------------"
  
  # Führt dein build_docker.sh aus, um das Image lokal zu erzeugen
  ./build_docker.sh
  
  echo "-------------------------------------------------------"
  echo "=> Lokaler Image-Build erfolgreich beendet."
fi

echo "======================================================="
echo " Bereite Custom-Dateien vor..."
echo "======================================================="

# Custom-Frontend-Dateien rüberkopieren (falls vorhanden)
if [ -d "./custom_frontend/static" ]; then
  echo "=> Überschreibe originale Web-Dateien mit Custom-Frontend..."
  mkdir -p ./www/static
  cp -r ./custom_frontend/static/* ./www/static/ 2>/dev/null || true
fi

echo "======================================================="
echo " Starte WASM-Build im Container..."
echo "======================================================="

docker run --rm \
  -v "$(pwd):/src" \
  -w /minetest-wasm \
  "${IMAGE_NAME}:${TAG}" \
  /bin/bash -c "./build_www.sh"

echo "======================================================="
echo " Build erfolgreich! Die Web-Dateien liegen in www/"
echo "======================================================="