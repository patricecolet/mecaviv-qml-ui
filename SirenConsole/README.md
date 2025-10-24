# SirenConsole - Console de Contrôle

## 🎯 Vue d'ensemble

**SirenConsole** est une interface de contrôle centralisée pour gérer jusqu'à 7 pupitres **SirenePupitre** via WebSocket.

## 🏗️ Architecture

```
SirenConsole (Interface) → SirenePupitre (Pupitres) → PureData → Sirènes Physiques
```

- **SirenConsole** : Interface de contrôle (ce projet)
- **SirenePupitre** : Application sur chaque pupitre physique
- **Sirènes** : Instruments de musique réels (définis dans `config.json`)

## 🔧 Configuration

### Structure Minimale
```javascript
// SirenConsole/config.js - UNIQUEMENT les données réseau
const config = {
    pupitres: [
        {
            id: "P1",
            name: "Pupitre 1",
            host: "192.168.1.41",    // IP du pupitre
            port: 8000,              // Port HTTP
            websocketPort: 10001,    // Port WebSocket
            enabled: true,
            status: "disconnected"
        }
        // ... P2 à P7 (192.168.1.42 à 192.168.1.47)
    ]
}
```

### ❌ Ce qui NE DOIT PAS être dans SirenConsole
- Données des sirènes physiques (ambitus, clef, transposition)
- Configuration musicale
- Caractéristiques des instruments

### ✅ Ce qui DOIT être dans SirenConsole
- Adresses réseau des pupitres
- Configuration de l'interface
- Presets de l'interface

## 🚀 Utilisation

```bash
# Démarrer SirenConsole
./scripts/run.sh
```

## 📡 Communication

SirenConsole communique avec les pupitres via WebSocket sur les ports `10001`.

Les données des sirènes physiques sont chargées depuis `config.json` via l'API du serveur.

## 🎯 Principe

**Source unique de vérité** : `config.json` contient toutes les données des sirènes physiques. SirenConsole ne fait que les afficher et les contrôler.