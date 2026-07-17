# Luanti WASM Frontend Generator

Minimales Vite-Setup für die **index.html Optimierung** mit Docker.

## Workflow

```
1. Docker Pull/Build → www mit {UUID}/ extrahieren
2. UUID erkennen → aus www/{UUID}/luanti.js
3. Dockerfile.vite Image bauen → Node mit Dependencies
4. Vite Container → generiert optimierte index.html
5. Output → kopiert dist/ nach www/
```

## Struktur

```
├── Dockerfile.vite              ← Frontend-Generator Image
├── build.sh                     ← Main Build-Script
├── custom_frontend/
│   ├── vite.config.js          ← Konfiguration
│   ├── package.json
│   ├── src/
│   │   └── index.html          ← Template mit __RELEASE_UUID__
│   └── dist/                   ← (temporär, wird zu www/)
└── www/                        ← Output
    ├── index.html              ← Generiert von Vite
    ├── {UUID}/
    │   ├── launcher.js
    │   ├── luanti.js
    │   ├── luanti.wasm
    │   ├── worker.js
    │   └── packs/
    │       └── base.pack
    └── ...
```

## Dockerfile.vite

```dockerfile
FROM node:20-slim

WORKDIR /app

# Copy package files
COPY custom_frontend/package.json custom_frontend/package-lock.json* ./

# Install dependencies
RUN npm ci --no-progress

# Copy source
COPY custom_frontend/src ./src

# Runtime: www wird gemountet, RELEASE_UUID gesetzt
ENV RELEASE_UUID=dev

ENTRYPOINT ["npm", "run", "build"]
```

**Vorteile:**
- ✓ Dependencies nur einmal installiert (im Image)
- ✓ Schnelle Wiederholungsläufe (Cache)
- ✓ Isoliert vom Host-System
- ✓ CI/CD ready

## Build-Prozess

```bash
$ ./build.sh

=> Docker Image bauen (Luanti Builder)
=> www/ extrahieren
=> UUID erkannt: c9e9c5c8b672
=> Dockerfile.vite Image bauen
=> Vite Container ausführen
=> Output zu www/ kopieren

✓ Fertig!
```

## Variablensubstitution

In `src/index.html`:

```html
<script src="/__RELEASE_UUID__/launcher.js"></script>
```

Wird zu:

```html
<script src="/c9e9c5c8b672/launcher.js"></script>
```

Das geschieht durch:
1. **vite.config.js** liest RELEASE_UUID
2. `define.__RELEASE_UUID__` setzt die Variable
3. Vite ersetzt beim HTML-Build
