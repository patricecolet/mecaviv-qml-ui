# Scripts SirenePupitre

Ce dossier contient tous les scripts bash pour automatiser le développement et le déploiement du projet SirenePupitre.

## Scripts disponibles

### 🔨 `build.sh` - Script de build
Build le projet pour WebAssembly uniquement.

**Usage:**
```bash
./scripts/build.sh [OPTION]
```

**Options:**
- `web` - Build pour WebAssembly
- `clean` - Nettoyer les dossiers de build
- `help` - Afficher l'aide

**Exemples:**
```bash
./scripts/build.sh web
./scripts/build.sh clean
```

### 🌐 `start-server.sh` - Démarrage du serveur
Démarre le serveur Node.js pour le développement WebAssembly.

**Usage:**
```bash
./scripts/start-server.sh [PORT]
```

**Arguments:**
- `PORT` - Port du serveur (défaut: 8000)

**Exemples:**
```bash
./scripts/start-server.sh
./scripts/start-server.sh 8080
```

### 📡 `atim-diagnostic.sh` - Diagnostic carte ATIM ARM-Nano
Vérifie la configuration UART et les prérequis pour la carte radio ATIM.

**Usage :** Exécuter sur le Raspberry Pi (directement ou via SSH)
```bash
./scripts/atim-diagnostic.sh
```

Voir `docs/ATIM_ARM_NANO_GUIDE.md` pour le guide complet.

### 🍓 `start-raspberry.sh` - Démarrage Raspberry Pi 5
Script optimisé pour Raspberry Pi 5 avec Chrome et PureData.

**Usage:**
```bash
./scripts/start-raspberry.sh [OPTION]
```

**Options:**
- `start` - Démarre l'application complète (serveur + PureData + Chrome)
- `server` - Démarre seulement le serveur
- `puredata` - Démarre seulement PureData
- `browser` - Ouvre seulement le navigateur
- `stop` - Arrête tous les processus
- `help` - Afficher l'aide

**Exemples:**
```bash
./scripts/start-raspberry.sh start
./scripts/start-raspberry.sh server
./scripts/start-raspberry.sh stop
```

### 🚀 `dev.sh` - Mode développement
Script de développement qui combine build, serveur et ouverture de Chrome.

**Usage:**
```bash
./scripts/dev.sh [OPTION]
```

**Options:**
- `web` - Build WebAssembly + démarre le serveur + ouvre Chrome
- `server` - Démarre seulement le serveur + ouvre Chrome
- `help` - Afficher l'aide

**Exemples:**
```bash
./scripts/dev.sh web
./scripts/dev.sh server
```

### 🎨 `convert-mesh.sh` - Conversion de modèles 3D
Convertit un fichier .obj en .mesh pour Qt Quick 3D en gérant automatiquement les fichiers temporaires.

**Usage:**
```bash
./scripts/convert-mesh.sh <fichier.obj> <nom_final.mesh>
```

**Arguments:**
- `fichier.obj` - Fichier source au format Wavefront OBJ
- `nom_final.mesh` - Nom du fichier .mesh de sortie

**Exemples:**
```bash
./scripts/convert-mesh.sh TrebleKey.obj TrebleKey.mesh
./scripts/convert-mesh.sh BassKey.obj BassKey.mesh
```

**Fonctionnalités:**
- Détecte automatiquement l'outil balsam de Qt
- Gère le sous-dossier meshes/ créé par balsam
- Nettoie automatiquement les fichiers temporaires (.qml)
- Affiche la taille du fichier généré

### 🎼 `convert-clefs.sh` - Conversion des clés musicales
Convertit automatiquement les deux clés musicales (Sol et Fa) en une seule commande.

**Usage:**
```bash
./scripts/convert-clefs.sh
```

**Actions:**
- Convertit `TrebleKey.obj` → `TrebleKey.mesh`
- Convertit `BassKey.obj` → `BassKey.mesh`
- Affiche un résumé des fichiers générés

## Workflow de développement

### Développement Web (WebAssembly)
```bash
# Build, serveur et Chrome en une commande
./scripts/dev.sh web

# Ou étape par étape
./scripts/build.sh web
./scripts/start-server.sh
# Ouvrir Chrome manuellement sur http://localhost:8000
```

### Serveur seulement (si build déjà fait)
```bash
# Démarre le serveur et ouvre Chrome
./scripts/dev.sh server
```

### Raspberry Pi 5
```bash
# Démarrage complet (serveur + PureData + Chrome)
./scripts/start-raspberry.sh start

# Arrêt de tous les processus
./scripts/start-raspberry.sh stop
```

### Nettoyage
```bash
./scripts/build.sh clean
```

## Dépendances requises

### Pour le build WebAssembly
- CMake (3.16+)
- Qt6 pour WebAssembly (wasm_singlethread) avec qt-cmake
- Node.js (pour le serveur de développement)

### Pour le serveur
- Node.js

### Pour l'ouverture automatique
- Google Chrome (ou Chromium)

### Pour Raspberry Pi 5
- Chromium-browser (installé par défaut sur Raspberry Pi OS)
- PureData (pd)
- Node.js

## Notes techniques

- Les scripts utilisent des couleurs pour une meilleure lisibilité
- Gestion automatique des erreurs avec `set -e`
- Vérification des dépendances avant exécution
- Gestion des processus (arrêt propre avec Ctrl+C)
- Support multi-plateforme (Linux, macOS, Windows)

## Dépannage

### Erreur "CMake n'est pas installé"
```bash
# Ubuntu/Debian
sudo apt install cmake

# macOS
brew install cmake

# Windows
# Télécharger depuis https://cmake.org/download/
```

### Erreur "Emscripten n'est pas installé"
```bash
# Installer Emscripten
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

### Erreur "Qt6 non trouvé"
```bash
# Ubuntu/Debian
sudo apt install qt6-base-dev qt6-quick-dev qt6-quick3d-dev

# macOS
brew install qt6

# Windows
# Installer Qt6 depuis https://www.qt.io/download
```
