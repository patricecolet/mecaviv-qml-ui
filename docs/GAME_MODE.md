# Mode Jeu "Siren Hero" - Spécifications

## 🎮 Concept

Un jeu de type **Guitar Hero/Rock Band** adapté aux sirènes mécaniques, où le joueur doit synchroniser ses contrôleurs (volant, joystick, faders) avec la séquence MIDI qui défile à l'écran.

**Particularité** : Transforme l'apprentissage du contrôle des sirènes en expérience ludique et pédagogique.

---

## 🏗️ Architecture du Jeu

```
┌──────────────────────────────────────────────────────┐
│              PureData (Serveur de Jeu)               │
├──────────────────────────────────────────────────────┤
│  1. Lit fichier MIDI (séquence à jouer)              │
│  2. Envoie la séquence AVEC AVANCE à l'interface     │
│  3. Reçoit les contrôleurs en temps réel du joueur   │
│  4. Compare contrôleurs vs séquence attendue         │
│  5. Calcule le score (timing + précision)            │
│  6. Envoie feedback visuel/audio                     │
└────────────┬─────────────────────────────────────────┘
             │
             │ WebSocket (bidirectionnel)
             ▼
┌──────────────────────────────────────────────────────┐
│         SirenePupitre (Interface Jeu)                │
├──────────────────────────────────────────────────────┤
│  • Affiche la séquence qui défile (notes futures)    │
│  • Curseur "NOW" indique le moment à jouer           │
│  • Indicateurs de contrôleurs (position joueur)      │
│  • Feedback visuel (bon/raté/parfait)                │
│  • Score en temps réel                               │
│  • Combo counter                                     │
└──────────────────────────────────────────────────────┘
```

---

## 🎨 Interface Visuelle - "Partition Animée"

### Concept Clé : Ligne Mélodique Continue

**Une seule ligne qui serpente** sur la portée musicale fixe, encodant visuellement tous les contrôleurs requis.

```
┌──────────────────────────────────────────────────────────────┐
│                    Animation Layer (défilant)                 │
│                                                               │
│                      Ligne mélodique continue qui serpente : │
│                 ┌──────────────────────────────────┐         │
│                 │ Do#∿∿∿∿∿∿∿∿━━━━━━┄┄┄┄─────      │         │
│          Si━━━━━┘                              La  │         │
│         /                                           │         │
│        /                                            │         │
│  ═════════════════════════════════════════▌═════════════════ │
│  ────────────────────────────────────────▌──────────────────  │
│  ═════════════════════════════════════════▌═════════════════ │ <- Portée fixe
│  ────────────────────────────────────────▌──────────────────  │    (ambitus)
│  ═════════════════════════════════════════▌═════════════════ │
│                                           ▲                   │
│                                      Curseur NOW              │
│                                                               │
│  [Contrôleurs actuels joueur]                                │
│  Volant: 45° | Fader: 64 | Vibrato: ON                      │
└──────────────────────────────────────────────────────────────┘

Légende :
━━━━━  Ligne épaisse     = Volume fort (fader haut)
─────  Ligne fine        = Volume faible (fader bas)
∿∿∿∿∿  Ondulation        = Vibrato actif (pédale modulation)
┄┄┄┄┄  Segments          = Tremolo actif (pad)
```

### Encodage Visuel Complet

**Volume (fader)** :
- `─────────` Fin (< 30) → Baisser le fader
- `━━━━━━━━━` Moyen (30-90) → Position moyenne
- `████████` Épais (> 90) → Monter le fader au max

**Vibrato (modulation)** :
- `━━━━━━━━━` Droit (OFF) → Pas de modulation
- `∿∿∿∿∿∿∿∿∿` Ondulé (ON) → Activer pédale de modulation

**Tremolo (amplitude)** :
- `━━━━━━━━━` Continu (OFF) → Mouvement fluide
- `┄┄┄┄┄┄┄┄┄` Pointillé (ON) → Mouvement saccadé

**Position du volant (hauteur de la ligne)** :
- Ligne haute → Tourner volant vers le haut
- Ligne centre → Position neutre
- Ligne basse → Tourner volant vers le bas

**Combinaisons** :
- `████∿∿∿∿∿` Volume fort + vibrato
- `━━┄┄━━┄┄━` Moyen + tremolo
- `████∿∿┄┄∿` Maximum expressif

### Effet Tunnel 3D (Optionnel)

