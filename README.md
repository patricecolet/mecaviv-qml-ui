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
- **CMake 3.16+**
- **Google Chrome** (pour le développement)

### Installation Qt WebAssembly

```bash
# Vérifier l'installation Qt
ls /Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake

# Si Qt n'est pas installé, télécharger depuis qt.io
# et installer le module "Qt for WebAssembly"
```

### Build de tous les projets

```bash
# Cloner le dépôt
cd /Users/patricecolet/repo/mecaviv-qml-ui

# Build tous les projets (5-10 minutes)
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

## 📜 Scripts Disponibles

### `./scripts/build-all.sh`
Build tous les projets en WebAssembly + installation Node.js.

### `./scripts/build-project.sh <project>`
Build un projet spécifique :
- `sirenepupitre`, `sirenconsole`, `pedalier`, `router`

### `./scripts/dev.sh <project>`
Mode développement : build + serveur + ouverture navigateur.

### `./scripts/clean-all.sh`
Nettoyage complet : supprime build/, node_modules/, *.wasm, logs.

**Documentation complète** : [scripts/README.md](./scripts/README.md)

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
QT_CMAKE="/Users/patricecolet/Qt/6.10.0/wasm_singlethread/bin/qt-cmake"
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

---

**Mécanique Vivante** - Système de Contrôle de Sirènes Musicales 🎵

