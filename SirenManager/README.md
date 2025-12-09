# SirenManager

Application QML/WebAssembly pour le contrôle des sirènes Mecaviv, migration complète de SireneControlMac.

## Vue d'ensemble

SirenManager est une application complète pour contrôler les sirènes Mecaviv via une interface moderne en QML. Elle reproduit toutes les fonctionnalités de SireneControlMac avec 10 vues principales :

1. **PLAYER** - Séquenceur MIDI avec contrôle de lecture
2. **MIXAGE** - Mixer avec contrôleurs de volume
3. **SIRENIUM** - Contrôle du sirenium (pédalier)
4. **MAINTENANCE** - Contrôle des moteurs et clapets
5. **CONTROLEURS** - Contrôleurs MIDI
6. **PIANO** - Piano virtuel
7. **VOITURES** - Contrôle des voitures A/B
8. **PAVILLONS** - Contrôle des pavillons 1/2
9. **SYSTÈME** - Maintenance système avec SSH proxy
10. **PLAYLISTS** - Compositeur de playlists

## Architecture

- **Frontend QML** : Interface utilisateur moderne avec 10 vues
- **Backend C++** : Modules pour communication UDP, gestion playlists, configuration
- **Service Node.js** : Proxy SSH pour les opérations de maintenance système
- **WebAssembly** : Compilation pour navigateur web

## Prérequis

- Qt 6.10+ avec support WebAssembly
- CMake 3.19+
- Node.js 18+ (pour le backend SSH)
- Qt for WebAssembly (wasm_singlethread)

## Build

### WebAssembly

```bash
# Configurer les variables d'environnement Qt
export QT_DIR="$HOME/Qt/6.10.0/macos"
export QT_WASM_DIR="$HOME/Qt/6.10.0/wasm_singlethread"

# Build WebAssembly
cd SirenManager
mkdir -p build
cd build
$QT_WASM_DIR/bin/qt-cmake ..
make -j$(sysctl -n hw.ncpu)
```

### Desktop natif

```bash
cd SirenManager
mkdir -p build
cd build
cmake ..
make -j$(sysctl -n hw.ncpu)
```

## Structure du projet

```
SirenManager/
├── src/              # Code C++ backend
├── QML/              # Interfaces QML
├── backend/          # Service Node.js pour proxy SSH
├── resources/        # Ressources (icônes, images)
└── webfiles/         # Fichiers générés pour WebAssembly
```

## Backend SSH

Le service backend Node.js permet d'exécuter des commandes SSH depuis le navigateur (via WebAssembly) :

```bash
cd backend
npm install
node server.js
```

Le serveur écoute sur le port 8005 par défaut.

## Communication

- **UDP** : Communication avec les sirènes via proxy WebSocket
- **SSH** : Opérations de maintenance via backend Node.js
- **WebSocket** : Communication temps réel

## License

Copyright © Mecaviv. All rights reserved.


