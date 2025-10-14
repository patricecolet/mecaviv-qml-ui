# Exemples de Messages Binaires PureData - Mode Jeu

## 📤 Messages à ENVOYER depuis PureData

### Format pour [pdjson]

Tous les messages doivent être précédés de `send` pour être envoyés via WebSocket :

```
send [byte0] [byte1] [byte2] ...
```

---

## 0x10 - GAME_NOTE_HIT (9 bytes)

### Exemple 1 : Hit Parfait (Perfect)

```
send 16 3 60 64 67 23 0 2 25
```

**Détails** :
- `16` = 0x10 (messageType)
- `3` = Pupitre ID 3
- `60` = Note MIDI C4
- `64` = Contrôleur attendu : 64
- `67` = Contrôleur joué : 67
- `23 0` = Timing +23ms (int16 little-endian : 23 = 0x0017 → bytes [17 00])
- `2` = Rating : Perfect
- `25` = Score gagné : 25 × 10 = 250 points

### Exemple 2 : Hit Bon (Good)

```
send 16 5 72 80 75 240 255 1 15
```

**Détails** :
- Pupitre 5
- Note 72 (C5)
- Attendu 80, joué 75
- Timing -16ms (int16 : -16 = 0xFFF0 → bytes [F0 FF] → décimal [240 255])
- Rating : Good (1)
- Score : 150 points (15 × 10)

### Exemple 3 : Miss

```
send 16 2 69 100 120 50 0 0 0
```

**Détails** :
- Pupitre 2
- Note 69 (A4)
- Attendu 100, joué 120 (écart trop grand)
- Timing +50ms
- Rating : Miss (0)
- Score : 0 points

---

## 0x11 - GAME_SCORE_UPDATE (14 bytes)

### Exemple 1 : Début de partie

```
send 17 3 100 0 0 0 5 0 5 0 80 3 2 0
```

**Détails** :
- `17` = 0x11 (messageType)
- `3` = Pupitre ID 3
- `100 0 0 0` = Score 100 (uint32 little-endian)
- `5 0` = Combo actuel : 5 (uint16)
- `5 0` = Max combo : 5 (uint16)
- `80` = Accuracy : 80%
- `3` = Perfect : 3
- `2` = Good : 2
- `0` = Miss : 0

### Exemple 2 : Milieu de partie (score élevé)

```
send 17 5 162 48 0 0 42 0 73 0 89 45 23 8
```

**Détails** :
- Pupitre 5
- Score 12450 (0x30A2 → little-endian [A2 30 00 00] → décimal [162 48 0 0])
- Combo : 42
- Max combo : 73
- Accuracy : 89%
- Perfect : 45
- Good : 23
- Miss : 8

**Calcul score 12450 en bytes** :
```
12450 en hex = 0x30A2
Little-endian : A2 30 00 00
Décimal : 162 48 0 0
```

### Exemple 3 : Score très élevé (> 65535)

```
send 17 1 66 4 1 0 89 0 89 0 94 67 18 2
```

**Détails** :
- Pupitre 1
- Score 66626 (0x01 04 42 → little-endian [42 04 01 00] → décimal [66 4 1 0])
- Combo : 89
- Max combo : 89
- Accuracy : 94%
- Perfect : 67
- Good : 18
- Miss : 2

---

## 📥 Messages à RECEVOIR dans PureData

### 0x12 - GAME_LEADERBOARD

**Exemple : 3 joueurs**

```
Reçu : 18 1 5 120 55 0 0 89 0 94 2 3 162 48 0 0 73 0 89 3 1 16 39 0 0 60 0 82
```

**Parsing** :
- `18` = 0x12 (messageType)

**Joueur 1 (rang 1)** :
- `1` = Rang 1
- `5` = Pupitre 5
- `120 55 0 0` = Score 14200 (0x3778 LE → [78 37 00 00] → [120 55 0 0])
- `89 0` = Combo 89
- `94` = Accuracy 94%

**Joueur 2 (rang 2)** :
- `2` = Rang 2
- `3` = Pupitre 3
- `162 48 0 0` = Score 12450
- `73 0` = Combo 73
- `89` = Accuracy 89%

**Joueur 3 (rang 3)** :
- `3` = Rang 3
- `1` = Pupitre 1
- `16 39 0 0` = Score 10000 (0x2710 LE → [10 27 00 00] → [16 39 0 0])
- `60 0` = Combo 60
- `82` = Accuracy 82%

---

## 🧮 Calculs Utiles pour PureData

### 1. Convertir score (uint32) en 4 bytes little-endian

```
# Dans PureData, pour score = 12450 :

[expr $f1 & 255]          # Byte 0 : 162
[expr ($f1 >> 8) & 255]   # Byte 1 : 48
[expr ($f1 >> 16) & 255]  # Byte 2 : 0
[expr ($f1 >> 24) & 255]  # Byte 3 : 0
```

### 2. Convertir combo (uint16) en 2 bytes little-endian

```
# Pour combo = 73 :

[expr $f1 & 255]          # Byte 0 : 73
[expr ($f1 >> 8) & 255]   # Byte 1 : 0
```

### 3. Convertir timing (int16 signé) en 2 bytes

**Timing positif (+23ms)** :
```
23 en hex = 0x0017
Little-endian : 17 00
Décimal : 23 0
```

