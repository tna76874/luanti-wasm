#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

echo "=== Minetest-WASM Build-Wrapper ==="

# 1. Prüfen, ob das Basis-Image existiert (wenn nicht, einmalig bauen)
if ! docker image inspect minetest-wasm-base >/dev/null 2>&1; then
    echo "-> Basis-Image 'minetest-wasm-base' nicht gefunden."
    echo "   Klone Repository von GitHub und baue Basis-Dependencies im Container..."
    docker build -t minetest-wasm-base -f Dockerfile.base "$SCRIPT_DIR"
else
    echo "-> Verwende existierendes Basis-Image 'minetest-wasm-base'."
fi

# 2. Schnellen inkrementellen Build mit Dockerfile.dev durchführen
echo "-> Baue angepasstes Frontend und kompiliere Minetest..."
mkdir -p "$SCRIPT_DIR/custom_frontend/static"
docker build -t minetest-wasm-local -f Dockerfile.dev "$SCRIPT_DIR"

# 3. Fertiges 'www' extrahieren
echo "-> Extrahiere 'www' Verzeichnis nach $DIST_DIR..."
rm -rf "$DIST_DIR"

# Temporären Container erstellen
TEMP_CONTAINER=$(docker create minetest-wasm-local)

# www-Verzeichnis aus dem Container herauskopieren
docker cp "$TEMP_CONTAINER:/minetest-wasm/www" "$DIST_DIR"

# Container aufräumen
docker rm "$TEMP_CONTAINER"

echo "=== Build erfolgreich abgeschlossen! ==="
echo "Die fertigen Web-Dateien liegen bereit in: $DIST_DIR"