```
                    (Loin - futur, Z=-1500)
                         ↓
                    ∿∿∿∿∿∿∿━━━━━━━━─────
                   /                     Fine, transparente
                  /                      
                 /                       
          ━━━━━━         (Z=-500)       Ligne moyenne
         /
        /
  ∿∿∿∿∿∿              (Z=-200)         Ligne proche, épaisse
     /
    /
─────                 (Z=-50)           Dernière section
     ▼                              
═════▌═════════════════════            Curseur NOW (Z=0)
─────▌─────────────────────            
═════▌═════════════════════         
     ▲
   Portée fixe (fond)
```

**Avantages 3D** :
- Vision "tunnel" dans le futur
- Loin = petit et transparent
- Proche = grand et brillant
- Anticipation naturelle

---

## 📊 Système de Scoring

### Calcul de Précision

Pour chaque événement, comparaison entre valeurs attendues et valeurs jouées :

```javascript
expectedPosition = 45°
playerPosition = 43°
tolerance = 10°

difference = abs(expectedPosition - playerPosition)  // 2°
accuracy = 1 - (difference / tolerance)              // 0.8 = 80%

if (accuracy >= 0.95) result = "perfect"  // x3 points
else if (accuracy >= 0.80) result = "good"  // x2 points
else if (accuracy >= 0.50) result = "ok"    // x1 points
else result = "miss"                         // x0 points
```

### Niveaux de Réussite

