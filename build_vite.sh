#!/bin/bash
set -e

# --- Parse Arguments ---
DEV_MODE=false
BUILD_IMAGE=false

while getopts "db" opt; do
  case $opt in
    d) DEV_MODE=true ;;
    b) BUILD_IMAGE=true ;;
    *) echo "Usage: $0 [-d dev] [-b build image]"; exit 1 ;;
  esac
done

# --- Check www directory exists ---
if [ ! -d "./www" ]; then
  echo "ERROR: ./www directory not found!"
  echo "Run ./build.sh first to extract www from Docker image"
  exit 1
fi

# --- Extract UUID from www ---
RELEASE_UUID=""
for dir in ./www/*/; do
  if [ -f "${dir}luanti.js" ]; then
    RELEASE_UUID=$(basename "$dir")
    break
  fi
done

if [ -z "$RELEASE_UUID" ]; then
  echo "ERROR: Could not find RELEASE_UUID in ./www/{UUID}/luanti.js"
  exit 1
fi

echo "✓ Found RELEASE_UUID: $RELEASE_UUID"

# --- Detect repository ---
if [ -z "$GITHUB_REPOSITORY" ]; then
  REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
  if [ -n "$REMOTE_URL" ]; then
    GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  else
    GITHUB_REPOSITORY="luanti-wasm"
  fi
fi

VITE_IMAGE="ghcr.io/${GITHUB_REPOSITORY}-vite"

# --- Build Image (if needed or requested) ---
if [ "$BUILD_IMAGE" = true ] || ! docker image inspect "${VITE_IMAGE}:latest" &>/dev/null; then
  echo ""
  echo "======================================================="
  echo " Building Vite Docker Image: ${VITE_IMAGE}:latest"
  echo "======================================================="
  docker build -t "${VITE_IMAGE}:latest" -f Dockerfile.vite .
  echo "✓ Image built successfully"
fi

# --- Run Vite ---
echo ""
echo "======================================================="
if [ "$DEV_MODE" = true ]; then
  echo " DEV MODE: Vite Hot Reload Server"
  echo "======================================================="
  echo "Starting: npm run dev"
  echo ""
  docker run --rm \
    -e RELEASE_UUID="$RELEASE_UUID" \
    -p 3000:3000 \
    -v "$(pwd)/www:/app/www:ro" \
    -v "$(pwd)/custom_frontend/src:/app/src" \
    -v "$(pwd)/custom_frontend/vite.config.js:/app/vite.config.js" \
    "${VITE_IMAGE}:latest" \
    npm run dev
else
  echo " PRODUCTION BUILD: Optimized Output"
  echo "======================================================="
  echo "Building..."
  echo ""
  docker run --rm \
    -e RELEASE_UUID="$RELEASE_UUID" \
    -v "$(pwd)/www:/app/www:ro" \
    -v "$(pwd)/custom_frontend/dist:/app/dist" \
    "${VITE_IMAGE}:latest"
  
  echo ""
  echo "✓ Build completed successfully"
  echo ""
  echo "======================================================="
  echo " Moving output to www/"
  echo "======================================================="
  
  if [ -d "custom_frontend/dist" ]; then
    rm -rf ./www
    mv custom_frontend/dist ./www
    echo "✓ Output moved to ./www/"
  else
    echo "ERROR: Build output not found!"
    exit 1
  fi
fi
