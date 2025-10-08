# Guide de Build - Mecaviv QML UI

Guide complet pour builder, développer et déployer les applications du monorepo.

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [Installation](#-installation)
- [Build des Projets](#-build-des-projets)
- [Développement](#-développement)
- [Déploiement](#-déploiement)
- [Troubleshooting](#-troubleshooting)
- [Optimisations](#-optimisations)

## 🔧 Prérequis

### Système d'Exploitation

Le système a été testé sur :
- **macOS** 12.0+ (Monterey ou plus récent)
- **Linux** (Ubuntu 20.04+, Debian 11+, Raspberry Pi OS)
- **Windows** 10/11 (avec adaptations des scripts)

### Logiciels Requis

#### Qt 6.10+ avec WebAssembly

**Installation** :
1. Télécharger Qt depuis [qt.io/download](https://www.qt.io/download)
2. Installer avec le **Qt Online Installer**
3. Sélectionner les composants :
   - Qt 6.10.0 (ou plus récent)
   - Qt for WebAssembly (wasm_singlethread)
   - Qt Quick
   - Qt Quick 3D
   - Qt WebSockets

**Vérification** :
```bash
# Vérifier que qt-cmake est accessible
ls /Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake

# Afficher la version
/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake --version
```

**Configuration du chemin** :
Si Qt est installé ailleurs, modifier `scripts/build-project.sh` :
```bash
QT_CMAKE="/votre/chemin/Qt/6.10.0/wasm_singlethread/bin/qt-cmake"
```

#### Node.js 18+

**Installation macOS** :
```bash
# Avec Homebrew
brew install node

# Vérifier
node --version  # doit afficher v18.x ou plus
npm --version
```

**Installation Linux** :
```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Vérifier
node --version
npm --version
```

#### CMake 3.16+

**Installation macOS** :
```bash
brew install cmake
cmake --version
```

**Installation Linux** :
```bash
sudo apt-get install cmake
cmake --version
```

#### Emscripten SDK

Normalement installé avec Qt WebAssembly. Si nécessaire :

```bash
# Cloner le SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Installer et activer
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

#### Google Chrome

Requis pour le développement (DevTools).

```bash
# macOS : Télécharger depuis google.com/chrome
# Linux : 
sudo apt-get install google-chrome-stable
```

## 📦 Installation

### Cloner le Dépôt

```bash
# Clone le monorepo
git clone <repository-url> mecaviv-qml-ui
cd mecaviv-qml-ui

# Vérifier la structure
ls -la
# Doit afficher : SirenePupitre, SirenConsole, pedalierSirenium, sirenRouter, scripts, docs
```

### Installation Rapide (Tous les Projets)

```bash
# Build tous les projets (5-10 minutes)
./scripts/build-all.sh
```

**Ce que fait le script** :
1. Build SirenePupitre en WebAssembly
2. Build SirenConsole en WebAssembly
3. Build pedalierSirenium en WebAssembly
4. Installation Node.js pour sirenRouter
5. Copie des fichiers dans webfiles/

## 🔨 Build des Projets

### Build Individuel

Pour builder un seul projet :

```bash
# SirenePupitre
./scripts/build-project.sh sirenepupitre

# SirenConsole
./scripts/build-project.sh sirenconsole

# pedalierSirenium
./scripts/build-project.sh pedalier

# sirenRouter (npm install)
./scripts/build-project.sh router
```

### Build Manuel (Méthode Détaillée)

#### SirenePupitre

```bash
cd SirenePupitre
mkdir -p build
cd build

# Configuration CMake avec Qt WebAssembly
/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..

# Compilation (utilise tous les cores)
make -j$(sysctl -n hw.ncpu)

# Copie vers webfiles
cp appSirenePupitre.* ../webfiles/
```

#### SirenConsole

```bash
cd SirenConsole
mkdir -p build
cd build

# Configuration CMake
/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..

# Compilation
make -j$(sysctl -n hw.ncpu)

# Copie vers webfiles
cp appSirenConsole.* ../webfiles/
```

#### pedalierSirenium

```bash
cd pedalierSirenium/QtFiles
mkdir -p build
cd build

# Configuration CMake
/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..

# Compilation
make -j$(sysctl -n hw.ncpu)

# Copie vers webfiles
cp qmlwebsocketserver.* ../../webfiles/
```

#### sirenRouter

```bash
cd sirenRouter

# Installation dépendances Node.js
npm install

# Optionnel : créer package.json si absent
cat > package.json << EOF
{
  "name": "siren-router",
  "version": "1.0.0",
  "description": "Service de monitoring pour sirènes",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js"
  }
}
EOF

npm install express ws
```

### Nettoyage

Pour nettoyer tous les builds :

```bash
# Nettoyage complet (build/, node_modules/, *.wasm, logs)
./scripts/clean-all.sh
```

Pour nettoyer manuellement :

```bash
# Supprimer les dossiers build
rm -rf SirenePupitre/build
rm -rf SirenConsole/build
rm -rf pedalierSirenium/QtFiles/build

# Supprimer node_modules
rm -rf sirenRouter/node_modules
rm -rf SirenConsole/webfiles/node_modules
rm -rf pedalierSirenium/webfiles/node_modules

# Supprimer les fichiers wasm
find . -name "*.wasm" -delete
```

## 💻 Développement

### Mode Développement Rapide

Le script `dev.sh` automatise : build + serveur + ouverture navigateur.

```bash
# SirenePupitre (port 8000)
./scripts/dev.sh sirenepupitre

# SirenConsole (port 8001)
./scripts/dev.sh sirenconsole

# pedalierSirenium (port 8010)
./scripts/dev.sh pedalier

# sirenRouter (ports 8002-8004)
./scripts/dev.sh router
```

**Workflow de développement** :
1. Lancer `./scripts/dev.sh <project>`
2. Chrome s'ouvre avec DevTools
3. Modifier le code QML
4. Ctrl+C pour arrêter
5. Relancer pour rebuilder

### Serveur Manuel

Pour lancer uniquement le serveur (sans rebuild) :

```bash
# SirenePupitre
cd SirenePupitre/webfiles
node server.js 8000

# SirenConsole
cd SirenConsole/webfiles
node server.js 8001

# pedalierSirenium
cd pedalierSirenium/webfiles
node server.js 8010
```

Ouvrir manuellement : `http://localhost:<port>`

### Hot Reload

Qt WebAssembly **ne supporte pas** le hot reload natif. Pour tester rapidement :

1. Modifier le code QML
2. Sauvegarder
3. Rebuilder : `./scripts/build-project.sh <project>`
4. Recharger la page dans le navigateur (F5)

### Debug dans le Navigateur

#### Console JavaScript

```bash
# Ouvrir DevTools : F12 ou Cmd+Opt+I

# Logs QML apparaissent dans la console
console.log("Message depuis QML")
```

#### Network Inspector

Vérifier les communications WebSocket :
1. F12 → Onglet "Network"
2. Filter "WS" (WebSocket)
3. Cliquer sur une connexion pour voir les messages

#### Memory Profiling

Pour détecter les fuites mémoire :
1. F12 → Onglet "Memory"
2. Take Heap Snapshot
3. Comparer avant/après actions

### Logs Serveur

Les serveurs Node.js créent des logs :

```bash
# Voir les logs en temps réel
tail -f /tmp/sirenepupitre_server.log
tail -f /tmp/sirenconsole_server.log
tail -f /tmp/pedalier_server.log

# Logs du build
tail -f SirenePupitre/build/build.log
```

## 🚀 Déploiement

### Déploiement Local (Tests)

```bash
# Build tous les projets
./scripts/build-all.sh

# Lancer les applications
./scripts/dev.sh sirenepupitre &
./scripts/dev.sh sirenconsole &
./scripts/dev.sh pedalier &
./scripts/dev.sh router &

# Accéder aux URLs
# http://localhost:8000 - SirenePupitre
# http://localhost:8001 - SirenConsole
# http://localhost:8010 - pedalierSirenium
# http://localhost:8002 - sirenRouter API
```

### Déploiement sur Raspberry Pi

#### Préparation

```bash
# Sur la machine de dev : build
./scripts/build-all.sh

# Créer une archive
tar -czf mecaviv-qml-ui.tar.gz \
  SirenePupitre/webfiles \
  SirenConsole/webfiles \
  pedalierSirenium/webfiles \
  sirenRouter
```

#### Installation sur Raspberry Pi

```bash
# Copier l'archive
scp mecaviv-qml-ui.tar.gz pi@192.168.1.20:/home/pi/

# Se connecter au Pi
ssh pi@192.168.1.20

# Extraire
cd /home/pi
tar -xzf mecaviv-qml-ui.tar.gz

# Installer Node.js si nécessaire
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt-get install -y nodejs

# Installer Chromium
sudo apt-get install -y chromium-browser

# Démarrer les services
cd SirenePupitre/webfiles
node server.js 8000 &

cd ../SirenConsole/webfiles
node server.js 8001 &

# etc...
```

#### Service systemd (Auto-démarrage)

Créer `/etc/systemd/system/sirenepupitre.service` :

```ini
[Unit]
Description=SirenePupitre Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/mecaviv-qml-ui/SirenePupitre/webfiles
ExecStart=/usr/bin/node server.js 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Activer :
```bash
sudo systemctl daemon-reload
sudo systemctl enable sirenepupitre
sudo systemctl start sirenepupitre

# Vérifier
sudo systemctl status sirenepupitre
```

Répéter pour les autres services.

### Déploiement Web (Production)

#### Avec Nginx

```nginx
# /etc/nginx/sites-available/mecaviv

server {
    listen 80;
    server_name mecaviv.local;

    # SirenePupitre
    location /pupitre {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # SirenConsole
    location /console {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # pedalierSirenium
    location /pedalier {
        proxy_pass http://localhost:8010;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # sirenRouter API
    location /api {
        proxy_pass http://localhost:8002;
    }
}
```

Activer :
```bash
sudo ln -s /etc/nginx/sites-available/mecaviv /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### Avec Docker (Futur)

Structure des Dockerfiles à venir dans v1.2.

## 🐛 Troubleshooting

### Erreur "qt-cmake not found"

**Cause** : Qt WebAssembly pas installé ou mauvais chemin.

**Solution** :
```bash
# Vérifier l'installation Qt
ls /Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake

# Si absent, réinstaller Qt avec le composant WebAssembly

# Si différent, modifier scripts/build-project.sh
nano scripts/build-project.sh
# Changer QT_CMAKE="/votre/chemin/qt-cmake"
```

### Erreur "Port already in use"

**Cause** : Un serveur tourne déjà sur le port.

**Solution** :
```bash
# Automatique avec clean-all
./scripts/clean-all.sh

# Ou manuellement
lsof -ti:8000 | xargs kill -9
lsof -ti:8001 | xargs kill -9
lsof -ti:8010 | xargs kill -9
```

### Build échoue avec "emscripten not found"

**Cause** : Emscripten SDK pas activé.

**Solution** :
```bash
# Activer Emscripten (inclus avec Qt WebAssembly)
source /Users/patricecolet/Qt/6.10.0/wasm_singlethread/emsdk/emsdk_env.sh

# Vérifier
em++ --version
```

### Fichiers .wasm très gros (>100MB)

**Cause** : Build en mode Debug.

**Solution** :
```bash
# Build en mode Release
cd build
/path/to/qt-cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)

# Tailles attendues :
# Debug: 80-120 MB
# Release: 30-40 MB
```

### WebSocket ne se connecte pas

**Cause** : Serveur WebSocket pas démarré ou mauvais port.

**Solution** :
```bash
# Vérifier que PureData tourne (port 10001)
lsof -i:10001

# Vérifier la config WebSocket
cat SirenePupitre/config.js | grep serverUrl
# Doit correspondre au serveur PureData
```

### Interface ne charge pas dans Chrome

**Cause** : Fichiers WASM pas copiés ou serveur pas démarré.

**Solution** :
```bash
# Vérifier les fichiers webfiles
ls -lh SirenePupitre/webfiles/*.wasm
ls -lh SirenePupitre/webfiles/*.js
ls -lh SirenePupitre/webfiles/*.html

# Si absents, rebuilder
./scripts/build-project.sh sirenepupitre

# Vérifier le serveur
curl http://localhost:8000
# Doit retourner du HTML
```

### Erreur CMake "Qt6 not found"

**Cause** : Qt pas dans le PATH ou mauvaise version.

**Solution** :
```bash
# Utiliser qt-cmake au lieu de cmake
/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..

# Ou ajouter Qt au PATH
export PATH="/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin:$PATH"
cmake ..
```

## ⚡ Optimisations

### Build Plus Rapide

```bash
# Utiliser tous les cores CPU
make -j$(sysctl -n hw.ncpu)

# Ou spécifier le nombre
make -j8

# Utiliser Ninja au lieu de Make
/path/to/qt-cmake .. -GNinja
ninja
```

### Cache CMake

```bash
# Utiliser ccache pour accélérer les recompilations
brew install ccache  # macOS
sudo apt-get install ccache  # Linux

# Configurer CMake
cmake .. -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
```

### Build Incrémental

```bash
# Ne rebuild que les fichiers modifiés
cd build
make

# Si erreur, clean et rebuild
make clean
make -j$(sysctl -n hw.ncpu)
```

### Optimisation Taille WASM

```bash
# Build Release avec optimisations
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)

# Activer LTO (Link Time Optimization)
cmake .. -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
make -j$(sysctl -n hw.ncpu)
```

### Performance Runtime

**Dans main.cpp** :
```cpp
// Activer le mode Release
#define QT_NO_DEBUG_OUTPUT
#define QT_NO_INFO_OUTPUT
```

**Dans QML** :
```qml
// Désactiver les logs de performance
Settings {
    property bool enableDebugLogs: false
}
```

## 📊 Métriques de Build

### Temps de Build (Machine Test : M1 MacBook Pro)

| Projet | Temps (Debug) | Temps (Release) |
|--------|---------------|-----------------|
| SirenePupitre | 2m 30s | 3m 15s |
| SirenConsole | 1m 45s | 2m 20s |
| pedalierSirenium | 3m 00s | 4m 00s |
| sirenRouter | 10s | 10s |
| **Total** | **7m 25s** | **9m 45s** |

### Taille des Fichiers

| Projet | WASM (Debug) | WASM (Release) |
|--------|--------------|----------------|
| SirenePupitre | 95 MB | 38 MB |
| SirenConsole | 82 MB | 34 MB |
| pedalierSirenium | 108 MB | 42 MB |

## 📚 Références

- [Documentation Qt WebAssembly](https://doc.qt.io/qt-6/wasm.html)
- [Emscripten Documentation](https://emscripten.org/docs/)
- [Qt Quick 3D](https://doc.qt.io/qt-6/qtquick3d-index.html)
- [Qt WebSockets](https://doc.qt.io/qt-6/qtwebsockets-index.html)

---

Pour l'architecture complète, voir [ARCHITECTURE.md](./ARCHITECTURE.md).  
Pour les protocoles de communication, voir [COMMUNICATION.md](./COMMUNICATION.md).

