# Mecaviv QML UI - Monorepo

Système complet de contrôle et visualisation pour sirènes musicales mécaniques, développé en Qt6/QML et Node.js.

## 🎯 Vue d'ensemble

Ce monorepo regroupe 4 applications interconnectées pour le contrôle, la visualisation et le monitoring de 7 sirènes musicales mécaniques. L'ensemble forme un système hiérarchique où chaque composant a un rôle spécifique dans la chaîne de contrôle et de monitoring.

## 🏗️ Architecture Globale

```
┌─────────────────────────────────────────────────────────────────┐
│                        SirenConsole                             │
│              Console de Contrôle (Priorité Max)                 │
│         Gestion de 7 pupitres - Port 8001 - WebSocket          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ WebSocket (contrôle + monitoring)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SirenePupitre (×7)                          │
│         Visualiseurs Musicaux (Interface Locale)                │
│      Portée 3D + Contrôleurs - Port 8000 - WebSocket           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ UDP/WebSocket (données musicales)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                        PureData                                 │
│              Hub de Routage MIDI + Communication                │
│        Reçoit : MIDI (Reaper, Sirénium) + UDP (Pupitres)       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ MIDI (contrôle physique)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Sirènes Physiques (×7)                        │
│              Instruments Mécaniques + VST Virtuels              │
│                   UDP → sirenRouter (monitoring)                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ UDP (monitoring passif)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       sirenRouter                               │
│            Service de Monitoring Centralisé                     │
│      REST API (8002) + WebSocket (8003) + UDP (8004)           │
└─────────────────────────────────────────────────────────────────┘
         │
         │ WebSocket (état temps réel)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    pedalierSirenium                             │
│         Interface Pédalier 3D (8 pédales × 7 sirènes)          │
│     Port 8010 - WebSocket - Gestion Scènes + Presets          │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 Projets Inclus

### 1. [SirenePupitre](./SirenePupitre/) - Visualiseur Musical 🎵

**Interface locale** pour visualiser en temps réel les données musicales d'une sirène.

**Fonctionnalités** :
- Portée musicale 3D avec clé de sol/fa
- Afficheurs LED 3D (Hz, RPM, note)
- Indicateurs de contrôleurs (volant, joystick, faders)
- Panneau admin (configuration, visibilité, couleurs)
- Mode console (contrôle à distance par SirenConsole)

**Technologies** : Qt 6, QML, Qt Quick 3D, WebAssembly  
**Port** : 8000  
**README** : [SirenePupitre/README.md](./SirenePupitre/README.md)

### 2. [SirenConsole](./SirenConsole/) - Console de Contrôle 🎛️

**Console centrale** pour gérer jusqu'à 7 instances de SirenePupitre.

**Fonctionnalités** :
- Vue d'ensemble de 7 pupitres
- Configuration centralisée (sirènes, contrôleurs, courbes)
- Assignation exclusive des sirènes (1 sirène = 1 pupitre)
- Mode "All" (configuration simultanée de tous les pupitres)
- Gestion de presets avec API REST
- Monitoring en temps réel

**Technologies** : Qt 6, QML, WebAssembly, Node.js  
**Port** : 8001  
**README** : [SirenConsole/README.md](./SirenConsole/README.md)

### 3. [pedalierSirenium](./pedalierSirenium/) - Interface Pédalier 3D 🎮

**Interface de contrôle 3D** pour 8 pédales contrôlant 7 sirènes.

**Fonctionnalités** :
- Vue 3D de 7 sirènes avec animations
- Matrice de configuration : 8 pédales × 7 sirènes × 8 contrôleurs = 448 paramètres
- Gestion de presets (sauvegarde/chargement)
- Gestion de scènes (64 scènes sur 8 pages)
- Contrôle de boucles (recording, playing, stopped, cleared)
- Monitoring MIDI temps réel avec portées musicales
- Debug panel avec 11 catégories de logs

**Technologies** : Qt 6, QML, Qt Quick 3D, WebAssembly, PureData  
**Port** : 8010  
**README** : [pedalierSirenium/README.md](./pedalierSirenium/README.md)

### 4. [sirenRouter](./sirenRouter/) - Service de Monitoring 📊

**Service de monitoring centralisé** pour observer l'état des sirènes.

**Fonctionnalités** :
- Monitoring passif des sirènes via UDP
- API REST pour consultation de l'état
- WebSocket pour notifications temps réel
- Dashboard web de monitoring
- Historique et logs des activités

**Technologies** : Node.js, Express, WebSocket  
**Ports** : 8002 (API REST), 8003 (WebSocket), 8004 (UDP)  
**README** : [sirenRouter/README.md](./sirenRouter/README.md)

## 🚀 Installation Rapide

### Prérequis

- **Qt 6.10+** avec support WebAssembly
- **Node.js 18+** et npm
- **CMake 3.19+** (système de build multiplateforme)
- **Ninja** (générateur de build recommandé)
- **Google Chrome** (pour le développement web)

### Installation des Outils

```bash
# macOS
brew install cmake ninja node

