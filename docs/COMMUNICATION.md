# Protocoles de Communication - Mecaviv QML UI

Documentation complète des protocoles de communication entre les applications du système.

## 📡 Vue d'Ensemble des Protocoles

Le système utilise **3 protocoles principaux** pour la communication entre applications :

| Protocol | Usage | Applications | Format |
|----------|-------|--------------|--------|
| **WebSocket** | Communication temps réel bidirectionnelle | Console ↔ Pupitres ↔ PureData ↔ pedalierSirenium | JSON + Binaire MIDI |
| **UDP** | Monitoring passif et données musicales | Sirènes → Router, Pupitres → PureData | JSON |
| **REST API** | Consultation de l'état | Applications → sirenRouter | JSON (HTTP) |

## 🔌 WebSocket - Communication Temps Réel

### Ports et Connexions

| Source | Destination | Port | Format |
|--------|-------------|------|--------|
| SirenConsole | SirenePupitre | 8000 + WS | JSON |
| SirenePupitre | PureData | 10001 | JSON + Binaire |
| pedalierSirenium | PureData | 10000 | JSON + Binaire |
| sirenRouter | SirenConsole | 8003 | JSON |

### Format des Messages JSON

Tous les messages WebSocket JSON suivent cette structure de base :

```json
{
  "type": "MESSAGE_TYPE",
  "data": { ... },
  "source": "application_source",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Champs obligatoires** :
- `type` : Type de message (voir sections suivantes)
- `data` : Contenu du message

**Champs optionnels** :
- `source` : Application source (console, pupitre, puredata, etc.)
- `timestamp` : Horodatage ISO8601

## 1️⃣ SirenConsole ↔ SirenePupitre

### Messages Console → Pupitre

#### CONSOLE_CONNECT - Prise de Contrôle

La console prend le contrôle d'un pupitre.

```json
{
  "type": "CONSOLE_CONNECT",
  "source": "console"
}
```

**Effet sur le pupitre** :
- Désactivation du panneau admin local
- Affichage du bandeau "Console connectée"
- Blocage des modifications locales
- Toutes les modifications viennent de la console

#### CONSOLE_DISCONNECT - Libération du Contrôle

La console libère le contrôle.

```json
{
  "type": "CONSOLE_DISCONNECT",
  "source": "console"
}
```

**Effet sur le pupitre** :
- Réactivation du panneau admin
- Masquage du bandeau
- Autorisation des modifications locales
- Retour au mode autonome

#### PARAM_UPDATE - Modification de Paramètre

Modification d'un paramètre de configuration.

```json
{
  "type": "PARAM_UPDATE",
  "path": ["displayConfig", "components", "rpm", "visible"],
  "value": true,
  "source": "console"
}
```

**Champs** :
- `path` : Chemin hiérarchique dans la configuration (tableau)
- `value` : Nouvelle valeur (any type)
- `source` : "console" pour éviter la réémission vers PureData

**Exemples de chemins** :
```json
// Visibilité d'un composant
["displayConfig", "components", "rpm", "visible"]

// Ambitus d'une sirène
["sirenConfig", "sirens", 0, "ambitus", "min"]

// Mode de la sirène
["sirenConfig", "mode"]