**Timing négatif (-16ms)** :
```
-16 en hex = 0xFFF0 (complément à 2)
Little-endian : F0 FF
Décimal : 240 255
```

Dans PureData :
```
# Pour timing positif (0-32767) :
[expr $f1 & 255]          # Byte 0
[expr ($f1 >> 8) & 255]   # Byte 1

# Pour timing négatif, il faut convertir en complément à 2
# PureData : utiliser [expr ($f1 + 65536) & 255] pour byte 0
```

### 4. Calculer accuracy (0-100%)

```
# perfect = 45, good = 23, miss = 8
# totalHits = 45 + 23 + 8 = 76

accuracy = ((perfect * 100 + good * 80) / (totalHits * 100)) * 100
         = ((45 * 100 + 23 * 80) / (76 * 100)) * 100
         = ((4500 + 1840) / 7600) * 100
         = (6340 / 7600) * 100
         = 0.834 * 100
         = 83.4 → arrondi à 83%
```

Dans PureData :
```
[expr (($f1 * 100 + $f2 * 80) / (($f1 + $f2 + $f3) * 100)) * 100]
|
[int]  # Arrondir à l'entier
```

### 5. Calculer rating

```
difference = abs(expectedValue - actualValue)
tolerance = 10  # Ou autre selon difficulté

accuracy = 1 - (difference / tolerance)

if accuracy >= 0.95:   rating = 2  # perfect
elif accuracy >= 0.80: rating = 1  # good
elif accuracy >= 0.50: rating = 0  # ok
else:                  rating = 0  # miss (mais combo reset)
```

Dans PureData :
```
[expr abs($f1 - $f2)]  # difference
|
[expr 1 - ($f1 / 10)]  # accuracy (tolerance = 10)
|
[select 0.95 0.80 0.50]
|  |     |    |
|  |     |    [0(  # ok
|  |     [1(      # good
|  [2(            # perfect
```

---

## 📝 Template de Patch PureData

### Envoyer GAME_NOTE_HIT

```
[r note_played]  # Reçoit note, expected, actual, timing, rating, score
|
[unpack f f f f f f f]
|   |   |   |   |   |   |
|   |   |   |   |   |   [expr $f1 / 10]  # scoreGained / 10
|   |   |   |   |   [f]  # rating
|   |   |   |   [expr $f1 & 255]  # timing byte 0
|   |   |   |   [expr ($f1 >> 8) & 255]  # timing byte 1
|   |   |   [f]  # actualValue
|   |   [f]  # expectedValue
|   [f]  # noteNumber
[16]  # messageType
|
[pack f f f f f f f f f]
|
# Ajouter pupitreId
[pack f f f f f f f f f f]
|
[list prepend send]
|
[list trim]
|
[pdjson]  # Envoie via WebSocket
```

### Envoyer GAME_SCORE_UPDATE (toutes les secondes)

```
[metro 1000]  # Toutes les secondes
|
[bang]
|
[17 $1 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 $13(
#    |  |  |  |  |  |  |  |  |   |   |   |   |
#    |  score (4 bytes)  combo   max accuracy perfect good miss
#    pupitreId           (2 bytes) (2 bytes)
|
[list prepend send]
|
[pdjson]
```

---

## 🎯 Exemples de Scénarios Complets

### Scénario 1 : Note Parfaite → Update Score

**1. Note jouée parfaitement** :
```
send 16 3 60 64 64 0 0 2 30
     ^  ^ ^  ^  ^  ^    ^ ^
     |  | |  |  |  |    | score (300 pts)
     |  | |  |  |  timing (0ms)
     |  | |  |  actualValue (64)
     |  | |  expectedValue (64)
     |  | noteNumber (60 = C4)
     |  pupitreId (3)
     messageType (0x10)
```

**2. Update score immédiat** :
```
send 17 3 44 1 0 0 1 0 1 0 100 1 0 0
     ^  ^ score=300  ^    ^    ^   ^ ^ ^
     |  |            combo max  acc perf good miss
     |  pupitreId    =1    =1   100% 1   0    0
     messageType (0x11)
```

### Scénario 2 : Combo de 10

**Après 10 notes parfaites** :
```
send 17 5 208 11 0 0 10 0 10 0 100 10 0 0
        ^ score=3024  ^    ^    ^   ^  ^ ^
        |             combo max  acc  perf good miss
        Pupitre 5     =10  =10  100% 10  0    0
```

**Score calculation** :
```
Note 1:  100 × 3 × 1 = 300  (combo 1,  mult ×1)
Note 2:  100 × 3 × 1 = 300  (combo 2,  mult ×1)
Note 3:  100 × 3 × 1 = 300  (combo 3,  mult ×1)
Note 4:  100 × 3 × 1 = 300  (combo 4,  mult ×1)
Note 5:  100 × 3 × 2 = 600  (combo 5,  mult ×2)
Note 6:  100 × 3 × 2 = 600  (combo 6,  mult ×2)
Note 7:  100 × 3 × 2 = 600  (combo 7,  mult ×2)
Note 8:  100 × 3 × 2 = 600  (combo 8,  mult ×2)
Note 9:  100 × 3 × 2 = 600  (combo 9,  mult ×2)
Note 10: 100 × 3 × 2 = 600  (combo 10, mult ×2)
Total: 4200 points
```

---

**Dernière mise à jour** : 13 Octobre 2025  
**Usage** : Copier/coller les exemples directement dans PureData

