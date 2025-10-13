# API WebSocket MIDI - SirenConsole ↔ PureData

## 📋 Vue d'ensemble

Communication bidirectionnelle entre **SirenConsole** (client) et **PureData** (serveur) pour le contrôle et le monitoring de la lecture MIDI.

**Architecture** :
```
SirenConsole (WASM)
    ↓ HTTP POST
server.js (Node.js proxy)
    ↓ WebSocket (binaire UTF-8)
PureData (port 10002)
    ↓ WebSocket (binaire UTF-8)
server.js → SirenConsole
```

---

## 🎵 Messages : SirenConsole → PureData

### 1. MIDI_FILE_LOAD - Charger un fichier MIDI

**Envoyé quand** : L'utilisateur clique sur "▶ Charger" dans la bibliothèque

**Format JSON** :
```json
{
    "type": "MIDI_FILE_LOAD",
    "path": "louette/AnxioGapT.midi"
}
```

**Champs** :
- `type` (string) : `"MIDI_FILE_LOAD"`
- `path` (string) : Chemin relatif du fichier MIDI depuis `config.paths.midiRepository`

**Réponse attendue** :
- Envoyer `MIDI_PLAYBACK_STATE` avec `file`, `duration`, `totalBeats`, `timeSignature` mis à jour

---

### 2. MIDI_TRANSPORT - Contrôle Play/Pause/Stop

**Envoyé quand** : L'utilisateur clique sur ▶, ⏸, ou ⏹

**Format JSON** :
```json
{
    "type": "MIDI_TRANSPORT",
    "action": "play"
}
```

**Champs** :
- `type` (string) : `"MIDI_TRANSPORT"`
- `action` (string) : `"play"` | `"pause"` | `"stop"`

**Comportements attendus** :

| Action | Comportement |
|--------|--------------|
| `play` | Démarre la lecture depuis la position actuelle, broadcaster `playing=true` |
| `pause` | Pause la lecture (garde la position), broadcaster `playing=false` |
| `stop` | Arrête et revient à `position=0`, broadcaster `playing=false` |

**Réponse** : Broadcast continu de `MIDI_PLAYBACK_STATE` toutes les 50-100ms pendant lecture

---

### 3. MIDI_SEEK - Navigation dans le morceau

**Envoyé quand** : 
- L'utilisateur clique sur la barre de progression
- L'utilisateur édite MESURE ou BEAT et valide
- L'utilisateur clique sur ◀◀ ou ▶▶

**Format JSON** :
```json
{
    "type": "MIDI_SEEK",
    "position": 5234
}
```

**Champs** :
- `type` (string) : `"MIDI_SEEK"`
- `position` (int) : Position en **millisecondes**

**Réponse** : `MIDI_PLAYBACK_STATE` immédiat avec `position` et `beat` mis à jour

---

### 4. TEMPO_CHANGE - Modification du tempo

**Envoyé quand** : L'utilisateur édite le champ TEMPO et valide (ou ↑↓)

**Format JSON** :
```json
{
    "type": "TEMPO_CHANGE",
    "tempo": 140,
    "smooth": true
}
```

**Champs** :
- `type` (string) : `"TEMPO_CHANGE"`
- `tempo` (int) : Nouveau tempo en BPM (20-300)
- `smooth` (bool) : Si `true`, transition douce recommandée (optionnel)

**Réponse** : `MIDI_PLAYBACK_STATE` avec `tempo` mis à jour

---

## 📊 Messages : PureData → SirenConsole

### MIDI_PLAYBACK_STATE - État de lecture (temps réel)

**Envoyé quand** :
- Toutes les ~50-100ms pendant la lecture (pour fluidité UI)
- Immédiatement après un changement (load, seek, tempo, transport)
- En réponse à toute commande

**Format JSON** :
```json
{
    "type": "MIDI_PLAYBACK_STATE",
    "playing": true,
    "position": 5234,
    "beat": 8.5,
    "tempo": 120,
    "timeSignature": {
        "numerator": 4,
        "denominator": 4
    },
    "duration": 180000,
    "totalBeats": 240,
    "file": "louette/AnxioGapT.midi"
}
```

**Champs** :

