#!/bin/bash

# Standardwerte setzen
MODE=""
PORT=3000

# Hilfe-Funktion
usage() {
    echo "Nutzung: $0 -m [dev|build] [-p port]"
    echo "  -m : Modus auswählen ('dev' für Entwicklungs-Server, 'build' für statischen Build)"
    echo "  -p : (Optional) Port für den Dev-Server (Standard: 3000)"
    exit 1
}

# Parameter auswerten mit getopts
while getopts "m:p:h" opt; do
    case ${opt} in
        m )
            MODE=$OPTARG
            ;;
        p )
            PORT=$OPTARG
            ;;
        h | ? )
            usage
            ;;
    esac
done

# Validierung der Pflichtangaben
if [ "$MODE" != "dev" ] && [ "$MODE" != "build" ]; then
    echo "Fehler: Ungültiger oder fehlender Modus (-m)."
    usage
fi

# --- DEV MODE ---
if [ "$MODE" == "dev" ]; then
    echo "[Vite Docker] Starte Entwicklungsmodus auf Port $PORT..."
    
    # Image für die 'development' Target-Stage bauen
    docker build --target development -f Dockerfile.vite -t minetest-vite:dev .
    
    # Container starten. Wir mounten das aktuelle Verzeichnis, damit Änderungen an index.html 
    # sofort (Hot Reload) im Container ankommen, ohne neu zu bauen.
    docker run -it --rm \
        -p ${PORT}:3000 \
        -v "$(pwd)":/app \
        -v /app/node_modules \
        --name minetest-vite-dev \
        minetest-vite:dev

# --- BUILD MODE ---
elif [ "$MODE" == "build" ]; then
    echo "[Vite Docker] Starte statischen Produktions-Build..."
    
    # Image für die 'exporter' Target-Stage bauen
    docker build --target exporter -f Dockerfile.vite -t minetest-vite:build .
    
    # Ordner für das Ergebnis auf dem Host leeren/bereitstellen
    mkdir -p dist
    
    # Container ausführen. Die fertigen statischen Dateien werden aus dem Container 
    # in deinen lokalen 'dist' Ordner kopiert.
    docker run --rm \
        -v "$(pwd)/dist":/output \
        --name minetest-vite-build \
        minetest-vite:build
        
    echo "[Vite Docker] Fertig! Die statische Website liegt in deinem lokalen './dist' Ordner."
fi