// Échelle UI
["ui", "scale"]
```

**Conversions automatiques** :
- `0` → `false` pour les champs "visible"
- `1` → `true` pour les champs "visible"

### Messages Pupitre → Console

#### PUPITRE_STATUS - Statut du Pupitre

Le pupitre envoie son statut à la console.

```json
{
  "type": "PUPITRE_STATUS",
  "pupitreId": "P1",
  "status": "connected",
  "data": {
    "id": "P1",
    "name": "Pupitre 1",
    "ip": "192.168.1.41",
    "port": 10001,
    "status": "connected",
    "assignedSirenes": [1, 2, 3],
    "currentSiren": 1,
    "midiNote": 60,
    "frequency": 261.63,
    "rpm": 1308,
    "vstEnabled": true,
    "udpEnabled": true,
    "rtpMidiEnabled": true,
    "controllerMapping": {
      "joystickX": { "cc": 1, "curve": "linear" },
      "joystickY": { "cc": 2, "curve": "parabolic" },
      "fader": { "cc": 3, "curve": "hyperbolic" }
    }
  }
}
```

**Fréquence d'envoi** : 
- À la connexion (initial)
- Toutes les 5 secondes (heartbeat)
- Lors de changements significatifs

## 2️⃣ SirenePupitre ↔ PureData

### Messages PureData → Pupitre

#### CONFIG_FULL - Configuration Complète

PureData envoie la configuration complète au pupitre.

```json
{
  "type": "CONFIG_FULL",
  "config": {
    "serverUrl": "ws://localhost:10001",
    "admin": {
      "enabled": true
    },
    "ui": {
      "scale": 0.5
    },
    "controllersPanel": {
      "visible": false
    },
    "sirenConfig": {
      "mode": "restricted",
      "currentSiren": "1",
      "sirens": [
        {
          "id": "1",
          "name": "S1",
          "outputs": 12,
          "ambitus": { "min": 43, "max": 86 },
          "clef": "bass",
          "restrictedMax": 72,
          "transposition": 1,
          "displayOctaveOffset": 0,
          "frettedMode": { "enabled": false }
        }
      ]
    },
    "displayConfig": {
      "components": {
        "rpm": { 
          "visible": true,
          "ledSettings": { "color": "#FFFF99", "digitSize": 1.0 }
        },
        "frequency": { "visible": true },
        "musicalStaff": { "visible": true }
      }
    }
  }
}
```

**Moment d'envoi** :
- À la connexion du pupitre
- En réponse à REQUEST_CONFIG
- Après un changement majeur de configuration

#### PARAM_UPDATE - Mise à Jour Paramètre

PureData met à jour un paramètre individuel.

```json
{
  "type": "PARAM_UPDATE",
  "path": ["sirenConfig", "currentSiren"],
  "value": "2"
}
```

#### Messages MIDI (Binaire)

PureData envoie les données musicales en **binaire** (voir section MIDI).

### Messages Pupitre → PureData

#### REQUEST_CONFIG - Demande de Configuration

Le pupitre demande sa configuration.

```json
{
  "type": "REQUEST_CONFIG"
}
```

**Moment d'envoi** :
- À la connexion WebSocket
- Après une déconnexion/reconnexion
- Sur demande utilisateur (refresh)

#### PARAM_CHANGED - Changement Local

Le pupitre informe PureData d'un changement local.

```json
{
  "type": "PARAM_CHANGED",
  "path": ["displayConfig", "components", "rpm", "visible"],
  "value": false
}
```

**Note** : Ce message n'est **pas** envoyé si `source: "console"` dans le PARAM_UPDATE reçu (évite les boucles).

## 3️⃣ pedalierSirenium ↔ PureData

### Messages pedalierSirenium → PureData

#### Configuration des Pédales

```json
{
  "device": "SIREN_PEDALS",
  "pedalConfigChange": {
    "pedalId": 1,
    "sirenId": 2,
    "controller": "vibratoSpeed",
    "value": -50
  }
}
```

**Contrôleurs disponibles** :
- `volume` : Contrôle du volume (-100% à +100%)
- `vibratoSpeed` : Modulation vitesse vibrato (-100% à +100%)
- `vibratoDepth` : Modulation profondeur vibrato (-100% à +100%)
- `tremoloSpeed` : Modulation vitesse tremolo (-100% à +100%)
- `tremoloDepth` : Modulation profondeur tremolo (-100% à +100%)
- `attack` : Modulation temps d'attaque (-100% à +100%)
- `release` : Modulation temps de relâchement (-100% à +100%)
- `voice` : Modulation accord (-12 à +12 demi-tons)

#### Gestion des Presets

```json
// Sauvegarder
{
  "device": "SIREN_PEDALS",
  "action": "savePreset",
  "presetName": "mon_preset"
}

// Charger
{
  "device": "SIREN_PEDALS",
  "action": "loadPreset",
  "presetName": "mon_preset"
}

// Supprimer
{
  "device": "SIREN_PEDALS",
  "action": "deletePreset",
  "presetName": "mon_preset"
}

// Liste des presets
{
  "device": "SIREN_PEDALS",
  "action": "getPresetList"
}

// Preset actuel
{
  "device": "SIREN_PEDALS",
  "action": "getCurrentPreset"
}
```

#### Gestion des Scènes

```json
// Liste des scènes
{
  "device": "LOOPER_SCENES",
  "action": "getScenesList"
}

// Charger une scène
{
  "device": "LOOPER_SCENES",
  "action": "loadScene",
  "sceneId": 1
}

// Sauvegarder une scène
{
  "device": "LOOPER_SCENES",
  "action": "saveScene",
  "sceneId": 1,
  "sceneName": "ma_scene"
}