# Linux
sudo apt-get install cmake ninja-build nodejs npm

# Windows
# Installer CMake: https://cmake.org/download/
# Installer Node.js: https://nodejs.org/
```

### Installation Qt WebAssembly

Télécharger Qt depuis [qt.io/download](https://www.qt.io/download) et installer les modules :
- Qt 6.10.0 (ou plus récent)
- Qt for WebAssembly (wasm_singlethread)

### Configuration des Chemins Qt

**⚠️ Important** : Le projet utilise des variables d'environnement pour les chemins Qt.

#### Configuration Rapide

```bash
# macOS / Linux
./scripts/setup-env.sh

# Windows (PowerShell)
.\scripts\setup-env.ps1
```

Le script détecte automatiquement votre système et configure les chemins Qt.

#### Configuration Manuelle

```bash
# macOS / Linux - Ajouter à ~/.zshrc ou ~/.bashrc
export QT_DIR="$HOME/Qt/6.10.0/macos"  # ou gcc_64 pour Linux
export QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"

# Windows - PowerShell ou Variables Système
$env:QT_DIR = "C:\Qt\6.10.0\msvc2019_64"
$env:QT_WASM_DIR = "C:\Qt\6.10.0\wasm_singlethread"
```

**📖 Guide détaillé** : Voir [CONFIG.md](./CONFIG.md) pour la configuration complète.

### Build de tous les projets

#### Méthode 1 : CMake (Recommandé - Multiplateforme)

```bash
# Cloner le dépôt
git clone https://github.com/patricecolet/mecaviv-qml-ui.git
cd mecaviv-qml-ui

# Configurer les variables Qt (voir CONFIG.md)
export QT_DIR="$HOME/Qt/6.10.0/macos"
export QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"

# Configuration
cmake --preset=default        # Desktop natif
# ou
cmake --preset=wasm          # WebAssembly

# Build (5-10 minutes)
cmake --build build --parallel
```

#### Méthode 2 : Scripts Bash (macOS/Linux uniquement)

```bash
# Build tous les projets
./scripts/build-all.sh
```

### Lancer un projet en mode développement

```bash
# SirenePupitre
./scripts/dev.sh sirenepupitre

# SirenConsole
./scripts/dev.sh sirenconsole

# pedalierSirenium
./scripts/dev.sh pedalier

# sirenRouter
./scripts/dev.sh router
```

## 📜 Build System

### CMake (Recommandé - Multiplateforme)

```bash
# Configuration
cmake --preset=default        # Desktop Debug
cmake --preset=release        # Desktop Release
cmake --preset=wasm          # WebAssembly

# Build
cmake --build build          # Build tout
cmake --build build --target appSirenePupitre  # Build un projet
cmake --build build --parallel  # Build parallèle

