# Architecture du Système Mecaviv QML UI

Documentation détaillée de l'architecture globale du système de contrôle des sirènes musicales.

## 🏗️ Vue d'Ensemble

Le système est composé de **4 applications principales** et d'un **hub central PureData** qui orchestrent le contrôle et le monitoring de **7 sirènes musicales mécaniques**.

### Principe de Hiérarchie

```
Console (Priorité Max) → Pupitres (Contrôle Local) → PureData (Hub) → Sirènes (Instruments)
                                                            ↑
                                                    sirenRouter (Monitoring)
                                                            ↑
                                                    pedalierSirenium (Effets)
```

## 📊 Diagramme de Communication Détaillé

```
┌─────────────────────────────────────────────────────────────────────┐
│                          SirenConsole                               │
│                    Console de Contrôle Centrale                     │
│  • Gestion de 7 pupitres                                           │
│  • Configuration centralisée (ambitus, contrôleurs, courbes)       │
│  • Assignation exclusive des sirènes                               │
│  • Mode "All" pour configuration globale                           │
│  • Presets et synchronisation                                      │
│  Port 8001 | Qt6 QML WebAssembly                                   │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     │ WebSocket (JSON)
                     │ • CONSOLE_CONNECT/DISCONNECT
                     │ • PARAM_UPDATE (avec source: "console")
                     │ • PUPITRE_STATUS
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   SirenePupitre (×7 instances)                      │
│                  Visualiseurs Musicaux Locaux                       │
│  • Portée musicale 3D (clé sol/fa)                                 │
│  • Afficheurs LED 3D (Hz, RPM, note)                               │
│  • Indicateurs contrôleurs (volant, joystick, faders, etc.)        │
│  • Mode restricted/admin                                            │
│  • Panneau admin (config, visibilité, couleurs)                    │
│  Port 8000 + 10001 | Qt6 QML WebAssembly                           │
└─────┬───────────────────────────────────────────────────────────────┘
      │
      │ WebSocket Binaire/JSON (Port 10001)
      │ • CONFIG_FULL (chargement config)
      │ • PARAM_UPDATE (changements individuels)
      │ • REQUEST_CONFIG (demande de config)
      │ • Messages MIDI binaires (note, contrôleurs)
      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            PureData                                 │
│                    Hub Central de Routage                           │
│  • Réception MIDI : Reaper, Sirénium (DAW/Instruments)            │
│  • Réception UDP : Pupitres, pedalierSirenium                     │
│  • Routage MIDI vers sirènes physiques                             │
│  • Communication bidirectionnelle avec Router                       │
│  • Demande/libération de contrôle                                  │
│  Port 10000-10001 | PureData + WebSocket                           │
└─────┬──────────────────────────────────────┬────────────────────────┘
      │                                       │
      │ MIDI (Note On/Off, CC, Pitch Bend)   │ WebSocket (monitoring)
      │                                       │
      ▼                                       ▼
┌─────────────────────────────────┐   ┌──────────────────────────────┐
│    Sirènes Physiques (×7)       │   │      sirenRouter             │
│                                 │   │  Service de Monitoring       │
│  • Instruments mécaniques       │   │                              │
│  • Contrôle MIDI + UDP          │   │  • Monitoring passif (UDP)   │
│  • Feedback état (UDP)          │───▶  • API REST (consultation)  │
│  • VST virtuels                 │   │  • WebSocket (notifications) │
│                                 │   │  • Dashboard web             │
│  Ports variables                │   │                              │
└─────────────────────────────────┘   │  Ports 8002-8004 | Node.js  │
                                      └──────────────┬───────────────┘
                                                     │
                                                     │ WebSocket
                                                     │ (état sirènes)
                                                     ▼
                                      ┌──────────────────────────────┐
                                      │   pedalierSirenium           │
                                      │ Interface Pédalier 3D        │
                                      │                              │
                                      │  • 8 pédales × 7 sirènes     │
                                      │  • 8 contrôleurs par sirène  │
                                      │  • Gestion scènes (64)       │
                                      │  • Gestion presets           │
                                      │  • Contrôle boucles          │
                                      │  • Monitoring MIDI + portées │
                                      │                              │
                                      │  Port 8010 | Qt6 QML WASM    │
                                      └──────────────────────────────┘
```

## 🔄 Flux de Données

### 1. Contrôle depuis SirenConsole

**Scénario** : L'opérateur modifie l'ambitus d'un pupitre depuis la console.

```
1. SirenConsole (UI)
   ↓ Modification ambitus min/max
   
2. ConsoleController
   ↓ Génération message PARAM_UPDATE
   
3. WebSocket → SirenePupitre
   ↓ Message avec source: "console"
   
4. ConfigController (Pupitre)
   ↓ Mise à jour config locale
   
5. SirenController
   ↓ Recalcul note limitée
   
6. MusicalStaff3D
   ↓ Mise à jour affichage portée
```

