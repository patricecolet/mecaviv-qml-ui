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

## 🎮 Mode Autonome SirenePupitre

### Vue d'ensemble

Le **mode autonome** permet à chaque SirenePupitre de lancer et contrôler la lecture de morceaux MIDI indépendamment de SirenConsole. PureData gère le séquenceur MIDI et diffuse la position aux pupitres.

**Architecture** :
```
SirenePupitre (QML - interface)
    ↓ Commandes JSON (binaire UTF-8)
PureData (Raspberry - séquenceur)
    ├─ Lecture MIDI locale
    ├─ Broadcast 0x01 POSITION (10 bytes @ 50ms)
    ├─ Broadcast 0x04 NOTES (5 bytes)
    └─ Broadcast 0x05 CC (3 bytes)
    ↓
SirenePupitre (affichage jeu)
```

### Messages : SirenePupitre → PureData

Tous les messages sont encodés en **JSON binaire UTF-8** via `WebSocketController.sendBinaryMessage()`.

#### 1. MIDI_FILES_REQUEST - Demander la liste des morceaux

```json
{
  "type": "MIDI_FILES_REQUEST",
  "source": "pupitre"
}
```

**Réponse attendue** : `MIDI_FILES_LIST` (JSON texte)

#### 2. MIDI_FILE_LOAD - Charger un morceau

```json
{
  "type": "MIDI_FILE_LOAD",
  "path": "louette/AnxioGapT.midi",
  "source": "pupitre"
}
```

**Champs** :
- `path` : Chemin relatif depuis `midiRepository`
- `source` : `"pupitre"` pour traçabilité

#### 3. MIDI_TRANSPORT - Contrôle play/pause/stop

```json
{
  "type": "MIDI_TRANSPORT",
  "action": "play",
  "source": "pupitre"
}
```

**Actions** :
- `"play"` : Démarre la lecture
- `"pause"` : Pause (garde la position)
- `"stop"` : Arrête et revient à position 0

### Messages : PureData → SirenePupitre

#### MIDI_FILES_LIST (JSON texte)

Réponse à `MIDI_FILES_REQUEST` :

```json
{
  "type": "MIDI_FILES_LIST",
  "categories": [
    {
      "name": "Louette",
      "files": [
        { "title": "AnxioGapT", "path": "louette/AnxioGapT.midi" },
        { "title": "HallucinogeneGapT", "path": "louette/HallucinogeneGapT.midi" }
      ]
    },
    {
      "name": "Patwave",
      "files": [
        { "title": "Daphné", "path": "patwave/daphne.midi" }
      ]
    }
  ]
}
```

#### 0x01 - POSITION (10 bytes, 50-100ms)

Position de lecture en temps réel :

```
Offset  Size  Type      Field                    
------  ----  --------  -----------------------
0       1     uint8     messageType (0x01)
1       1     uint8     flags (bit0=playing)
2       2     uint16    barNumber (LE)
4       2     uint16    beatInBar (LE)
6       4     float32   beat (total décimal, LE)
------  ----  --------  -----------------------
Total: 10 bytes
```

**Exemple** : Mesure 13, beat 2, beat total 50.5, playing=true
```
[0x01, 0x01, 0x0D, 0x00, 0x02, 0x00, <float32LE(50.5)>]
```

**Usage** : Progression visuelle en mode jeu (barre de progression, position temporelle)

### Différences avec SirenConsole

| Aspect | SirenConsole | SirenePupitre |
|--------|--------------|---------------|
| Séquenceur | Node.js | PureData (local) |
| Contrôle | HTTP POST | WebSocket binaire |
| Position | 0x01 broadcast central | 0x01 local |
| Seek | Oui (MIDI_SEEK) | Non (source PureData) |

---

## 📚 Références