// Supprimer une scène
{
  "device": "LOOPER_SCENES",
  "action": "deleteScene",
  "sceneId": 1
}
```

### Messages PureData → pedalierSirenium

#### État des Boucles et Sirènes

```json
{
  "device": "SIREN_LOOPER",
  "loops": {
    "main_loop": 1,
    "states": [
      {
        "siren_id": 1,
        "transport": "playing",
        "current_bar": 3,
        "loopSize": 8,
        "revolutions": 42
      },
      {
        "siren_id": 2,
        "transport": "recording",
        "current_bar": 1,
        "loopSize": 4,
        "revolutions": 0
      }
    ]
  },
  "sirenPings": {
    "siren1": 1,
    "siren2": 0,
    "siren3": 1,
    "siren4": 1,
    "siren5": 0,
    "siren6": 1,
    "siren7": 1
  },
  "clock": {
    "bpm": 120,
    "beat": 1,
    "bar": 3
  }
}
```

**États de transport** :
- `recording` : Enregistrement en cours (🔴 rouge pulsant)
- `playing` : Lecture en cours (🟢 vert animé)
- `stopped` : Pause (🟡 jaune fixe)
- `cleared` : Boucle effacée (⚫ gris inactif)

**sirenPings** :
- `1` ou `true` : Sirène OK (vert #4CAF50)
- `0` ou `false` : Sirène déconnectée (orange #FF5722)

#### Liste des Scènes

```json
{
  "device": "LOOPER_SCENES",
  "batch": "scenesList",
  "scenes": [
    {
      "page": 1,
      "sceneId": 1,
      "globalSceneId": 1,
      "sceneName": "intro",
      "isEmpty": false,
      "isActive": false
    },
    {
      "page": 1,
      "sceneId": 2,
      "globalSceneId": 2,
      "sceneName": "verse",
      "isEmpty": false,
      "isActive": true
    }
  ]
}
```

## 4️⃣ Messages MIDI Binaires (WebSocket)

### Format des Frames MIDI

Les messages MIDI sont transmis en **binaire** pour minimiser la latence.

#### Note On

```
[0x90 | canal, note, vélocité]  // 3 octets
```

**Exemple** : Note On canal 0, note 60 (C4), vélocité 90
```
[0x90, 0x3C, 0x5A]
```

#### Note Off

```
[0x80 | canal, note, 0]  // 3 octets
// Ou
[0x90 | canal, note, 0]  // Note On avec vélocité 0
```

**Exemple** : Note Off canal 0, note 60
```
[0x80, 0x3C, 0x00]
```

#### Control Change

```
[0xB0 | canal, controller, value]  // 3 octets
```

**Exemple** : CC 1 (Modulation) canal 0, valeur 64
```
[0xB0, 0x01, 0x40]
```

#### Pitch Bend

```
[0xE0 | canal, lsb, msb]  // 3 octets
```

**Encodage 14 bits** :
```javascript
// Valeur pitch bend: 0-16383 (centre: 8192)
// Pour sirènes: 13 bits, centre 4096

lsb = bend & 0x7F
msb = (bend >> 7) & 0x7F

// Message
[0xE0 | canal, lsb, msb]
```

**Exemple** : Pitch bend canal 0, centre (8192)
```
lsb = 8192 & 0x7F = 0
msb = (8192 >> 7) & 0x7F = 64
[0xE0, 0x00, 0x40]
```

#### Horloge MIDI Temps Réel

```
[0xF8]  // Clock tick (24 ppq) - 1 octet
[0xFA]  // Start - 1 octet
[0xFB]  // Continue - 1 octet
[0xFC]  // Stop - 1 octet
```

**Exemple** : Clock tick
```
[0xF8]
```

### Spécifications Sirènes (sirenSpec)

Les sirènes ont des paramètres pitch bend spécifiques :

```json
{
  "meta": {
    "bendBits": 13,
    "bendCenter": 4096
  },
  "siren1": {
    "label": "S1",
    "channel": 0,
    "clef": "treble",
    "ambitus": { "min": 48, "max": 84 },
    "transpose": 0,
    "color": "#4CAF50"
  }
}
```

**Calcul du bend** :
```javascript
// Pour sirènes : 13 bits, centre 4096, plage ±4096
// bend = 0..8191 (0 = -100%, 4096 = 0%, 8191 = +100%)