| Résultat | Précision | Multiplicateur | Couleur |
|----------|-----------|----------------|---------|
| **Perfect** | ≥ 95% | x3 | Or (#FFD700) |
| **Good** | ≥ 80% | x2 | Vert (#00FF00) |
| **Ok** | ≥ 50% | x1 | Jaune (#FFFF00) |
| **Miss** | < 50% | x0 | Rouge (#FF0000) |

### Système de Combo

- **Combo** : Événements consécutifs réussis (≥ "ok")
- **Multiplicateur** : x1 → x2 (5 combo) → x3 (10 combo) → x4 (20 combo)
- **Reset** : Un "miss" remet à 0

```javascript
finalScore = baseScore × resultMultiplier × comboMultiplier

// Exemple : baseScore=100, perfect (x3), combo=15 (x4)
// → 100 × 3 × 4 = 1200 points
```

---

## 📡 Messages WebSocket

### Démarrage du Jeu

```json
{
    "type": "GAME_START",
    "midiFile": "louette/AnxioGapT.midi",
    "difficulty": "normal",
    "lookahead": 3000,
    "mode": "practice",
    "tempo": 120,
    "syncMode": "autonomous",
    "playerSiren": "S3"
}
```

### Envoi de la Séquence (PureData → Interface)

```json
{
    "type": "GAME_SEQUENCE",
    "lookahead": 3000,
    "events": [
        {
            "timestamp": 1500,
            "note": 69.5,
            "velocity": 100,
            "controllers": {
                "wheel": { "position": 45, "tolerance": 10 },
                "joystick": { "x": 0.5, "y": -0.3, "tolerance": 0.1 },
                "fader": { "value": 64, "tolerance": 10 },
                "gearShift": { "position": 2 }
            }
        }
    ]
}
```

### Contrôleurs du Joueur (Interface → PureData)

```json
{
    "type": "PLAYER_INPUT",
    "timestamp": 1500,
    "controllers": {
        "wheel": { "position": 43, "velocity": 5.0 },
        "joystick": { "x": 0.48, "y": -0.32, "z": 0, "button": false },
        "fader": { "value": 66 },
        "gearShift": { "position": 2 }
    }
}
```

### Scoring (PureData → Interface)

```json
{
    "type": "GAME_SCORE",
    "event_id": 123,
    "result": "perfect",
    "score": 1000,
    "total_score": 25000,
    "combo": 15,
    "accuracy": {
        "wheel": 0.95,
        "joystick": 0.88,
        "fader": 0.82,
        "gearShift": 1.0
    }
}
```

### Fin du Jeu

```json
{
    "type": "GAME_END",
    "total_score": 125000,
    "accuracy": 0.87,
    "perfect_count": 45,
    "good_count": 23,
    "ok_count": 12,
    "miss_count": 8,
    "max_combo": 32,
    "rank": "A"
}
```

---

## 🎯 Modes de Jeu

### Practice Mode (Entraînement Autonome)

- **SirenePupitre** contrôle autonome du tempo
- Tempo ajustable : 50%, 75%, 100%, 125%
- Pas de pénalité pour erreurs
- Répétition de sections (loop)
- **Mode casque** : ComposeSiren joue les 7 sirènes en accompagnement
- Pas de MIDI Clock externe

### Performance Mode (Concert Synchronisé)

- **SirenConsole** = Master (MIDI Clock)
- **SirenePupitre** = Slave (synchronisé)
- Tempo imposé
- Score complet avec combo
- Classement final
- Synchronisation multi-pupitres

### Challenge Mode (Compétition)

- Difficulté croissante
- Time limit
- Objectifs spécifiques
- Déblocage de compositions

---

## 📊 Niveaux de Difficulté

| Difficulté | Tolérance | Lookahead | Contrôleurs |
|------------|-----------|-----------|-------------|
| **Easy** | ±30% | 5s | Volant uniquement |
| **Normal** | ±20% | 3s | Volant + 1 autre |
| **Hard** | ±10% | 2s | 3+ contrôleurs |
| **Expert** | ±5% | 1s | Tous les contrôleurs |

---

## 🎨 Composants QML

### À Créer

```
QML/game/
├── GameController.qml         # Logique et synchronisation
├── GameMode.qml               # Vue principale
├── MelodicLine3D.qml          # Ligne continue (serpente)
├── LineSegment3D.qml          # Segment avec encodage visuel
├── GameCursor3D.qml           # Curseur "NOW"
├── ScoreFeedback3D.qml        # Feedback visuel
├── ParticleEffect3D.qml       # Particules "perfect"
├── ComboDisplay.qml           # Combo + multiplicateur
├── GameHUD.qml                # Score + stats
└── ControllerTargetBar.qml    # Barres comparatives
```

### Composants Réutilisés

- ✅ `MusicalStaff3D` - Portée de fond
- ✅ `NoteCursor3D` - Base pour curseur jeu
- ✅ `LEDText3D` - Affichage score
- ✅ `NumberDisplay3D` - Stats temps réel
- ✅ Indicateurs de contrôleurs existants

---

## 💾 Statistiques et Progression

### Sauvegarde Locale

```json
{
    "player": "User1",
    "stats": {
        "total_score": 1250000,
        "songs_played": 15,
        "perfect_ratio": 0.45,
        "best_combo": 87,
        "favorite_song": "AnxioGapT",
        "difficulty_unlocked": "hard"
    },
    "song_records": {
        "louette/AnxioGapT.midi": {
            "best_score": 125000,
            "best_accuracy": 0.92,
            "rank": "A",
            "attempts": 12,
            "completed": true
        }
    }
}
```

### Système de Rangs

- **S** : 95%+ précision
- **A** : 85-94%
- **B** : 75-84%
- **C** : 65-74%
- **D** : < 65%

---

## 🎯 Anticipation du Mouvement

### Partition Gestuelle

La ligne qui arrive permet de **préparer les gestes** :

```
Exemple : Do → Mi → Sol (crescendo + vibrato)

        ████∿∿∿∿∿∿∿∿∿∿  Sol (haut, épais, ondulé)
       /
      /  ━━━━━━━━━━━━━  Mi (moyen)
     /
    /
   ───────────────────  Do (bas, fin)
```

**Lecture visuelle** :
- Ligne monte → Préparer rotation volant vers le haut
- S'épaissit → Monter le fader progressivement
- Ondule → Activer pédale de vibrato
- Ligne continue = Mélodie monophonique fluide

### Timeline de Préparation

```
T-3s : "Ligne épaisse arrive, préparer fader"
T-2s : "Position moyenne, transition"
T-1s : "Volume fort + vibrato, fader haut + pédale"
T-0s : Exécution au curseur NOW
```

---

## 🎵 Lookahead Adaptatif

Le temps d'avance s'ajuste automatiquement selon :

### 1. Tempo (BPM)

```javascript
function calculateLookahead(bpm, difficulty) {
    var baseBeats = 8  // 8 temps en avance (normal)
    
    switch(difficulty) {
        case "easy": baseBeats = 12; break
        case "normal": baseBeats = 8; break
        case "hard": baseBeats = 6; break
        case "expert": baseBeats = 4; break
    }
    
    return baseBeats * (60 / bpm) * 1000  // En ms
}

// BPM 60 (lent), normal  → 8s lookahead
// BPM 120 (moyen), normal → 4s lookahead  
// BPM 180 (rapide), normal → 2.7s lookahead
```

### 2. Densité de Notes

```javascript
var noteDensity = countNotesInWindow(lookahead)

if (noteDensity > 15) lookahead *= 0.8  // Réduire si trop chargé
else if (noteDensity < 5) lookahead *= 1.2  // Augmenter si peu de notes
```

### 3. Complexité des Contrôleurs

```javascript
var activeControllers = countActiveControllers(event)

if (activeControllers >= 4) lookahead *= 1.3  // +30% de temps
```

---

## 🎬 Feedback Visuel

### Quand la Ligne Atteint le Curseur

**Perfect (≥95%)** :
- Ligne devient OR (#FFD700)
- Explosion de particules dorées
- Flash lumineux
- Son "ding!"

**Good (≥80%)** :
- Ligne devient VERT (#00FF00)
- Flash vert
- Son "tick"

**Ok (≥50%)** :
- Ligne devient JAUNE (#FFFF00)
- Son neutre

**Miss (<50%)** :
- Ligne devient ROUGE (#FF0000)
- Shake écran
- Ligne se brise
- Combo reset

---

## 📱 HUD (Head-Up Display)

```
┌─────────────────────────────────────────────────┐
│ SCORE: 125,000    COMBO: x15  [████████░░] 87% │ <- Haut
│                                                 │
│  [Animation ligne mélodique au centre]          │
│                                                 │
│ Volant: 45° ━━━━━━━━━━━━━━━━━━━━━░░░ Target: 50│ <- Bas
│ Fader:  64  ━━━━━━━━━━━░░░░░░░░░░░░  Target: 70│
└─────────────────────────────────────────────────┘
```

- **Haut gauche** : Score (LED 3D)
- **Haut droite** : Combo + précision
- **Bas** : Contrôleurs actuels vs cibles

---

## 🎮 Apprentissage Gestuel

### Patterns Reconnaissables

**1. Crescendo** :
```
─── ━━━ ███ ███████  → Montée progressive du fader
```

**2. Montée mélodique** :
```
     ○─────
    /        → Rotation volant vers le haut
   /
  /
 ○─────
```

**3. Vibrato alterné** :
```
━━━━━ ∿∿∿∿∿ ━━━━━ ∿∿∿∿∿  → Pédale ON/OFF rythmée
```

### Dimension Pédagogique

- Lecture anticipée des gestes
- Patterns visuels → réflexes musicaux  
- Contrôle technique → expression artistique
- Apprentissage ludique et naturel

---

## 🚀 Cas d'Usage

### 1. Entraînement Casque (Mode Practice)

- SirenePupitre lance composition complète
- Joueur contrôle 1 sirène (ex: S3)
- ComposeSiren joue les 7 sirènes :
  - S3 = joueur (temps réel)
  - S1,S2,S4,S5,S6,S7 = accompagnement (séquence)
- Écoute au casque
- Moteurs au repos (sécurité)

### 2. Concert Synchronisé (Mode Performance)

- SirenConsole = Master (MIDI Clock)
- 7 SirenePupitre synchronisés
- Chaque instrumentiste joue sa sirène
- Score et classement en fin de concert
- Sirènes physiques jouent réellement

### 3. Challenge Solo

- Objectifs spécifiques (score, combo, précision)
- Déblocage progressif de compositions
- Système de rangs (S/A/B/C/D)

---

## 🔧 Implémentation Technique

### Animation de Défilement

Position calculée selon le temps :
```qml
property real timeUntilPlay: targetTime - currentTime
z: -timeUntilPlay * 0.5  // Profondeur 3D
```

### Encodage de la Ligne

Propriétés dynamiques :
```qml
lineWidth: Math.max(2, (volume / 127) * 10)  // Épaisseur
waveform: vibrato ? "wavy" : "straight"       // Ondulation
segmented: tremolo                            // Segments
opacity: Math.max(0.4, 1 - (abs(z) / 2000))  // Fade distance
```

### Synchronisation

Timer 60 FPS :
```qml
Timer {
    interval: 16  // ~60 FPS
    running: gameActive
    onTriggered: {
        currentGameTime = Date.now() - gameStartTime
        updateLinePositions(currentGameTime)
        checkEventsAtCursor(currentGameTime)
    }
}
```

### Fenêtre de Timing

```javascript
var timingWindow = 200  // ±200ms

if (abs(event.timestamp - currentGameTime) <= timingWindow) {
    var score = checkEventAccuracy(event, currentControllers)
    sendScoreToPlayer(score)
}
```

---

## 📚 Références

- [COMPOSESIREN_ARCHITECTURE.md](./COMPOSESIREN_ARCHITECTURE.md) - Architecture générale
- [SirenePupitre README](../SirenePupitre/README.md) - Application de visualisation
- [COMMUNICATION.md](./COMMUNICATION.md) - Protocoles WebSocket

---

**Document de conception - Mode Jeu "Siren Hero"**  
**Dernière mise à jour** : Octobre 2025