# Helper scripts
./scripts/configure.sh default   # macOS/Linux
.\scripts\configure.ps1 default    # Windows (PowerShell)
```

### Scripts Bash (Legacy - Unix uniquement)

```bash
./scripts/build-all.sh         # Build tous les projets
./scripts/build-project.sh <project>  # Build un projet spécifique
./scripts/dev.sh <project>     # Mode développement
./scripts/clean-all.sh         # Nettoyage complet
```

**Documentation complète** : 
- [docs/BUILD.md](./docs/BUILD.md) - Guide de build détaillé
- [scripts/README.md](./scripts/README.md) - Documentation des scripts

## 📡 Communication entre Applications

### Protocoles Utilisés

- **WebSocket** : Communication temps réel entre Console ↔ Pupitres ↔ PureData
- **UDP** : Données musicales (Pupitres → PureData, Sirènes → Router)
- **MIDI** : Contrôle physique des sirènes (PureData → Sirènes)
- **REST API** : Consultation de l'état (sirenRouter)

### Ports Utilisés

| Application | Protocol | Port(s) | Description |
|-------------|----------|---------|-------------|
| SirenePupitre | HTTP + WebSocket | 8000 | Interface web + communication |
| SirenConsole | HTTP + WebSocket | 8001 | Interface web + contrôle pupitres |
| sirenRouter | REST + WebSocket + UDP | 8002-8004 | API, notifications, monitoring |
| pedalierSirenium | HTTP + WebSocket | 8010 | Interface web + communication |
| PureData | WebSocket | 10000-10001 | Hub central de routage |

### Messages WebSocket

Voir la documentation détaillée : [docs/COMMUNICATION.md](./docs/COMMUNICATION.md)

## 📚 Documentation

- **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** : Architecture détaillée du système
- **[BUILD.md](./docs/BUILD.md)** : Guide de build complet et troubleshooting
- **[COMMUNICATION.md](./docs/COMMUNICATION.md)** : Protocoles de communication
- **[COMPOSESIREN_ARCHITECTURE.md](./docs/COMPOSESIREN_ARCHITECTURE.md)** : Architecture ComposeSiren et flux MIDI
- **[TODO.md](./TODO.md)** : Roadmap et tâches à venir

### Documentation par Projet

- [SirenePupitre/README.md](./SirenePupitre/README.md)
- [SirenConsole/README.md](./SirenConsole/README.md)
- [pedalierSirenium/README.md](./pedalierSirenium/README.md)
- [sirenRouter/README.md](./sirenRouter/README.md)

## 🎯 Use Cases Typiques

### Concert/Performance

1. **Démarrer sirenRouter** pour le monitoring
2. **Démarrer PureData** comme hub central
3. **Démarrer 7 instances de SirenePupitre** (une par sirène)
4. **Démarrer SirenConsole** pour le contrôle global
5. **Utiliser pedalierSirenium** pour les effets live

### Développement/Debug

1. **Démarrer un seul pupitre** : `./scripts/dev.sh sirenepupitre`
2. **Tester les communications** avec le debug panel
3. **Modifier le code QML** et recharger
4. **Consulter les logs** : `tail -f /tmp/sirenepupitre_server.log`

### Configuration des Sirènes

1. **Ouvrir SirenConsole**
2. **Onglet Configuration** → Sélectionner un pupitre
3. **Assigner les sirènes** (assignation exclusive)
4. **Configurer l'ambitus, la transposition, les contrôleurs**
5. **Sauvegarder en preset** pour réutiliser

## 🔧 Dépannage

### Port déjà utilisé

```bash
# Utiliser le script de nettoyage
./scripts/clean-all.sh

