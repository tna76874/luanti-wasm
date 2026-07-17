#!/bin/bash
set -e

# 1. Repository-Namen für das Builder-Image ermitteln
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
echo " Bereite Custom-Dateien vor..."
echo "======================================================="

# Optional: Kopiere deine Custom-Frontend-Dateien temporär in das Verzeichnis,
# das im Container gebaut wird (falls sie dort nicht eh schon liegen)
if [ -d "./custom_frontend/static" ]; then
  echo "=> Überschreibe originale Web-Dateien mit Custom-Frontend..."
  cp -r ./custom_frontend/static/* ./www/static/ 2>/dev/null || true
fi

echo "======================================================="
echo " Starte schnellen Dev-Build im Container..."
echo "======================================================="

# Wir führen nur die finalen Build-Schritte aus.
# -v mountet dein aktuelles Verzeichnis direkt als /src
docker run --rm \
  -v "$(pwd):/src" \
  -w /src \
  "${IMAGE_NAME}:${TAG}" \
  /bin/bash -c "./build_minetest.sh && ./build_fsroot.sh && ./build_www.sh"

echo "======================================================="
echo " Dev-Build erfolgreich! Dateien liegen lokal in www/"
echo "======================================================="