**Message WebSocket** :
```json
{
  "type": "PARAM_UPDATE",
  "path": ["sirenConfig", "sirens", 0, "ambitus", "min"],
  "value": 48,
  "source": "console"
}
```

### 2. Performance Musicale Temps Réel

**Scénario** : Un musicien joue avec le Sirénium (contrôleur MIDI).

```
1. Sirénium (Hardware MIDI)
   ↓ Note On (canal 1, note 60, vélocité 90)
   
2. PureData (Reception MIDI)
   ↓ Routage selon canal → Sirène
   
3. PureData → Sirène Physique (MIDI)
   ↓ Note On exécutée
   
4. Sirène → PureData (UDP feedback)
   ↓ État actuel (RPM, fréquence)
   
5. PureData → SirenePupitre (WebSocket binaire)
   ↓ Message MIDI + données musicales
   
6. SirenController (Calculs)
   ↓ MIDI note → fréquence → RPM
   
7. Interface 3D (Affichage)
   ↓ Mise à jour portée, curseur, LEDs
```

### 3. Monitoring par sirenRouter

**Scénario** : Monitoring passif de l'état des sirènes.

```
1. Sirène Physique
   ↓ UDP broadcast (état toutes les 100ms)
   
2. sirenRouter (UDP Server)
   ↓ Réception état + stockage
   
3. sirenRouter → SirenConsole (WebSocket)
   ↓ Notification temps réel
   
4. SirenConsole (OverviewPage)
   ↓ Mise à jour indicateurs status
```

**Trame UDP** (Sirène → Router) :
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

### 4. Gestion de Scènes (pedalierSirenium)

**Scénario** : Chargement d'une scène prédéfinie.

```
1. pedalierSirenium (SceneManager)
   ↓ Clic sur scène 3
   
2. WebSocket → PureData
   ↓ {"device": "LOOPER_SCENES", "action": "loadScene", "sceneId": 3}
   
3. PureData (Gestion Scènes)
   ↓ Chargement config boucles
   
4. PureData → pedalierSirenium (WebSocket)
   ↓ {"device": "LOOPER_SCENES", "batch": "sceneLoaded", ...}
   
5. SirenController (×7 sirènes)
   ↓ Mise à jour états transport
   
6. SirenView (UI 3D)
   ↓ Animations boucles (recording/playing/stopped/cleared)
```

## 📡 Protocoles de Communication

### WebSocket Messages

#### Format Général
Tous les messages WebSocket suivent ce format JSON :

```json
{
  "type": "MESSAGE_TYPE",
  "data": { ... },
  "source": "application_source",
  "timestamp": "ISO8601"
}
```

#### Messages Spécifiques

##### Console → Pupitre
```json
// Prise de contrôle
{
  "type": "CONSOLE_CONNECT",
  "source": "console"
}

// Modification paramètre
{
  "type": "PARAM_UPDATE",
  "path": ["displayConfig", "components", "rpm", "visible"],
  "value": true,
  "source": "console"
}
```

##### Pupitre → Console
```json
// Statut du pupitre
{
  "type": "PUPITRE_STATUS",
  "pupitreId": "P1",
  "status": "connected",
  "data": {
    "assignedSirenes": [1, 2],
    "vstEnabled": true,
    "midiNote": 60,
    "frequency": 261.63,
    "rpm": 1308
  }
}
```

##### PureData → Pupitre
```json
// Configuration complète
{
  "type": "CONFIG_FULL",
  "config": {
    "serverUrl": "ws://localhost:10001",
    "sirenConfig": { ... },
    "displayConfig": { ... }
  }
}

// Mise à jour paramètre
{
  "type": "PARAM_UPDATE",
  "path": ["sirenConfig", "currentSiren"],
  "value": "2"
}
```

##### pedalierSirenium ↔ PureData (Binaire MIDI)

Les messages MIDI sont transmis en **binaire** (1-3 octets) :

```
Note On:   [0x90 | canal, note, vélocité]
Note Off:  [0x80 | canal, note, 0]
CC:        [0xB0 | canal, controller, value]
Pitch Bend: [0xE0 | canal, lsb, msb]
Clock:     [0xF8] (1 octet)
```

### UDP Messages

#### Sirène → sirenRouter (Monitoring)

**Port** : 8004  
**Format** : JSON

