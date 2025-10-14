# Messages Binaires PureData - Mode Jeu "Siren Hero"

## 📋 Vue d'ensemble

PureData envoie 2 types de messages binaires au serveur Node.js pendant le mode jeu :
- **0x10 - GAME_NOTE_HIT** : Feedback d'une note jouée (temps réel)
- **0x11 - GAME_SCORE_UPDATE** : Mise à jour du score (toutes les secondes)

Le serveur Node.js renvoie :
- **0x12 - GAME_LEADERBOARD** : Classement temps réel (toutes les 2 secondes)

---

## 📤 Messages à ENVOYER depuis PureData

### 0x10 - GAME_NOTE_HIT (9 bytes)

**Quand** : À chaque note jouée par le musicien (temps réel)

**Format** :
```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x10 (GAME_NOTE_HIT)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint8   | noteNumber      | Note MIDI (0-127)
3      | uint8   | expectedValue   | Contrôleur attendu (0-127)
4      | uint8   | actualValue     | Contrôleur joué (0-127)
5      | int16   | timingMs        | Timing signé (-500 à +500 ms, little-endian)
7      | uint8   | rating          | 0=miss, 1=good, 2=perfect
8      | uint8   | scoreGained     | Points gagnés / 10 (0-255 → 0-2550)
```

**Exemple PureData (liste à envoyer via [mrpeach/packOSC] → WebSocket)** :
```
# Note 60 (C4), parfaite, timing +23ms, 250 points
16 3 60 64 67 23 0 2 25
```

**Calcul du rating** :
```
difference = abs(expectedValue - actualValue)
tolerance = 10  # Dépend de la difficulté

accuracy = 1 - (difference / tolerance)

if accuracy >= 0.95: rating = 2  # perfect
elif accuracy >= 0.80: rating = 1  # good
elif accuracy >= 0.50: rating = 0  # ok (pas de reset combo)
else: rating = -1  # miss (mais on envoie 0 en binaire)
```

**Code PureData pour créer le message** :
```
[pack 0x10 $1 $2 $3 $4 $5 $6 $7 $8]
|
# $1 = pupitreId (1-7)
# $2 = noteNumber (0-127)
# $3 = expectedValue (0-127)
# $4 = actualValue (0-127)
# $5 = timingMs (-500 à +500)
# $6 = rating (0, 1, ou 2)
# $7 = scoreGained / 10
|
[list prepend send]
|
[list trim]
|
[pdjson]  # Envoie via WebSocket
```

---

### 0x11 - GAME_SCORE_UPDATE (14 bytes)

**Quand** : Toutes les secondes pendant la partie

**Format** :
```
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x11 (GAME_SCORE_UPDATE)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint32  | score           | Score total (0 à 4 294 967 295, little-endian)
6      | uint16  | combo           | Combo actuel (0-65535, little-endian)
8      | uint16  | maxCombo        | Meilleur combo (0-65535, little-endian)
10     | uint8   | accuracy        | Précision * 100 (0-100%)
11     | uint8   | perfect         | Nombre Perfect (0-255)
12     | uint8   | good            | Nombre Good (0-255)
13     | uint8   | miss            | Nombre Miss (0-255)
```

**Exemple PureData** :
```
# Score 12450, combo 42, maxCombo 73, accuracy 89%, 45 perfect, 23 good, 8 miss
17 3 162 48 0 0 42 0 73 0 89 45 23 8
```

**Calcul accuracy** :
```
totalHits = perfect + good + miss
if totalHits > 0:
    accuracy = floor(((perfect * 100 + good * 80) / (totalHits * 100)) * 100)
```

**Code PureData pour créer le message** :
```
# Variables à maintenir dans PureData :
# - score (compteur)
# - combo (compteur, reset à 0 sur miss)
# - maxCombo (max de combo)
# - perfect, good, miss (compteurs)

# Calcul accuracy
[expr (($f1 * 100 + $f2 * 80) / (($f1 + $f2 + $f3) * 100)) * 100]
|
[int]  # accuracy (0-100)
|
[pack 0x11 $1 $2 $3 $4 $5 $6 $7 $8 $9 $10]
|
# $1 = pupitreId
# $2 = score (byte 0, poids faible)
# $3 = score (byte 1)
# $4 = score (byte 2)
# $5 = score (byte 3, poids fort)
# $6 = combo (byte 0)
# $7 = combo (byte 1)
# $8 = maxCombo (byte 0)
# $9 = maxCombo (byte 1)
# $10 = accuracy
|
[list prepend send]
|
[pdjson]
```

**Note importante** : Pour les valeurs multi-bytes (uint32, uint16), il faut les décomposer en bytes **little-endian** :

```
# Exemple : score = 12450 = 0x30A2
# Little-endian : A2 30 00 00

score = 12450
byte0 = score & 0xFF          # 0xA2 = 162
byte1 = (score >> 8) & 0xFF   # 0x30 = 48
byte2 = (score >> 16) & 0xFF  # 0x00 = 0
byte3 = (score >> 24) & 0xFF  # 0x00 = 0

# Dans PureData :
[expr $f1 & 255]        # byte0
[expr ($f1 >> 8) & 255] # byte1
[expr ($f1 >> 16) & 255] # byte2
[expr ($f1 >> 24) & 255] # byte3
```

---

## 📥 Messages à RECEVOIR dans PureData

### 0x12 - GAME_LEADERBOARD (1 + N×9 bytes)

**Quand** : Toutes les 2 secondes pendant la partie (broadcast depuis le serveur)