| Champ | Type | Description | Exemple |
|-------|------|-------------|---------|
| `type` | string | Toujours `"MIDI_PLAYBACK_STATE"` | `"MIDI_PLAYBACK_STATE"` |
| `playing` | bool | État lecture (true = play, false = pause/stop) | `true` |
| `position` | int | Position en **millisecondes** | `5234` |
| `beat` | float | Beat actuel (décimal pour précision) | `8.5` |
| `tempo` | int | Tempo actuel en BPM | `120` |
| `timeSignature.numerator` | int | Battements par mesure | `4` |
| `timeSignature.denominator` | int | Type de note (4=noire, 8=croche) | `4` |
| `duration` | int | Durée totale en **millisecondes** | `180000` |
| `totalBeats` | int | Nombre total de beats dans le fichier | `240` |
| `file` | string | Chemin du fichier chargé | `"louette/AnxioGapT.midi"` |

**Calculs UI** (côté SirenConsole, pour info) :
```javascript
currentBar = Math.floor(beat / timeSignature.numerator) + 1
currentBeat = Math.floor(beat % timeSignature.numerator) + 1
currentFrame = Math.floor((beat % 1) * 960)  // 960 ticks/beat
```

**Fréquence recommandée** : 50-100ms pendant lecture pour fluidité UI

---

## 🧪 Tests recommandés

### Test 1 : Load + State
- SirenConsole envoie `MIDI_FILE_LOAD`
- PureData répond avec `MIDI_PLAYBACK_STATE` contenant `file`, `duration`, `totalBeats`
- SirenConsole affiche nom fichier et durée totale

### Test 2 : Play/Pause/Stop
- SirenConsole envoie `MIDI_TRANSPORT` action=play
- PureData broadcast `MIDI_PLAYBACK_STATE` toutes les 50ms avec `playing=true`, `position` croissante
- SirenConsole : barre progression se remplit, compteurs MESURE|BEAT|FRAME bougent

### Test 3 : Seek
- SirenConsole envoie `MIDI_SEEK` position=90000
- PureData répond immédiatement avec état mis à jour
- SirenConsole : affichage instantané de la nouvelle position

### Test 4 : Tempo
- SirenConsole envoie `TEMPO_CHANGE` tempo=140
- PureData répond avec état contenant nouveau tempo
- SirenConsole : affichage "140 BPM", lecture plus rapide

---

## 🔍 Débogage

### Logs Node.js (server.js)
- `📥 Requête: POST /api/puredata/command` : Commande depuis SirenConsole
- `📡 → PureData:` : JSON envoyé à PureData
- `📊 État lecture MIDI mis à jour` : État reçu de PureData

### Console Chrome (SirenConsole)
- `qml: 📁 Chargement fichier:` : Load file
- `qml: ▶ Play` : Transport play
- `qml: ⏸ Pause` : Transport pause
- Timer XHR : Polling état toutes les 100ms

---

## 💡 Notes importantes

### Format binaire obligatoire
PureData `pdjson` attend du **binaire UTF-8**, pas du texte :
```javascript
// ✅ CORRECT (server.js)
ws.send(Buffer.from(jsonString, 'utf8'))

// ❌ INCORRECT
ws.send(jsonString)  // → "Not a JSON object." dans PureData
```

### Fréquence broadcast
- **50-100ms** recommandé pour fluidité UI
- < 20ms : Surcharge réseau
- \> 200ms : UI saccadée

### Précision position
- Position en **millisecondes** dans les messages WebSocket
- Beat en **decimal** (ex: 8.5) pour précision sub-beat

### Signature temporelle
- Peut changer en cours de morceau
- Broadcaster la signature **à la position actuelle**

---

## 📚 Références

- **Architecture globale** : `docs/COMPOSESIREN_ARCHITECTURE.md`
- **Config centralisée** : `config.json`
- **Proxy Node.js** : `SirenConsole/webfiles/puredata-proxy.js`
- **Composant QML** : `SirenConsole/QML/components/MidiPlayer.qml`

---

**Dernière mise à jour** : Octobre 2025  
**Status** : ✅ Interface SirenConsole complète - Spec WebSocket documentée