```json
{
  "sireneId": 1,
  "status": "playing",
  "currentNote": 69.5,
  "volume": 0.8,
  "frequency": 440.0,
  "rpm": 1200,
  "controllers": {
    "wheel": { "position": 45, "velocity": 10.5 },
    "joystick": { "x": 0.0, "y": 0.0, "z": 0.0, "button": false }
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### REST API (sirenRouter)

#### GET `/api/status/sirenes`

Récupère l'état de toutes les sirènes.

**Réponse** :
```json
{
  "sirenes": {
    "1": { "status": "playing", "currentNote": 69.5, ... },
    "2": { "status": "stopped", ... },
    ...
  }
}
```

#### GET `/api/status/sirenes/:id`

Récupère l'état d'une sirène spécifique.

## 🔐 Gestion des Priorités

### Hiérarchie de Contrôle

1. **Console** (Priorité Maximale)
   - Peut prendre le contrôle de n'importe quel pupitre
   - Bloque les modifications locales sur le pupitre
   - Envoie des messages avec `source: "console"`

2. **Pupitre** (Contrôle Local)
   - Mode autonome par défaut
   - Peut être contrôlé par la console
   - Bandeau "Console connectée" quand contrôlé

3. **PureData** (Exécution)
   - Exécute les commandes reçues
   - Routage MIDI vers sirènes
   - Pas de décision, seulement exécution

### Système de Takeover

Quand la console se connecte à un pupitre :

```
1. Console envoie CONSOLE_CONNECT
   ↓
2. Pupitre désactive panneau admin
   ↓
3. Pupitre affiche bandeau "Console connectée"
   ↓
4. Modifications locales bloquées
   ↓
5. Console peut modifier tous les paramètres
```

Quand la console se déconnecte :

```
1. Console envoie CONSOLE_DISCONNECT
   ↓
2. Pupitre réactive panneau admin
   ↓
3. Pupitre masque bandeau
   ↓
4. Modifications locales autorisées
   ↓
5. Pupitre redevient autonome
```

## 🎯 Points d'Extension

### Ajout d'une Nouvelle Application

Pour ajouter une application au système :

1. **Créer le projet** dans le monorepo
2. **Implémenter WebSocketController** pour communication
3. **Définir les messages** spécifiques (protocole JSON)
4. **Documenter l'API** dans COMMUNICATION.md
5. **Ajouter au script de build** centralisé
6. **Mettre à jour** ce document ARCHITECTURE.md

### Ajout d'un Nouveau Type de Sirène

Pour supporter un nouveau type de sirène :

1. **Définir les spécifications** dans `sirenSpec.json`
2. **Adapter les calculs** MIDI → Hz → RPM
3. **Mettre à jour l'interface** (portée, clé, ambitus)
4. **Tester** avec toutes les applications
5. **Documenter** les particularités

## 📦 Dépendances entre Applications

### SirenConsole ← → SirenePupitre
- **Direction** : Bidirectionnelle
- **Protocol** : WebSocket (JSON)
- **Dépendance** : Console peut contrôler les pupitres

### SirenePupitre ← → PureData
- **Direction** : Bidirectionnelle
- **Protocol** : WebSocket (JSON + Binaire)
- **Dépendance** : Pupitre reçoit les données musicales

### pedalierSirenium ← → PureData
- **Direction** : Bidirectionnelle
- **Protocol** : WebSocket (JSON + Binaire)
- **Dépendance** : Pédalier contrôle les effets et boucles

### Sirènes → sirenRouter
- **Direction** : Unidirectionnelle
- **Protocol** : UDP (JSON)
- **Dépendance** : Monitoring passif, pas de contrôle

### sirenRouter → SirenConsole
- **Direction** : Unidirectionnelle
- **Protocol** : WebSocket (JSON)
- **Dépendance** : Notifications d'état

## 🔄 Cycle de Vie

### Démarrage du Système

```
1. Démarrer sirenRouter (monitoring)
2. Démarrer PureData (hub central)
3. Démarrer les 7 SirenePupitre (visualisation)
4. Démarrer SirenConsole (contrôle)
5. Optionnel : Démarrer pedalierSirenium (effets)
```

### Arrêt Gracieux

```
1. SirenConsole envoie CONSOLE_DISCONNECT à tous les pupitres
2. pedalierSirenium sauvegarde les presets en cours
3. SirenePupitre ferme les connexions WebSocket
4. PureData arrête le routage MIDI
5. sirenRouter ferme les serveurs (REST, WS, UDP)
```

## 📈 Scalabilité

Le système est conçu pour supporter :

- **7 sirènes** actuellement
- **Extensible** à plus de sirènes (modification de `sirenSpec`)
- **Multiple consoles** possibles (priorité gérée)
- **Monitoring distribué** (plusieurs instances de router)
- **Déploiement cloud** (WebAssembly + serveurs)

---

Pour plus de détails sur les protocoles, voir [COMMUNICATION.md](./COMMUNICATION.md).  
Pour le guide de build, voir [BUILD.md](./BUILD.md).