# Ou tuer manuellement
lsof -ti:8000 | xargs kill -9
```

### Build échoue

```bash
# Nettoyer et rebuilder
./scripts/clean-all.sh
./scripts/build-project.sh <project>
```

### Qt WebAssembly introuvable

Vérifier le chemin dans `scripts/build-project.sh` :
```bash
QT_CMAKE="$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake"
```

### Plus de dépannage

Voir [docs/BUILD.md](./docs/BUILD.md) pour le guide complet.

## 🗂️ Structure du Monorepo

```
mecaviv-qml-ui/
├── README.md                    # Ce fichier
├── TODO.md                      # Roadmap globale
├── .gitignore                   # Fichiers à ignorer
├── docs/                        # Documentation globale
│   ├── ARCHITECTURE.md
│   ├── BUILD.md
│   └── COMMUNICATION.md
├── scripts/                     # Scripts centralisés
│   ├── build-all.sh
│   ├── build-project.sh
│   ├── dev.sh
│   ├── clean-all.sh
│   └── README.md
├── SirenePupitre/              # Visualiseur musical
│   ├── README.md
│   ├── QML/
│   └── webfiles/
├── SirenConsole/               # Console de contrôle
│   ├── README.md
│   ├── QML/
│   └── webfiles/
├── pedalierSirenium/          # Interface pédalier 3D
│   ├── README.md
│   ├── QtFiles/
│   └── webfiles/
└── sirenRouter/                # Service monitoring
    ├── README.md
    └── src/
```

## 🤝 Contribution

Ce projet est développé par **Mécanique Vivante** pour le contrôle de sirènes musicales mécaniques.

### Workflow Git

```bash
# Travailler sur une branche
git checkout -b feature/ma-fonctionnalite

# Commiter les changements
git add .
git commit -m "Description de la fonctionnalité"

# Pousser vers le remote
git push origin feature/ma-fonctionnalite
```

## 📄 Licence

Ce projet est développé dans le cadre du projet Mécanique Vivante.

## 🆘 Support

Pour toute question :
1. Consulter la [documentation](./docs/)
2. Vérifier les [README des projets](#-projets-inclus)
3. Consulter le [TODO.md](./TODO.md) pour les fonctionnalités en cours

## 🔄 Restructuration - Dossier partagé `shared/`

### ✅ Migration terminée (Octobre 2025)

Pour éviter la duplication de code entre projets, un dossier `shared/` a été créé à la racine du monorepo.

**Résultat** : 
- **9 composants QML** : 6 utilitaires + 3 clefs
- **4 polices** : 2 musicales + 2 emoji
- **2 scripts de conversion** : convert-mesh.sh (générique), convert-clefs.sh

Tous partagés entre SirenePupitre, SirenConsole et (futur) pedalierSirenium, éliminant tous les doublons et facilitant la maintenance.

**Anciens emplacements** : 
- `fonts/` (racine) - **SUPPRIMÉ**
- `SirenePupitre/QML/utils/Clef*.qml` - **DÉPLACÉ**
- `SirenePupitre/scripts/convert-*.sh` - **DÉPLACÉ**

**Nouveau emplacement unique** : `shared/` - Source unique de vérité

#### Structure finale

```
mecaviv-qml-ui/
├── shared/
│   ├── qml/
│   │   ├── clefs/               # Composants clefs musicales (3 fichiers)
│   │   │   ├── Clef2D.qml       # Clef 2D avec polices
│   │   │   ├── Clef2DPath.qml   # Clef avec tracé vectoriel
│   │   │   └── Clef3D.qml       # Clef 3D avec modèles .mesh
│   │   ├── common/              # Composants QML partagés (6 fichiers)
│   │   │   ├── DigitLED3D.qml
│   │   │   ├── LEDText3D.qml
│   │   │   ├── LEDSegment.qml
│   │   │   ├── Knob.qml
│   │   │   ├── Knob3D.qml
│   │   │   └── MusicUtils.qml
│   │   └── fonts/               # Polices partagées (4 fichiers)
│   │       ├── EmojiFont.qml
│   │       ├── NotoEmoji-VariableFont_wght.ttf
│   │       ├── MusiSync.ttf
│   │       └── NotoMusic-Regular.ttf
│   └── scripts/                 # Scripts de conversion (2 fichiers)
│       ├── convert-mesh.sh      # Convertit .obj → .mesh (générique)
│       └── convert-clefs.sh     # Convertit clefs musicales
├── SirenePupitre/
│   └── QML/
│       └── utils/               # Composants spécifiques au pupitre
│           ├── meshes/          # Modèles 3D (reste local)
│           ├── Clef3D.qml
│           ├── Clef2D.qml
│           ├── Ring3D.qml
│           └── ColorPicker.qml
└── pedalierSirenium/
    └── QtFiles/qml/
        └── utils/               # Composants spécifiques pédalier
            └── VirtualKeyboard.qml
