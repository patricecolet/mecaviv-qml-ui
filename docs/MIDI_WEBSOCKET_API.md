# API WebSocket MIDI - SirenConsole ↔ PureData

## 📋 Vue d'ensemble

Système de contrôle et monitoring MIDI avec **Node.js comme séquenceur central**.

**Architecture** :
```
SirenConsole (WASM - machine de contrôle)
    ↓ HTTP POST (commandes)
Node.js server.js
    ├─ MidiSequencer : Lecture MIDI, transport, calcul bar/beat
    ├─ Timer 50ms → Broadcast 0x01 POSITION (binaire 10 bytes)
    ├─ Envoi notes MIDI → PureData (WebSocket)
    └─ HTTP GET (polling état)
    ↓
SirenePupitre (Raspberry - pupitres)
    └─ PureData : Reçoit notes + position, synthèse audio
```

**Avantages** :
- ✅ Pas de PureData sur machine SirenConsole (plus portable)
- ✅ Synchro centralisée depuis Node.js
- ✅ PureData focus sur audio uniquement
- ✅ Format binaire ultra-compact (10 bytes @ 50ms = 200 bytes/sec)

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

**Format recommandé** : **BINAIRE multi-types** pour économiser bande passante

#### 0x01 - POSITION (10 bytes, haute fréquence 50ms)

État de lecture en temps réel, envoyé toutes les 50ms pendant lecture :

```
Offset  Size  Type      Field                    Exemple
------  ----  --------  -------------------      -------
0       1     uint8     messageType              0x01
1       1     uint8     flags (bit0=playing)     0x01
2       2     uint16    barNumber                13
4       2     uint16    beatInBar                2
6       4     float32   beat (total décimal)     50.5
------  ----  --------  -------------------      -------
Total: 10 bytes → 200 bytes/sec à 50ms
```

**Champs** :
- `barNumber` : Numéro de mesure (calculé avec changements de signature)
- `beatInBar` : Beat dans la mesure actuelle (1-n selon signature)
- `beat` : Beat total depuis le début (décimal pour précision)

**Construction** :
```
bytes[0] = 0x01
bytes[1] = playing ? 0x01 : 0x00
writeUInt16LE(barNumber, 2)
writeUInt16LE(beatInBar, 4)
writeFloat32LE(beat, 6)
```

**Note** : `barNumber` et `beatInBar` doivent être calculés en tenant compte des changements de signature temporelle dans le fichier MIDI.

---

#### 0x02 - FILE_INFO (10 bytes, au load)

Informations fichier, envoyé une fois au chargement :

```
Offset  Size  Type      Field                    
------  ----  --------  -----------------------
0       1     uint8     messageType (0x02)
1       1     uint8     reserved (0x00)
2       4     uint32    duration (ms total)
6       4     uint32    totalBeats
------  ----  --------  -----------------------
Total: 10 bytes
```

**Construction** :
```
bytes[0] = 0x02
bytes[1] = 0x00
writeUInt32LE(duration, 2)
writeUInt32LE(totalBeats, 6)
```

---

#### 0x03 - TEMPO (3 bytes, quand change)

Changement de tempo, envoyé seulement si tempo change :

```
Offset  Size  Type      Field                    
------  ----  --------  -----------------------
0       1     uint8     messageType (0x03)
1       2     uint16    tempo (BPM)
------  ----  --------  -----------------------
Total: 3 bytes
```

**Construction** :
```
bytes[0] = 0x03
writeUInt16LE(tempo, 1)
```

---

#### 0x04 - TIMESIG (3 bytes, quand change)

Changement de signature temporelle, envoyé seulement si signature change :

```
Offset  Size  Type      Field                    
------  ----  --------  -----------------------
0       1     uint8     messageType (0x04)
1       1     uint8     numerator (ex: 4)
2       1     uint8     denominator (ex: 4)
------  ----  --------  -----------------------
Total: 3 bytes
```

**Construction** :
```
bytes[0] = 0x04
bytes[1] = numerator
bytes[2] = denominator
```

---

**Avantages** :
- **6 bytes** à 50ms = **120 bytes/sec** vs 6000 bytes/sec JSON (98% économie !)
- Tempo/Signature : uniquement quand change (économie maximale)
- Parsing ultra-rapide
- Node.js décodage automatique via `puredata-proxy.js`

---

#### Format JSON (alternatif, pour debug)

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
    "totalBeats": 240
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

---

## 🎛️ Séquenceur MIDI Node.js

**Fichier** : `SirenConsole/webfiles/midi-sequencer.js`

**Fonctionnalités** :
- ✅ Lecture fichiers MIDI (via `midi-file`)
- ✅ Transport : play/pause/stop/seek
- ✅ Calcul bar/beat avec changements de signature
- ✅ Timer haute résolution 50ms
- ✅ Broadcast position binaire (0x01)
- ✅ Envoi notes MIDI à PureData
- ✅ Gestion tempo dynamique
- ✅ Map des changements de signature temporelle

**Commandes gérées** :
- `MIDI_FILE_LOAD` → Charge fichier, parse événements, build signature map
- `MIDI_TRANSPORT` → play/pause/stop avec timer
- `MIDI_SEEK` → Navigation précise (ms → tick → bar/beat)
- `TEMPO_CHANGE` → Ajuste tempo et broadcast 0x03

**Broadcast automatique** :
- 0x01 POSITION toutes les 50ms pendant lecture
- 0x03 TEMPO si changement dans fichier MIDI
- 0x04 TIMESIG si changement dans fichier MIDI
- Notes MIDI vers PureData via WebSocket

---

**Dernière mise à jour** : Octobre 2025  
**Status** : ✅ Séquenceur MIDI Node.js complet et fonctionnel - Architecture centralisée opérationnelle

