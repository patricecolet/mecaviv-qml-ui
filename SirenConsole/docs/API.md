# API SirenConsole

## 📡 Protocole WebSocket

SirenConsole communique avec les pupitres via WebSocket en utilisant des messages JSON.

### Messages sortants (Console → Pupitre)

#### REQUEST_CONFIG
Demande la configuration complète du pupitre.

```json
{
  "type": "REQUEST_CONFIG",
  "data": {}
}
```

#### PARAM_UPDATE
Met à jour un paramètre spécifique du pupitre.

```json
{
  "type": "PARAM_UPDATE",
  "data": {
    "path": ["sirenConfig", "currentSiren"],
    "value": "2"
  }
}
```

**Chemins supportés :**
- `["sirenConfig", "currentSiren"]` - Sirène active
- `["sirenConfig", "sirens", index, "frettedMode", "enabled"]` - Mode fretté
- `["ui", "scale"]` - Échelle de l'interface
- `["controllersPanel", "visible"]` - Visibilité du panneau
- `["admin", "enabled"]` - Mode admin

> **Note** : La console gère automatiquement l'assignation exclusive des sirènes. Quand une sirène est assignée à un pupitre, elle est automatiquement retirée des autres pupitres pour éviter les conflits.

### Messages entrants (Pupitre → Console)

#### CONFIG_FULL
Configuration complète du pupitre.

```json
{
  "type": "CONFIG_FULL",
  "data": {
    "sirenConfig": {
      "currentSiren": "1",
      "sirens": [
        {
          "id": "1",
          "name": "S1",
          "frettedMode": {
            "enabled": false
          }
        }
      ]
    },
    "ui": {
      "scale": 0.5
    }
  }
}
```

#### PARAM_UPDATE
Confirmation de mise à jour d'un paramètre.

```json
{
  "type": "PARAM_UPDATE",
  "data": {
    "path": ["sirenConfig", "currentSiren"],
    "value": "2",
    "success": true
  }
}
```

#### STATUS_UPDATE
Mise à jour du statut du pupitre.

