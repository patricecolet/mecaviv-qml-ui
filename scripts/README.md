# Scripts de Build Centralisés

Scripts pour builder et développer tous les projets du monorepo mecaviv-qml-ui.

> ⚠️ **Note Windows** : Les scripts `.sh` (bash) fonctionnent uniquement sur macOS/Linux.  
> Pour Windows, utilisez les scripts `.ps1` (PowerShell) ou CMake directement.  
> Voir [../docs/BUILD.md](../docs/BUILD.md) pour le guide Windows complet.

## 📋 Scripts Disponibles

### Scripts Unix (macOS/Linux)

Les scripts `.sh` ci-dessous ne fonctionnent que sur macOS et Linux.

#### `build-all.sh` - Build de tous les projets

Build tous les projets Qt/QML en WebAssembly + installation de sirenRouter.

```bash
./scripts/build-all.sh
```

**Durée estimée** : 5-10 minutes selon la machine

**Ce qu'il fait** :
- Build SirenePupitre en WebAssembly
- Build SirenConsole en WebAssembly
- Build pedalierSirenium en WebAssembly
- Installation des dépendances Node.js pour sirenRouter

### `build-project.sh <project>` - Build d'un projet spécifique

Build un seul projet.

```bash
./scripts/build-project.sh sirenepupitre
./scripts/build-project.sh sirenconsole
./scripts/build-project.sh pedalier
./scripts/build-project.sh router
```

**Projets disponibles** :
- `sirenepupitre` : SirenePupitre (Visualiseur musical)
- `sirenconsole` : SirenConsole (Console de contrôle)
- `pedalier` : pedalierSirenium (Interface pédalier 3D)
- `router` : sirenRouter (Service monitoring Node.js)

### `dev.sh <project>` - Mode développement

Build + Serveur + Ouverture du navigateur pour développement rapide.

```bash
./scripts/dev.sh sirenepupitre   # Port 8000
./scripts/dev.sh sirenconsole    # Port 8001
./scripts/dev.sh pedalier        # Port 8010
./scripts/dev.sh router          # Port 8002-8004
```

**Ce qu'il fait** :
1. Tue les serveurs existants sur le port
2. Build le projet
3. Démarre le serveur Node.js
4. Ouvre Chrome avec DevTools

**Ports utilisés** :
- SirenePupitre : `8000`
- SirenConsole : `8001`
- pedalierSirenium : `8010`
- sirenRouter : `8002` (API REST), `8003` (WebSocket), `8004` (UDP)

### `clean-all.sh` - Nettoyage complet

Supprime tous les dossiers de build, node_modules et fichiers temporaires.

```bash
./scripts/clean-all.sh
```

**Ce qu'il fait** :
- Supprime tous les `build/` et `build-*/`
- Supprime tous les `node_modules/`
- Supprime les fichiers `.wasm`
- Supprime les logs temporaires
- Tue tous les serveurs en cours

### Scripts PowerShell (Windows)

Les scripts `.ps1` ci-dessous fonctionnent sur Windows avec PowerShell 5.1+.

#### `setup-env.ps1` - Configuration des Variables Qt

Script interactif pour configurer `QT_DIR` et `QT_WASM_DIR`.

```powershell
.\scripts\setup-env.ps1
```