- **Architecture globale** : `docs/COMPOSESIREN_ARCHITECTURE.md`
- **Config centralisée** : `config.json`
- **Proxy Node.js** : `SirenConsole/webfiles/puredata-proxy.js`
- **Composant QML** : `SirenConsole/QML/components/MidiPlayer.qml`
- **Mode autonome Pupitre** : `SirenePupitre/QML/game/GameAutonomyPanel.qml`

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

## 🎮 Messages Mode Jeu "Siren Hero"

### Architecture Multi-Joueurs

**Rôles** :
- **PureData** (chaque Raspberry) : Moteur du jeu (lit MIDI + calcule score)
- **Node.js** (SirenConsole) : Coordinateur (synchro + leaderboard)
- **QML** (SirenePupitre) : Interface visuelle (partition + feedback)

```
SirenConsole (Node.js - Coordinateur)
    │
    ├─→ broadcast GAME_START (synchro)
    │
    ↓
7× Raspberry Pi (autonomes)
    ├─ PureData:
    │  ├─ Lit fichier MIDI localement
    │  ├─ Reçoit contrôleurs UDP (MCU)
    │  ├─ Compare contrôleurs vs séquence MIDI
    │  └─ Calcule score (Perfect/Good/Miss)
    │
    ├─ SirenePupitre (QML):
    │  ├─ Affiche partition défilante
    │  └─ Feedback visuel temps réel
    │
    └─→ GAME_SCORE_UPDATE 0x11 (PureData → Console via WebSocket)
    ↓
SirenConsole (Node.js)
    ├─ Collecte scores des 7 pupitres
    ├─ Trie par score (leaderboard)
    └─→ broadcast GAME_LEADERBOARD 0x12
```

### 1. GAME_START (Console → Pupitres)

**Lancement d'une partie multi-joueurs synchronisée**

```json
{
  "type": "GAME_START",
  "midiFile": "louette/bach_partita.mid",
  "mode": "challenge",
  "difficulty": "medium",
  "syncTimestamp": 1697212800000,
  "countdown": 3,
  "options": {
    "lookaheadMs": 2000,
    "toleranceMs": 150,
    "showNotes": true,
    "practiceMode": false
  }
}
```

**Champs** :
- `midiFile` : Chemin relatif depuis midiRepository
- `mode` : `"practice"`, `"challenge"`, `"performance"`, `"training"`
- `difficulty` : `"easy"`, `"medium"`, `"hard"`, `"expert"`
- `syncTimestamp` : Timestamp Unix (ms) de démarrage synchronisé
- `countdown` : Décompte en secondes avant le début
- `options.lookaheadMs` : Avance d'affichage des notes (ms)
- `options.toleranceMs` : Fenêtre de tolérance pour Perfect/Good/Miss
- `options.showNotes` : Afficher les notes à l'avance
- `options.practiceMode` : Mode entraînement (pas de score)

### 2. GAME_SCORE_UPDATE (Pupitre → Console) - FORMAT BINAIRE

**Mise à jour du score en temps réel (toutes les secondes)**

**Format** : `0x11 - GAME_SCORE_UPDATE` (14 bytes)

```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x11 (GAME_SCORE_UPDATE)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint32  | score           | Score total (0 à 4 294 967 295)
6      | uint16  | combo           | Combo actuel (0-65535)
8      | uint16  | maxCombo        | Meilleur combo (0-65535)
10     | uint8   | accuracy        | Précision * 100 (0-100%)
11     | uint8   | perfect         | Nombre Perfect (0-255)
12     | uint8   | good            | Nombre Good (0-255)
13     | uint8   | miss            | Nombre Miss (0-255)
```

**Total** : 14 bytes (vs ~180 bytes JSON)

**Exemple** :
```javascript
// Score 8750, combo 42, maxCombo 67, accuracy 87%, 45 perfect, 23 good, 12 miss
Buffer: [0x11, 0x03, 0x2E, 0x22, 0x00, 0x00, 0x2A, 0x00, 0x43, 0x00, 0x57, 0x2D, 0x17, 0x0C]
//       type  pup   score (LE)          combo maxC  acc   perf good miss
```