```

#### Composants à déplacer vers `shared/qml/common/`

**✅ Migration terminée** - Composants partagés entre SirenePupitre et pedalierSirenium :
- [X] `DigitLED3D.qml` - Afficheur 7 segments 3D
- [X] `LEDText3D.qml` - Texte LED 3D
- [X] `LEDSegment.qml` - Segment LED individuel
- [X] `Knob.qml` - Bouton rotatif 2D
- [X] `Knob3D.qml` - Bouton rotatif 3D
- [X] `MusicUtils.qml` - Utilitaires de calculs musicaux

#### Ressources à déplacer vers `shared/qml/fonts/`

**✅ Migration terminée** - Toutes les polices partagées :
- [X] `MusiSync.ttf` - Symboles musicaux de base
- [X] `NotoMusic-Regular.ttf` - Police Noto Music (SMuFL)
- [X] `EmojiFont.qml` - Wrapper QML pour la police emoji
- [X] `NotoEmoji-VariableFont_wght.ttf` - Police emoji Noto

#### Composants à garder locaux

**Spécifiques à chaque projet** :
- `meshes/` - Modèles 3D .mesh (94-200K par fichier, générés depuis .obj)
  - TrebleKey.mesh, BassKey.mesh (restent dans SirenePupitre/QML/utils/meshes/)
- `Ring3D.qml`, `ColorPicker.qml` - Utilitaires UI (SirenePupitre)
- `VirtualKeyboard.qml` - Clavier virtuel (pedalierSirenium)
- `TrebleClef3D.qml` - Version vectorielle simple (pedalierSirenium, à migrer)

#### ✅ Modifications terminées

**Scripts adaptés** :
- [X] `SirenePupitre/scripts/build.sh` - Copie fonts depuis `../shared/qml/fonts/`
- [X] `pedalierSirenium/scripts/build_run_web.sh` - Copie fonts depuis shared/
- [ ] `scripts/convert-clefs.sh` - Chemins meshes/ (reste local, si nécessaire)

**Fichiers de ressources** :
- [X] `SirenePupitre/data.qrc` - Références vers `../shared/qml/`
- [X] `pedalierSirenium/QtFiles/data.qrc` - Références vers `../../shared/qml/`
- [X] `CMakeLists.txt` (racine) - Variable SHARED_QML_DIR configurée

**Imports QML** (23 fichiers modifiés) :
- [X] SirenePupitre : 16 fichiers mis à jour vers `import "../../../shared/qml/common"`
- [X] pedalierSirenium : 7 fichiers mis à jour avec imports vers shared/
- [X] Chemins de polices : `qrc:/QML/fonts/` → `qrc:/shared/qml/fonts/`

**Validation** :
- [X] Build réussi pour SirenePupitre ✅
- [X] Build réussi pour SirenConsole ✅
- [X] Consolidation des polices emoji vers shared/ ✅
- [X] Suppression du dossier fonts/ racine (doublon éliminé) ✅
- [X] Migration des clefs vers shared/qml/clefs/ ✅
- [X] Migration des scripts de conversion vers shared/scripts/ ✅
- [ ] Build pedalierSirenium (refonte prévue, utilisera shared/)

### Bibliothèque MIDI externe (À faire)

#### Déplacer `midifiles/` vers un repository séparé

**Raison** : La bibliothèque MIDI (40+ fichiers, compositions musicales) mérite son propre repository pour :
- Gestion de versions indépendante
- Partage avec d'autres projets
- Historique Git dédié aux compositions

**Structure prévue** :
```
mecaviv-midi-library/           # Nouveau repository
├── README.md
├── louette/                    # Compositions de Louette (40+ fichiers)
├── patwave/                    # Compositions de Patwave (4 fichiers)
├── covers/                     # Adaptations et reprises
└── presets/                    # Configurations de presets
```

---

**Mécanique Vivante** - Système de Contrôle de Sirènes Musicales 🎵

