# Guide de Build - Mecaviv QML UI

Guide complet pour builder, développer et déployer les applications du monorepo.

> 💡 **Recommandé** : Utilisez **CMake** pour un build multiplateforme (Windows, macOS, Linux).  
> Les scripts bash sont maintenus pour compatibilité mais ne fonctionnent que sur Unix.

> ⚙️ **Configuration Requise** : Avant de commencer, configurez les chemins Qt en suivant le guide [CONFIG.md](../CONFIG.md).

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [🏗️ Build avec CMake (Recommandé)](#️-build-avec-cmake-recommandé)
- [🔧 Build avec Scripts Bash (Legacy)](#-build-avec-scripts-bash-legacy)
- [Développement](#-développement)
- [Déploiement](#-déploiement)
- [Troubleshooting](#-troubleshooting)
- [Optimisations](#-optimisations)

## 🔧 Prérequis

### Système d'Exploitation

Le système supporte :
- ✅ **macOS** 12.0+ (Monterey ou plus récent)
- ✅ **Linux** (Ubuntu 20.04+, Debian 11+, Raspberry Pi OS)
- ✅ **Windows** 10/11

### Logiciels Requis

#### CMake 3.19+

**macOS** :
```bash
brew install cmake ninja
cmake --version  # doit afficher 3.19+
```

**Linux** :
```bash
sudo apt-get install cmake ninja-build
cmake --version
```

**Windows** :
- Télécharger depuis [cmake.org/download](https://cmake.org/download/)
- Installer avec "Add CMake to PATH"

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
# macOS/Linux
ls $HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake

# Windows
dir C:\Qt\6.10.0\wasm_singlethread\bin\qt-cmake.bat
```

#### Node.js 18+

**macOS** :
```bash
brew install node
node --version  # doit afficher v18.x+
```

**Linux** :
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Windows** :
- Télécharger depuis [nodejs.org](https://nodejs.org/)

#### Emscripten SDK (pour WebAssembly)

Normalement inclus avec Qt WebAssembly. Si nécessaire :

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

---

## 🏗️ Build avec CMake (Recommandé)

### Pourquoi CMake ?

- ✅ **Multiplateforme** : Windows, macOS, Linux, WebAssembly
- ✅ **Intégration IDE** : Qt Creator, CLion, Visual Studio, VS Code
- ✅ **Build parallèle** optimisé
- ✅ **Configuration via presets** pour différentes cibles
- ✅ **Gestion des dépendances** automatique

### 🚀 Quick Start

#### Étape 1 : Configuration

```bash
# Desktop natif (Debug)
cmake --preset=default

# Desktop natif (Release)
cmake --preset=release

# WebAssembly
cmake --preset=wasm

# Spécifique plateforme
cmake --preset=macos       # macOS uniquement
cmake --preset=linux       # Linux uniquement
cmake --preset=windows     # Windows uniquement
cmake --preset=raspberry-pi # Raspberry Pi optimisé
```

**Ou utilisez les scripts helper** :

```bash
# Unix (macOS/Linux)
./scripts/configure.sh default   # ou release, wasm, etc.

# Windows
scripts\configure.ps1 default
```

#### Étape 2 : Build

```bash
# Builder tout
cmake --build build

# Builder avec le preset
cmake --build --preset=default

# Build parallèle (utilise tous les cores)
cmake --build build --parallel

# Builder un projet spécifique
cmake --build build --target appSirenePupitre
cmake --build build --target appSirenConsole
cmake --build build --target qmlwebsocketserver
cmake --build build --target sirenRouter
```

#### Étape 3 : Nettoyage

```bash
# Nettoyer le build
cmake --build build --target clean

# Nettoyer tout (inclus node_modules)
cmake --build build --target clean_all

# Ou supprimer le dossier
rm -rf build
```

### 📋 Presets Disponibles

| Preset | Description | Utilisation |
|--------|-------------|-------------|
| `default` | Build Debug desktop natif | Développement local |
| `release` | Build Release desktop optimisé | Production desktop |
| `wasm` | Build WebAssembly (Release) | Déploiement web |
| `macos` | Build natif macOS (Universal) | Distribution macOS |
| `linux` | Build natif Linux | Distribution Linux |
| `windows` | Build natif Windows (Visual Studio) | Distribution Windows |
| `raspberry-pi` | Build optimisé Raspberry Pi | Déploiement RPi 4/5 |

### 🎯 Workflows Typiques

#### Développement Desktop

```bash
# Configuration initiale
cmake --preset=default

# Build
cmake --build build

# Lancer l'application
./build/SirenePupitre/appSirenePupitre
./build/SirenConsole/appSirenConsole
./build/pedalierSirenium/QtFiles/qmlwebsocketserver
```

#### Build WebAssembly

```bash
# Configuration pour WASM
cmake --preset=wasm

# Build
cmake --build build-wasm

# Les fichiers WASM sont automatiquement copiés dans webfiles/
# Lancer le serveur
cd SirenePupitre/webfiles
node server.js 8000
```

#### Build Release Multi-Projets

```bash
# Configuration Release
cmake --preset=release

# Build seulement certains projets
cmake --build build --target appSirenePupitre --target appSirenConsole

# Ou avec options
cmake -DBUILD_PEDALIER=OFF --preset=release
cmake --build build
```

### ⚙️ Options de Configuration

Modifier les options via la ligne de commande :

```bash
# Désactiver certains projets
cmake -DBUILD_PEDALIER=OFF --preset=default

# Build sans Node.js
cmake -DINSTALL_NODE_DEPS=OFF --preset=default

# Ne pas copier vers webfiles
cmake -DCOPY_TO_WEBFILES=OFF --preset=wasm
```

### 🔌 Intégration IDE

#### Qt Creator

1. Ouvrir Qt Creator
2. File → Open File or Project
3. Sélectionner `CMakeLists.txt` racine
4. Qt Creator détectera automatiquement les presets
5. Build → Build All

#### CLion / IntelliJ

1. Open Project → Sélectionner le dossier racine
2. CLion détecte `CMakeLists.txt`
3. Settings → Build → CMake → Sélectionner un preset
4. Build → Build Project

#### Visual Studio Code

1. Installer l'extension "CMake Tools"
2. Ouvrir le dossier racine
3. Cmd/Ctrl+Shift+P → "CMake: Select Configure Preset"
4. Sélectionner un preset
5. Build via la barre d'état

#### Visual Studio (Windows)

1. File → Open → CMake
2. Sélectionner `CMakeLists.txt`
3. Visual Studio détecte automatiquement les presets
4. Build → Build All

---

## 🔧 Build avec Scripts Bash (Legacy)

> ⚠️ **Attention** : Ces scripts ne fonctionnent que sur **macOS et Linux**.  
> Pour Windows, utilisez CMake.

### Scripts Disponibles

#### `./scripts/build-all.sh` - Build Complet

Build tous les projets en WebAssembly + installation Node.js.

```bash
./scripts/build-all.sh
```

**Durée** : 5-10 minutes

#### `./scripts/build-project.sh <project>` - Build Individuel

```bash
./scripts/build-project.sh sirenepupitre
./scripts/build-project.sh sirenconsole
./scripts/build-project.sh pedalier
./scripts/build-project.sh router
```

#### `./scripts/dev.sh <project>` - Mode Développement

Build + serveur + ouverture Chrome.

```bash
./scripts/dev.sh sirenepupitre   # Port 8000
./scripts/dev.sh sirenconsole    # Port 8001
./scripts/dev.sh pedalier        # Port 8010
./scripts/dev.sh router          # Ports 8002-8004
```

#### `./scripts/clean-all.sh` - Nettoyage

Supprime build/, node_modules/, *.wasm, logs.

```bash
./scripts/clean-all.sh
```

### Build Manuel (Détaillé)

#### SirenePupitre

```bash
cd SirenePupitre
mkdir -p build && cd build
$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..
make -j$(sysctl -n hw.ncpu)
cp appSirenePupitre.* ../webfiles/
```

#### SirenConsole

```bash
cd SirenConsole
mkdir -p build && cd build
$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..
make -j$(sysctl -n hw.ncpu)
cp appSirenConsole.* ../webfiles/
```

#### pedalierSirenium

```bash
cd pedalierSirenium/QtFiles
mkdir -p build && cd build
$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..
make -j$(sysctl -n hw.ncpu)
cp qmlwebsocketserver.* ../../webfiles/
```

#### sirenRouter

```bash
cd sirenRouter
npm install
npm start
```

---

## 💻 Développement

### Mode Développement avec CMake

#### Workflow Itératif

```bash
# 1. Configuration initiale (une fois)
cmake --preset=default

# 2. Développement
# - Modifier le code QML/C++
# - Rebuild automatique du fichier modifié
cmake --build build

# 3. Test
./build/SirenePupitre/appSirenePupitre

# 4. Répéter 2-3
```

#### Rebuild Incrémental

CMake rebuild uniquement les fichiers modifiés :

```bash
# Après modification de Main.qml
cmake --build build
# → Rebuild uniquement les dépendances nécessaires
```

#### Watch Mode (Linux/macOS)

Utiliser `fswatch` pour rebuild automatique :

```bash
# Installer fswatch
brew install fswatch  # macOS
sudo apt-get install fswatch  # Linux

# Watch et rebuild
fswatch -o SirenePupitre/QML | xargs -n1 -I{} cmake --build build --target appSirenePupitre
```

### Mode Développement avec Scripts Bash

```bash
# Lancer en mode dev (build + serveur + Chrome)
./scripts/dev.sh sirenepupitre

# Modifier le code...
# Ctrl+C pour arrêter

# Relancer pour rebuilder
./scripts/dev.sh sirenepupitre
```

### Hot Reload

⚠️ Qt WebAssembly **ne supporte pas** le hot reload natif.

Workflow recommandé :
1. Modifier le code QML
2. Sauvegarder
3. Rebuilder : `cmake --build build --target <projet>`
4. Recharger la page (F5)

### Debug dans le Navigateur

#### Console JavaScript

- Ouvrir DevTools : **F12** ou **Cmd+Opt+I**
- Onglet "Console" pour voir les logs QML
- `console.log()` dans QML apparaît dans la console

#### Network Inspector

Vérifier les WebSocket :
1. F12 → Onglet "Network"
2. Filter "WS" (WebSocket)
3. Cliquer sur une connexion pour voir les messages

#### Memory Profiling

1. F12 → Onglet "Memory"
2. Take Heap Snapshot
3. Comparer avant/après pour détecter les fuites

### Logs et Debugging

```bash
# Logs CMake verbeux
cmake --build build --verbose

# Logs de build détaillés
cmake --build build -- VERBOSE=1

# Logs du serveur
tail -f /tmp/sirenepupitre_server.log
tail -f /tmp/sirenconsole_server.log
```

---

## 🚀 Déploiement

### Déploiement Local (Tests)

```bash
# Build tout en Release
cmake --preset=release
cmake --build build

# Lancer les applications desktop
./build/SirenePupitre/appSirenePupitre &
./build/SirenConsole/appSirenConsole &
```

### Déploiement WebAssembly

```bash
# Build WASM Release
cmake --preset=wasm
cmake --build build-wasm

# Les fichiers sont copiés dans webfiles/
# Lancer les serveurs
cd SirenePupitre/webfiles && node server.js 8000 &
cd SirenConsole/webfiles && node server.js 8001 &
cd pedalierSirenium/webfiles && node server.js 8010 &
```

### Déploiement Raspberry Pi

#### Méthode 1 : Cross-Compilation (recommandée)

```bash
# Sur machine de dev
cmake --preset=raspberry-pi
cmake --build build --target package

# Copier sur le Pi
scp build/mecaviv-qml-ui.tar.gz pi@192.168.1.20:/home/pi/
```

#### Méthode 2 : Build sur le Pi

```bash
# Sur le Raspberry Pi
sudo apt-get install cmake ninja-build qt6-base-dev qt6-quick-dev

# Build
cmake --preset=raspberry-pi
cmake --build build -j4
```

### Service systemd (Auto-démarrage)

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
sudo systemctl status sirenepupitre
```

### Déploiement Web (Nginx)

```nginx
server {
    listen 80;
    server_name mecaviv.local;

    location /pupitre {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /console {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## 🐛 Troubleshooting

### Erreur "CMake not found"

**Cause** : CMake pas installé ou pas dans le PATH.

**Solution** :
```bash
# macOS
brew install cmake

# Linux
sudo apt-get install cmake

# Windows
# Réinstaller CMake avec "Add to PATH"
```

### Erreur "Qt6 not found"

**Cause** : Qt pas installé ou CMAKE_PREFIX_PATH incorrect.

**Solution** :
```bash
# Vérifier installation Qt
ls $HOME/Qt/6.10.0/

# Modifier CMakePresets.json
# Ajuster CMAKE_PREFIX_PATH vers votre installation Qt
```

### Erreur "Ninja not found"

**Cause** : Générateur Ninja pas installé.

**Solution** :
```bash
# macOS
brew install ninja

# Linux
sudo apt-get install ninja-build

# Windows
# Télécharger depuis github.com/ninja-build/ninja
```

### Erreur "Port already in use"

**Cause** : Un serveur tourne déjà sur le port.

**Solution** :
```bash
# Tuer le processus
lsof -ti:8000 | xargs kill -9

# Ou utiliser le script
./scripts/clean-all.sh
```

### Build échoue avec "emscripten not found"

**Cause** : Emscripten SDK pas activé.

**Solution** :
```bash
# Activer Emscripten (inclus avec Qt WebAssembly)
source $HOME/Qt/6.10.0/wasm_singlethread/emsdk/emsdk_env.sh

# Vérifier
em++ --version
```

### Fichiers WASM très gros (>100MB)

**Cause** : Build en mode Debug.

**Solution** :
```bash
# Utiliser le preset Release
cmake --preset=release
# ou
cmake --preset=wasm  # déjà en Release
```

### WebSocket ne se connecte pas

**Cause** : Serveur WebSocket pas démarré ou mauvais port.

**Solution** :
```bash
# Vérifier que PureData tourne (port 10001)
lsof -i:10001

# Vérifier config
cat SirenePupitre/config.js | grep serverUrl
```

---

## ⚡ Optimisations

### Build Plus Rapide

```bash
# Utiliser tous les cores
cmake --build build --parallel

# Spécifier le nombre de jobs
cmake --build build -j8

# Utiliser ccache
sudo apt-get install ccache  # Linux
brew install ccache          # macOS

cmake -DCMAKE_CXX_COMPILER_LAUNCHER=ccache --preset=default
```

### Build Incrémental

CMake rebuild automatiquement uniquement les fichiers modifiés :

```bash
# Première compilation : longue
cmake --build build

# Modifications mineures : rapide
cmake --build build
```

### Cache CMake

```bash
# Utiliser le cache de configuration
cmake --preset=default  # Première fois
cmake --build build      # Utilise le cache

# Nettoyer le cache si problème
rm -rf build/CMakeCache.txt
cmake --preset=default
```

### Optimisation Taille WASM

```bash
# Build avec optimisations de taille
cmake -DCMAKE_BUILD_TYPE=MinSizeRel --preset=wasm

# Activer LTO (Link Time Optimization)
cmake -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON --preset=wasm
```

### Performance Runtime

Dans `CMakeLists.txt` :
```cmake
# Mode Release avec optimisations
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Désactiver les logs de debug
add_definitions(-DQT_NO_DEBUG_OUTPUT)
```

---

## 📊 Métriques de Build

### Temps de Build (M1 MacBook Pro)

| Projet | Debug | Release | WASM |
|--------|-------|---------|------|
| SirenePupitre | 2m 30s | 3m 15s | 3m 45s |
| SirenConsole | 1m 45s | 2m 20s | 2m 50s |
| pedalierSirenium | 3m 00s | 4m 00s | 4m 30s |
| sirenRouter | 10s | 10s | 10s |
| **Total** | **7m 25s** | **9m 45s** | **11m 15s** |

### Taille des Fichiers

| Projet | WASM Debug | WASM Release |
|--------|------------|--------------|
| SirenePupitre | 95 MB | 38 MB |
| SirenConsole | 82 MB | 34 MB |
| pedalierSirenium | 108 MB | 42 MB |

---

## 📚 Références

- [CMake Documentation](https://cmake.org/documentation/)
- [Qt CMake Manual](https://doc.qt.io/qt-6/cmake-manual.html)
- [Qt WebAssembly](https://doc.qt.io/qt-6/wasm.html)
- [CMake Presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html)
- [Ninja Build](https://ninja-build.org/)

---

Pour l'architecture complète, voir [ARCHITECTURE.md](./ARCHITECTURE.md).  
Pour les protocoles de communication, voir [COMMUNICATION.md](./COMMUNICATION.md).