### 3. GAME_NOTE_HIT (Pupitre → Console) - FORMAT BINAIRE

**Feedback d'une note jouée (temps réel, envoi à chaque note)**

**Format** : `0x10 - GAME_NOTE_HIT` (9 bytes)

```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x10 (GAME_NOTE_HIT)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint8   | noteNumber      | Note MIDI (0-127)
3      | uint8   | expectedValue   | Contrôleur attendu (0-127)
4      | uint8   | actualValue     | Contrôleur joué (0-127)
5      | int16   | timingMs        | Timing signé (-500 à +500 ms)
7      | uint8   | rating          | 0=miss, 1=good, 2=perfect
8      | uint8   | scoreGained     | Points gagnés / 10 (0-255 → 0-2550)
```

**Total** : 9 bytes (vs ~150 bytes JSON)

**Exemple** :
```javascript
// Perfect hit: Note 60, attendu 64, joué 67, timing +23ms, 250 points
Buffer: [0x10, 0x03, 0x3C, 0x40, 0x43, 0x00, 0x17, 0x02, 0x19]
//       type  pup   note  exp   act   timing   rat   score
```

### 4. GAME_END (Pupitre → Console)

**Signal de fin de partie**

```json
{
  "type": "GAME_END",
  "pupitreId": "pupitre_3",
  "finalScore": 12450,
  "accuracy": 0.89,
  "rank": "A",
  "stats": {
    "perfect": 67,
    "good": 28,
    "miss": 5,
    "totalNotes": 100,
    "maxCombo": 73,
    "duration": 185000
  }
}
```

**Champs** :
- `finalScore` : Score final de la partie
- `rank` : `"S"` (perfect), `"A"` (>90%), `"B"` (>75%), `"C"` (>60%), `"D"` (<60%)
- `stats.duration` : Durée de la partie en ms

### 5. GAME_LEADERBOARD (Console → Pupitres) - FORMAT BINAIRE

**Classement temps réel (broadcast toutes les 2 secondes)**

**Format** : `0x12 - GAME_LEADERBOARD` (1 + N×9 bytes, N = nombre de joueurs)

**En-tête** (1 byte) :
```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x12 (GAME_LEADERBOARD)
```

**Par joueur** (9 bytes, répété N fois) :
```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | rank            | Position classement (1-7)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint32  | score           | Score total (little-endian)
6      | uint16  | combo           | Meilleur combo (little-endian)
8      | uint8   | accuracy        | Précision * 100 (0-100%)
```

**Total** : 1 + (9 × 7) = **64 bytes max** (vs ~400 bytes JSON pour 7 joueurs)

**Exemple (3 joueurs)** :
```javascript
// Top 3: P5 (14200pts, 89combo, 94%), P3 (12450pts, 73combo, 89%), P1 (10000pts, 60combo, 82%)
Buffer: [0x12, 
         0x01, 0x05, 0x78, 0x37, 0x00, 0x00, 0x59, 0x00, 0x5E,  // Rank 1: P5
         0x02, 0x03, 0xA2, 0x30, 0x00, 0x00, 0x49, 0x00, 0x59,  // Rank 2: P3
         0x03, 0x01, 0x10, 0x27, 0x00, 0x00, 0x3C, 0x00, 0x52]  // Rank 3: P1
```

**Note** : Les noms de joueurs ne sont pas transmis en binaire (économie de bande passante). Chaque pupitre connaît son propre nom localement.

### 6. GAME_PAUSE (Console → Pupitres)

**Mise en pause synchronisée**

```json
{
  "type": "GAME_PAUSE",
  "paused": true
}
```

### 7. GAME_ABORT (Console → Pupitres)

**Annulation de la partie**

```json
{
  "type": "GAME_ABORT",
  "reason": "Network error"
}
```

---

## 📊 Flux Complet Mode Jeu