**Format** :
```
Header (1 byte):
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | messageType     | 0x12 (GAME_LEADERBOARD)

Par joueur (9 bytes, répété N fois):
Offset | Type    | Champ           | Description
-------|---------|-----------------|----------------------------------
0      | uint8   | rank            | Position classement (1-7)
1      | uint8   | pupitreId       | ID pupitre (1-7)
2      | uint32  | score           | Score total (little-endian)
6      | uint16  | combo           | Meilleur combo (little-endian)
8      | uint8   | accuracy        | Précision * 100 (0-100%)
```

**Exemple (3 joueurs)** :
```
Hex: 12 01 05 78 37 00 00 59 00 5E 02 03 A2 30 00 00 49 00 59 03 01 10 27 00 00 3C 00 52
      |  Rank 1: P5         |  Rank 2: P3         |  Rank 3: P1         |
```

**Décodage dans PureData** :
```
[pdjson]  # Reçoit le buffer binaire
|
[route binary]  # Filtre les messages binaires
|
[unpack 0 0 0 0 ...]  # Décompose en bytes
|
[route 18]  # Filtre messageType 0x12 (18 en décimal)
|
# Parser les joueurs (boucle sur les 9 bytes)
```

**Exemple de parsing d'un joueur** :
```
# bytes : rank pupitreId score0 score1 score2 score3 combo0 combo1 accuracy

rank = byte[0]
pupitreId = byte[1]
score = byte[2] + (byte[3] << 8) + (byte[4] << 16) + (byte[5] << 24)
combo = byte[6] + (byte[7] << 8)
accuracy = byte[8]
```

---

## 🎯 Messages JSON (non binaires)

### GAME_START (Console → PureData)

**Format** :
```json
{
  "type": "GAME_START",
  "midiFile": "louette/AnxioGapT.midi",
  "mode": "practice",
  "difficulty": "normal",
  "syncTimestamp": 1760372135119,
  "countdown": 3,
  "options": {
    "lookaheadMs": 2000,
    "toleranceMs": 150,
    "showNotes": true,
    "practiceMode": false
  }
}
```

**Code PureData pour recevoir** :
```
[pdjson]
|
[route type]
|
[route GAME_START]
|
[route midiFile mode difficulty syncTimestamp countdown options]
```

### GAME_END (PureData → Console)

**Format** :
```json
{
  "type": "GAME_END",
  "pupitreId": 3,
  "finalScore": 12450,
  "accuracy": 0.89,
  "rank": "A",
  "stats": {
    "perfect": 45,
    "good": 23,
    "miss": 8,
    "totalNotes": 76,
    "maxCombo": 73,
    "duration": 185000
  }
}
```

**Code PureData pour envoyer** :
```
[makefilename {\"type\":\"GAME_END\",\"pupitreId\":%d,...}]
|
[pdjson]
```

---

## 📊 Flux Complet d'une Partie

```
1. Console → broadcast GAME_START (JSON)
   ↓
2. PureData reçoit → Démarre countdown (3...2...1...GO!)
   ↓
3. PureData lit fichier MIDI localement + calcule score
   ↓
4. Musicien joue → PureData envoie GAME_NOTE_HIT 0x10 (chaque note, 9 bytes)
   ↓
5. PureData envoie GAME_SCORE_UPDATE 0x11 (toutes les secondes, 14 bytes)
   ↓
6. Console → broadcast GAME_LEADERBOARD 0x12 (toutes les 2s, 1+N×9 bytes)
   ↓
7. Fin du morceau → PureData envoie GAME_END (JSON)
```

---

## 🧪 Test des Messages

### Test GAME_NOTE_HIT (0x10)

Dans PureData :
```
[bang]
|
[16 3 60 64 67 23 0 2 25(  # Perfect hit
|
[list prepend send]
|
[pdjson]
```

Console Node.js devrait afficher :
```
✨ P3 PERFECT: Note 60, 250pts, timing +23ms
```

### Test GAME_SCORE_UPDATE (0x11)

Dans PureData :
```
[bang]
|
[17 3 162 48 0 0 42 0 73 0 89 45 23 8(  # Score 12450
|
[list prepend send]
|
[pdjson]
```

Console Node.js devrait afficher :
```
🎯 Score P3: 12450pts, combo 42, acc 89%
```

---

## 💡 Notes Importantes

### 1. Little-Endian

Tous les entiers multi-bytes (uint16, uint32, int16) sont en **little-endian** :
- Byte de poids **faible** en premier
- Exemple : `12450 = 0x30A2` → bytes `[A2 30]` (162, 48)

### 2. Envoi via pdjson

Le patch `pdjson` attend une **liste de bytes** avec `send` en préfixe :
```
send 16 3 60 64 67 23 0 2 25
```

### 3. Réception binaire

Pour recevoir un message binaire dans PureData :
```
[pdjson]
|
[route binary]  # Filtre les messages binaires
|
[unpack 0 0 0 ...]  # Décompose en liste de bytes
```

### 4. Timing négatif

Le champ `timingMs` est **signé** (int16) :
- Valeur négative = joué **trop tôt**
- Valeur positive = joué **trop tard**
- Plage : -32768 à +32767 ms

### 5. Fréquence d'envoi

- **GAME_NOTE_HIT (0x10)** : À chaque note (peut être ~10-50 notes/seconde pour morceaux rapides)
- **GAME_SCORE_UPDATE (0x11)** : 1× par seconde
- **GAME_LEADERBOARD (0x12)** : Reçu toutes les 2 secondes

---

## 📚 Ressources

- **Architecture générale** : `docs/MIDI_WEBSOCKET_API.md`
- **Mode Jeu specs** : `docs/GAME_MODE.md`
- **pdjson patch** : `Documents/Pd/externals/pdjson/pdjson.pd_lua`

---

**Dernière mise à jour** : 13 Octobre 2025  
**Status** : ✅ Protocole binaire complet (92% économie vs JSON)