```json
{
  "type": "STATUS_UPDATE",
  "data": {
    "currentNote": 60,
    "sirenId": "1",
    "frettedMode": false,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## 🎛️ Contrôles disponibles

### Changement de sirène
```javascript
consoleController.changeSiren("1", "2") // Pupitre 1 → Sirène 2
```

### Basculement mode fretté
```javascript
consoleController.toggleFrettedMode("1") // Pupitre 1
```

### Commande personnalisée
```javascript
consoleController.sendCommand("1", "PARAM_UPDATE", {
  path: ["ui", "scale"],
  value: 0.8
})
```

### Commande globale
```javascript
consoleController.sendCommandToAll("PARAM_UPDATE", {
  path: ["admin", "enabled"],
  value: true
})
```

## 💾 API REST - Gestion des Presets

### Base URL
```
http://localhost:8001/api/presets
```

### GET /api/presets
Récupérer tous les presets disponibles.

**Réponse :**
```json
{
  "presets": [
    {
      "id": "preset_001",
      "name": "Configuration Théâtre",
      "description": "Setup pour spectacle théâtral",
      "created": "2024-01-15T10:30:00Z",
      "modified": "2024-01-15T14:45:00Z",
      "version": "1.0",
      "pupitres": [
        {
          "id": "P1",
          "assignedSirenes": [1, 2, 3],
          "vstEnabled": true,
          "udpEnabled": true,
          "rtpMidiEnabled": true,
          "controllerMapping": {
            "joystickX": { "cc": 1, "curve": "linear" },
            "joystickY": { "cc": 2, "curve": "parabolic" },
            "fader": { "cc": 3, "curve": "hyperbolic" },
            "selector": { "cc": 4, "curve": "s curve" },
            "pedalId": { "cc": 5, "curve": "linear" }
          }
        }
      ]
    }
  ]
}
```

### GET /api/presets/:id
Récupérer un preset spécifique.

**Paramètres :**
- `id` : Identifiant du preset

**Réponse :**
```json
{
  "id": "preset_001",
  "name": "Configuration Théâtre",
  "description": "Setup pour spectacle théâtral",
  "created": "2024-01-15T10:30:00Z",
  "modified": "2024-01-15T14:45:00Z",
  "version": "1.0",
  "pupitres": [...]
}
```

### POST /api/presets
Créer un nouveau preset.

**Corps de la requête :**
```json
{
  "name": "Nouveau Preset",
  "description": "Description du preset",
  "pupitres": [...]
}
```

**Réponse :**
```json
{
  "id": "preset_002",
  "name": "Nouveau Preset",
  "description": "Description du preset",
  "created": "2024-01-15T15:00:00Z",
  "modified": "2024-01-15T15:00:00Z",
  "version": "1.0",
  "pupitres": [...]
}
```

### PUT /api/presets/:id
Mettre à jour un preset existant.

**Paramètres :**
- `id` : Identifiant du preset

**Corps de la requête :**
```json
{
  "name": "Preset Modifié",
  "description": "Description modifiée",
  "pupitres": [...]
}
```

### DELETE /api/presets/:id
Supprimer un preset.

**Paramètres :**
- `id` : Identifiant du preset

**Réponse :**
- Status 204 (No Content) en cas de succès

### Codes d'erreur API
- `400` - Requête invalide (nom manquant, etc.)
- `404` - Preset non trouvé
- `500` - Erreur serveur

## 📊 Modèles de données

### Pupitre
```javascript
{
  id: "1",
  name: "Pupitre 1",
  host: "192.168.1.101",
  port: 10001,
  status: "connected", // connected, connecting, disconnected, error
  currentSiren: "1",
  currentNote: 60,
  frettedMode: false,
  lastSeen: "10:30:00"
}
```

### Preset
```javascript
{
  id: "preset_001",
  name: "Configuration Théâtre",
  description: "Setup pour spectacle théâtral",
  created: "2024-01-15T10:30:00Z",
  modified: "2024-01-15T14:45:00Z",
  version: "1.0",
  pupitres: [
    {
      id: "P1",
      assignedSirenes: [1, 2, 3],
      vstEnabled: true,
      udpEnabled: true,
      rtpMidiEnabled: true,
      controllerMapping: {
        joystickX: { cc: 1, curve: "linear" },
        joystickY: { cc: 2, curve: "parabolic" },
        fader: { cc: 3, curve: "hyperbolic" },
        selector: { cc: 4, curve: "s curve" },
        pedalId: { cc: 5, curve: "linear" }
      }
    }
  ]
}
```

### Configuration
```javascript
{
  console: {
    name: "Console de Contrôle des Pupitres",
    version: "1.0.0",
    autoConnect: true,
    reconnectInterval: 5000
  },
  pupitres: [
    // Array de pupitres
  ],
  ui: {
    theme: "dark",
    layout: "grid",
    colors: {
      primary: "#2E86AB",
      success: "#F18F01",
      error: "#C73E1D"
    }
  }
}
```

## 🔧 Configuration réseau

### Adresses par défaut
- Pupitre 1: `192.168.1.101:10001`
- Pupitre 2: `192.168.1.102:10001`
- Pupitre 3: `192.168.1.103:10001`
- Pupitre 4: `192.168.1.104:10001`
- Pupitre 5: `192.168.1.105:10001`
- Pupitre 6: `192.168.1.106:10001`
- Pupitre 7: `192.168.1.107:10001`

### API REST
- Console: `http://localhost:8001`
- API Presets: `http://localhost:8001/api/presets`

### Test de connectivité
```bash
./scripts/test-connections.sh 192.168.1
```

## 🚨 Gestion des erreurs

### Codes d'erreur
- `CONNECTION_FAILED` - Échec de connexion WebSocket
- `INVALID_MESSAGE` - Message JSON invalide
- `PARAMETER_ERROR` - Paramètre non supporté
- `TIMEOUT` - Délai d'attente dépassé

### Reconnexion automatique
- Intervalle par défaut: 5 secondes
- Nombre maximum de tentatives: 10
- Backoff exponentiel: 2x

## 📝 Logs

### Niveaux de log
- `debug` - Informations de débogage
- `info` - Informations générales
- `warning` - Avertissements
- `error` - Erreurs

### Format des logs
```
[10:30:00] [INFO] ConsoleController: Connexion établie avec pupitre 1
[10:30:01] [ERROR] WebSocketManager: Échec de connexion pupitre 2
[10:30:02] [INFO] PresetManager: Preset sauvegardé via API: Configuration Théâtre
```

## 🔐 Sécurité

### Authentification
Actuellement non implémentée. À ajouter pour la production.

### Chiffrement
WebSocket non chiffré (ws://). Utiliser wss:// pour la production.

### Validation
- Validation des adresses IP
- Validation des ports
- Sanitisation des messages JSON
- Validation des données de preset