// Conversion en LSB/MSB pour MIDI
lsb = bend & 0x7F
msb = (bend >> 7) & 0x7F
```

## 5️⃣ UDP - Monitoring Passif

### Port UDP

**sirenRouter** écoute sur le port `8004`.

### Format des Trames UDP

#### Sirène → sirenRouter

```json
{
  "sireneId": 1,
  "status": "playing",
  "currentNote": 69.5,
  "volume": 0.8,
  "frequency": 440.0,
  "rpm": 1200,
  "controllers": {
    "wheel": {
      "position": 45,
      "velocity": 10.5
    },
    "joystick": {
      "x": 0.0,
      "y": 0.0,
      "z": 0.0,
      "button": false
    },
    "gearShift": {
      "position": 2,
      "mode": "THIRD"
    },
    "fader": {
      "value": 64,
      "percent": 50.0
    },
    "modPedal": {
      "value": 0,
      "percent": 0.0
    },
    "pad": {
      "velocity": 0,
      "aftertouch": 0,
      "active": false
    }
  },
  "timestamp": "2024-01-01T12:00:00Z",
  "metadata": {
    "controller": "reaper",
    "session": "concert_2024"
  }
}
```

**Fréquence d'envoi** : Toutes les 100ms (10 Hz)

## 6️⃣ REST API - sirenRouter

### Base URL

```
http://localhost:8002/api
```

### Endpoints

#### GET `/api/status/sirenes`

Récupère l'état de toutes les sirènes.

**Réponse** :
```json
{
  "sirenes": {
    "1": {
      "status": "playing",
      "currentNote": 69.5,
      "volume": 0.8,
      "controller": "reaper",
      "timestamp": "2024-01-01T12:00:00Z"
    },
    "2": {
      "status": "stopped",
      "controller": null,
      "timestamp": "2024-01-01T12:00:00Z"
    }
  }
}
```

#### GET `/api/status/sirenes/:id`

Récupère l'état d'une sirène spécifique.

**Exemple** : `/api/status/sirenes/1`

**Réponse** :
```json
{
  "sireneId": 1,
  "status": "playing",
  "currentNote": 69.5,
  "frequency": 440.0,
  "rpm": 1200,
  "controllers": { ... },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## 📊 Tableau Récapitulatif

### Messages par Application

#### SirenConsole

| Direction | Type | Format | Port |
|-----------|------|--------|------|
| → Pupitre | CONSOLE_CONNECT | JSON | 8000 WS |
| → Pupitre | CONSOLE_DISCONNECT | JSON | 8000 WS |
| → Pupitre | PARAM_UPDATE | JSON | 8000 WS |
| ← Pupitre | PUPITRE_STATUS | JSON | 8000 WS |
| ← Router | sirene_status_changed | JSON | 8003 WS |

#### SirenePupitre

| Direction | Type | Format | Port |
|-----------|------|--------|------|
| ← Console | CONSOLE_CONNECT/DISCONNECT | JSON | 8000 WS |
| ← Console | PARAM_UPDATE | JSON | 8000 WS |
| → Console | PUPITRE_STATUS | JSON | 8000 WS |
| ← PureData | CONFIG_FULL | JSON | 10001 WS |
| ← PureData | PARAM_UPDATE | JSON | 10001 WS |
| ← PureData | MIDI Messages | Binaire | 10001 WS |
| → PureData | REQUEST_CONFIG | JSON | 10001 WS |
| → PureData | PARAM_CHANGED | JSON | 10001 WS |

#### pedalierSirenium

| Direction | Type | Format | Port |
|-----------|------|--------|------|
| → PureData | pedalConfigChange | JSON | 10000 WS |
| → PureData | savePreset/loadPreset | JSON | 10000 WS |
| → PureData | Scene actions | JSON | 10000 WS |
| ← PureData | SIREN_LOOPER | JSON | 10000 WS |
| ← PureData | LOOPER_SCENES | JSON | 10000 WS |
| ← PureData | MIDI Messages | Binaire | 10000 WS |

#### sirenRouter

| Direction | Type | Format | Port |
|-----------|------|--------|------|
| ← Sirènes | Status updates | JSON | 8004 UDP |
| → Consoles | Notifications | JSON | 8003 WS |
| ← Any | API Requests | JSON | 8002 HTTP |

## 🔐 Sécurité et Validation

### Validation des Messages

Tous les messages doivent :
- Avoir un champ `type` valide
- Respecter le schéma JSON attendu
- Contenir des valeurs dans les plages acceptables

### Gestion des Erreurs

En cas de message invalide :
```json
{
  "type": "ERROR",
  "code": "INVALID_MESSAGE",
  "message": "Le champ 'type' est requis",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Heartbeat et Reconnexion

- Heartbeat toutes les 30 secondes
- Reconnexion automatique après déconnexion
- Timeout après 60 secondes sans réponse

## 📚 Exemples Complets

Voir les fichiers de documentation spécifiques :
- [SirenePupitre/README.md](../SirenePupitre/README.md)
- [SirenConsole/README.md](../SirenConsole/README.md)
- [pedalierSirenium/README.md](../pedalierSirenium/README.md)
- [sirenRouter/README.md](../sirenRouter/README.md)

---

Pour l'architecture globale, voir [ARCHITECTURE.md](./ARCHITECTURE.md).  
Pour le guide de build, voir [BUILD.md](./BUILD.md).