**Ce qu'il fait** :
- Détecte Qt dans `C:\Qt\`
- Vous propose de valider ou personnaliser les chemins
- Optionnellement ajoute aux variables système Windows
- Configuration permanente pour tous les terminaux

#### `configure.ps1` - Configuration CMake

Configuration rapide du projet avec CMake.

```powershell
.\scripts\configure.ps1 default   # Desktop Debug
.\scripts\configure.ps1 release   # Desktop Release
.\scripts\configure.ps1 wasm      # WebAssembly
.\scripts\configure.ps1 windows   # Visual Studio
```

**Prérequis** : Définir `QT_DIR` et `QT_WASM_DIR` avec `setup-env.ps1`.

### Équivalence Scripts

| Unix (macOS/Linux) | Windows (PowerShell) | Description |
|-------------------|----------------------|-------------|
| `./scripts/setup-env.sh` | `.\scripts\setup-env.ps1` | Configuration variables Qt |
| `./scripts/configure.sh` | `.\scripts\configure.ps1` | Configuration CMake |
| `./scripts/build-all.sh` | ❌ (utiliser CMake) | Build tous les projets |
| `./scripts/dev.sh` | ❌ (utiliser CMake) | Mode développement |

**Recommandation Windows** : Utiliser CMake directement plutôt que les scripts bash.

## 🔧 Configuration Requise

### Qt WebAssembly

Les scripts utilisent Qt 6.10.0 avec le toolchain WebAssembly :

```bash
$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake
```

**Installation Qt pour WebAssembly** :
1. Télécharger Qt 6.10+ depuis [qt.io](https://www.qt.io/download)
2. Installer le module **Qt for WebAssembly**
3. Vérifier que `qt-cmake` est disponible

### Node.js

**Version requise** : Node.js 18+

```bash
node --version  # Vérifier la version
npm --version
```

### Emscripten (pour Qt WebAssembly)

Qt WebAssembly nécessite Emscripten. Normalement installé avec Qt.

## 🚀 Workflow de Développement

### Première utilisation

```bash
# 1. Build tous les projets
./scripts/build-all.sh

# 2. Tester un projet
./scripts/dev.sh sirenepupitre
```

### Développement quotidien

```bash
# Développer sur un projet spécifique
./scripts/dev.sh sirenconsole

# Modifier le code QML...
# Ctrl+C pour arrêter le serveur

# Rebuild et relancer
./scripts/dev.sh sirenconsole
```

### Nettoyage et rebuild complet

```bash
# Nettoyer tout
./scripts/clean-all.sh

# Rebuild tout
./scripts/build-all.sh
```

## 📦 Structure des Projets

### Projets Qt/QML (SirenePupitre, SirenConsole)

```
ProjectName/
├── CMakeLists.txt
├── main.cpp
├── config.js
├── QML/
├── build/              # Créé par le build
└── webfiles/           # Fichiers pour le serveur
    ├── server.js
    └── [fichiers compilés]
```

### pedalierSirenium (structure différente)

```
pedalierSirenium/
├── QtFiles/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── qml/
│   └── build/          # Créé par le build
├── pd/                 # Patches PureData
└── webfiles/           # Fichiers pour le serveur
```

### sirenRouter (Node.js)

```
sirenRouter/
├── package.json
├── src/
│   ├── server.js
│   └── api/
└── node_modules/       # Créé par npm install
```

## 🐛 Dépannage

### Erreur "qt-cmake not found"

Vérifier le chemin dans `build-project.sh` :

```bash
QT_CMAKE="$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake"
```

Ajuster selon votre installation Qt.

### Port déjà utilisé

Le script `dev.sh` tue automatiquement les processus sur le port, mais si ça ne marche pas :

```bash
# Tuer manuellement
lsof -ti:8000 | xargs kill -9

# Ou utiliser clean-all
./scripts/clean-all.sh
```

### Build échoue

```bash
# Nettoyer et réessayer
./scripts/clean-all.sh
./scripts/build-project.sh <project>
```

### Fichiers wasm très gros

Les fichiers `.wasm` peuvent faire 30-40 MB. C'est normal pour Qt WebAssembly.

## 📝 Logs

Les serveurs créent des logs temporaires :

```bash
# Voir les logs d'un serveur
tail -f /tmp/sirenepupitre_server.log
tail -f /tmp/sirenconsole_server.log
tail -f /tmp/pedalier_server.log
```

## 🔗 Liens Utiles

- [Documentation Qt WebAssembly](https://doc.qt.io/qt-6/wasm.html)
- [Emscripten](https://emscripten.org/)
- [README racine du monorepo](../README.md)
- [Documentation architecture](../docs/ARCHITECTURE.md)
- [Documentation build détaillée](../docs/BUILD.md)

