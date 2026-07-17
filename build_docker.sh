#!/bin/bash
set -e

# --- 1. Versionen direkt im Skript definieren (Fallbacks) ---
EMSDK_VERSION="${EMSDK_VERSION:-3.1.64}"
LUANTI_VERSION="${LUANTI_VERSION:-5.10.0}"

# --- 2. Repository & Image-Namen ermitteln ---
if [ -z "$GITHUB_REPOSITORY" ]; then
  # Lokale Git-Konfiguration auslesen
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  # Fallback falls kein Git remote vorhanden ist
  : "${GITHUB_REPOSITORY:=luanti-wasm}"
fi

# Der Name des Base-Builders
IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}-builder"
COMMIT_HASH=$(git rev-parse --short HEAD || echo "local")

# Version-Tags säubern
CLEAN_EMSDK=$(echo "$EMSDK_VERSION" | tr -cd '[:alnum:]._-')
CLEAN_LUANTI=$(echo "$LUANTI_VERSION" | tr -cd '[:alnum:]._-')
VERSION_TAG="v${CLEAN_LUANTI}-emsdk${CLEAN_EMSDK}"

echo "-------------------------------------------------------"
echo "Configuration Summary (No .env):"
echo "Image Name:      $IMAGE_NAME"
echo "EMSDK Version:   $EMSDK_VERSION"
echo "Luanti Version:  $LUANTI_VERSION"
echo "-------------------------------------------------------"

# --- 3. Docker Build ---
docker build \
  --no-cache \
  --pull \
  --build-arg EMSDK_VERSION="${EMSDK_VERSION}" \
  --build-arg LUANTI_VERSION="${LUANTI_VERSION}" \
  -t "${IMAGE_NAME}:${COMMIT_HASH}" \
  -f Dockerfile.base \
  .

# --- 4. Tagging & Push Funktion ---
tag_and_push() {
  local TAG=$1
  echo "=> Tagging: ${IMAGE_NAME}:${TAG}"
  docker tag "${IMAGE_NAME}:${COMMIT_HASH}" "${IMAGE_NAME}:${TAG}"
  
  if [ "$CI" == "true" ]; then
    echo "=> Pushing: ${IMAGE_NAME}:${TAG} ..."
    docker push "${IMAGE_NAME}:${TAG}"
  fi
}

# --- 5. Tags vergeben ---
tag_and_push "latest"
tag_and_push "${VERSION_TAG}"

if [ "$CI" == "true" ]; then
  echo "=> Pushing base hash tag: ${IMAGE_NAME}:${COMMIT_HASH}"
  docker push "${IMAGE_NAME}:${COMMIT_HASH}"
  echo "--- Build & Push completed successfully ---"
else
  echo "--- Local Image Build Finished ---"
  echo "Nutzbar mit: ./build.sh"
fi