```
1. SirenConsole → broadcast GAME_START (JSON, 1 fois)
   ↓
2. Pupitres démarrent countdown (3...2...1...GO!)
   ↓
3. PureData lit MIDI + calcule score
   ↓
4. Pupitres → GAME_NOTE_HIT 0x10 (chaque note, 9 bytes)
   ↓
5. Pupitres → GAME_SCORE_UPDATE 0x11 (toutes les secondes, 14 bytes)
   ↓
6. Console → broadcast GAME_LEADERBOARD 0x12 (toutes les 2s, 64 bytes max)
   ↓
7. Fin du morceau → Pupitres → GAME_END (JSON, 1 fois)
   ↓
8. Console → broadcast GAME_LEADERBOARD 0x12 (final)
```

### 🚀 Optimisation Binaire

**Bande passante économisée** :

Exemple partie 3 minutes, 150 notes, 7 joueurs :
- **JSON** :
  - GAME_NOTE_HIT: 150 notes × 150 bytes × 7 = **157 KB**
  - GAME_SCORE_UPDATE: 180 sec × 180 bytes × 7 = **221 KB**
  - GAME_LEADERBOARD: 90 broadcasts × 400 bytes = **36 KB**
  - **Total** : ~414 KB

- **Binaire** :
  - GAME_NOTE_HIT: 150 × 9 bytes × 7 = **9.4 KB**
  - GAME_SCORE_UPDATE: 180 × 14 bytes × 7 = **17.6 KB**
  - GAME_LEADERBOARD: 90 × 64 bytes = **5.8 KB**
  - **Total** : ~33 KB

**Économie** : **92%** (414 KB → 33 KB) ⚡

**Avantages** :
- Latence minimale sur WiFi Raspberry Pi
- Peut gérer 30+ joueurs simultanés
- Pas de lag même avec beaucoup de notes rapides
- Parfait pour morceaux virtuoses (Paganini, Flight of the Bumblebee)

## 📋 Tableau Récapitulatif des Messages Binaires

| Type | ID   | Nom                  | Taille   | Fréquence            | Direction            | Contexte        |
|------|------|----------------------|----------|----------------------|----------------------|-----------------|
| 0x01 | MIDI | POSITION             | 10 bytes | 50ms (lecture)       | Node.js → Clients    | Séquenceur MIDI |
| 0x02 | MIDI | FILE_INFO            | 10 bytes | 1× (chargement)      | Node.js → Clients    | Séquenceur MIDI |
| 0x03 | MIDI | TEMPO                | 3 bytes  | Changement           | Node.js → Clients    | Séquenceur MIDI |
| 0x04 | MIDI | TIMESIG              | 3 bytes  | Changement           | Node.js → Clients    | Séquenceur MIDI |
| 0x10 | GAME | NOTE_HIT             | 9 bytes  | Chaque note          | PureData → Console   | Mode Jeu        |
| 0x11 | GAME | SCORE_UPDATE         | 14 bytes | 1 sec (partie)       | PureData → Console   | Mode Jeu        |
| 0x12 | GAME | LEADERBOARD          | 1+N×9    | 2 sec (partie)       | Console → PureData   | Mode Jeu        |

**Clarification** :
- **Messages 0x01-0x04** : Séquenceur MIDI (Node.js lit MIDI, broadcast position/tempo)
- **Messages 0x10-0x11** : Mode Jeu (PureData lit MIDI, calcule score, envoie à Console)
- **Message 0x12** : Mode Jeu (Console collecte scores, broadcast leaderboard)

**Bande passante totale** :
- **Séquenceur MIDI** : ~200 bytes/sec pendant lecture
- **Mode Jeu (7 joueurs)** : ~300 bytes/sec pendant partie
- **Total** : ~500 bytes/sec (vs ~6500 JSON) = **92% économie**

---

**Dernière mise à jour** : 13 Octobre 2025  
**Status** : ✅ Séquenceur MIDI Node.js complet - 🎮 Protocole Mode Jeu binaire défini (92% économie)

