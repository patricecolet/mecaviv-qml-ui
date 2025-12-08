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

## 🔄 Synchronisation & Presets

- Le serveur (`webfiles/server.js`) conserve un `currentPresetId`. Au démarrage il se cale automatiquement sur le premier preset disponible et se régénère si `presets.json` est corrompu (fichier de secours `.corrupted-<timestamp>` + preset par défaut).
- Les modifications envoyées depuis l'UI sont persistées via `PATCH /api/presets/current/*`. Elles ne sont relayées vers les pupitres que si le pupitre est marqué comme **synchro** (`GET /api/pupitres/:id/sync-status`).
- Pour activer la synchro :
  1. soit déclencher `Upload preset` (`POST /api/presets/current/upload`) après avoir vérifié que le pupitre est connecté ;
  2. soit laisser SirenePupitre renvoyer un `CONFIG_FULL` / `PUPITRE_STATUS` suite à un `REQUEST_CONFIG`.
- Tant que `isSynced` est `false`, les changements restent uniquement dans `presets.json` (aucun `PARAM_UPDATE` WebSocket n’est envoyé).

## 🧪 Tests locaux

- Pour piloter un SirenePupitre local, configurer `host: "localhost"` et `websocketPort: 10002` dans `SirenConsole/config.js` pour le pupitre ciblé, ainsi que `serverUrl: "ws://localhost:10002"` dans `SirenePupitre/config.js`.
- S’assurer qu’aucun autre service n’utilise les ports critiques : `8000` (HTTP SirenePupitre), `8001` (HTTP SirenConsole), `10002` (WebSocket Pupitre), `10001` (port par défaut de Cursor). Utiliser `lsof -i :PORT` en cas de doute.
- Après connexion, envoyer un `Upload preset` pour initialiser la synchro avant de tester les boutons de SirenConsole.

## 🎯 Principe

**Source unique de vérité** : `config.json` contient toutes les données des sirènes physiques. SirenConsole ne fait que les afficher et les contrôler.