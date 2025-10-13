# ComposeSiren - Architecture et Flux MIDI

## 🎯 Vue d'ensemble

**ComposeSiren** est un VST/AU développé en JUCE qui permet de contrôler les sirènes mécaniques. Ce document analyse l'architecture, les flux MIDI et l'intégration avec le reste du système.

## 📍 Localisation

```
/Users/patricecolet/repo/mecaviv/ComposeSiren/
├── Source/              # Code source JUCE
├── Builds/              # Projets de build (Xcode, Visual Studio, etc.)
├── Releases/            # Installeurs et binaires
├── Dependencies/        # JUCE framework
└── README.md
```

**Installeurs disponibles** : Permet de lancer ComposeSiren depuis la console (SirenConsole).

---

## 🎵 Flux MIDI - Architecture Globale

### Schéma des flux

```
┌─────────────────────────────────────────────────────────────────┐
│                         Sources                                  │
├─────────────────────────────────────────────────────────────────┤
│  • Fichiers MIDI (compositions) - via external PureData         │
│  • MCU Contrôleurs (UDP, IP fixe) - volant, joystick, pédales  │
│  • SirenConsole - Contrôle GUI (WebSocket)                      │
│  • Séquenceur MIDI externe (optionnel)                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ MIDI + UDP
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                        PureData                                  │
│         Hub Central + Lecteur MIDI + Gestionnaire UDP            │
├─────────────────────────────────────────────────────────────────┤
│  • Lit fichiers MIDI (via [midifile])                           │
│  • Reçoit contrôleurs du MCU (UDP, IP fixe)                     │
│  • Reçoit commandes WebSocket (Console/Pupitre)                 │
│  • Route selon la destination (canaux 1-7 ou 8-14)             │
│  • Applique transformations et courbes                          │
│  • Combine Note On + Pitch Bend → Note fractionnelle           │
│  • Convertit contrôleurs UDP → MIDI CC                          │
└──┬────────┬─────────────────────┬───────────────────────────────┘
   │        │                     │
   │ UDP    │ MIDI Out            │ WebSocket (binaire)
   │ ou     │ (ALSA)              │ Note + Controllers
   │ MIDI   │                     │ (monitoring)
   │        │                     │
   ▼        ▼                     ▼
┌─────────────────────┐  ┌─────────────────────────────────┐
│   ComposeSiren      │  │    Interfaces de Monitoring     │
│   (Standalone)      │  │                                 │
├─────────────────────┤  ├─────────────────────────────────┤
│ Connexion JUCE:     │  │ • SirenePupitre (×7)            │
│ • Sélection PD      │  │   - Portée musicale 3D          │
│ • aconnect auto     │  │   - Hz/RPM en temps réel        │
│ • Reçoit MIDI       │  │   - Afficheurs LED 3D           │
│ • Génère audio 7ch  │  │   - État contrôleurs (3D)       │
│ • Interface GUI     │  │   - Mode JEU (Siren Hero)       │
│   (ou headless)     │  │   - Entraînement casque         │
│                     │  │                                 │
│ Canaux MIDI:        │  │ • SirenConsole                  │
│ • 1-7: S1-S7 physi  │  │   - Vue d'ensemble 7 pupitres   │
│ • 8-14: S1-S7 virt  │  │   - Configuration centralisée   │
│                     │  │   - Gestion presets             │
│ Mix Parameters:     │  │   - API REST /api/midi/files    │
│ • CC70: Volume/ch   │  │   - Lancement ComposeSiren      │
│ • CC10: Pan/ch      │  │   - Config reverb globale       │
└─────────┬───────────┘  └───────────────┬─────────────────┘
          │                              │
          │ Audio 7ch                    │ Display + Control
          ▼                              ▼
┌─────────────────────┐        ┌────────────────────┐
│  Sortie Audio       │        │  Visualisation +   │
│  (casque/enceintes) │        │  Contrôle Jeu      │
│  7 sirènes mixées   │        │                    │
└─────────────────────┘        └────────────────────┘

                               ┌────────────────────┐
                               │ Sirènes Physiques  │
                               │ (×7 instruments)   │
                               │                    │
                               │ Contrôlées par     │
                               │ PureData UNIQUEMENT│
                               │ (UDP/MIDI Port 1)  │
                               └────────────────────┘
```

**Légende** :
- **UDP** : Communication directe PureData → Sirènes physiques (contrôle moteurs)
- **MIDI Out (ALSA)** : PureData → ComposeSiren (génération audio)
- **WebSocket binaire** : PureData → Interfaces (monitoring temps réel)

---

## 📡 Messages WebSocket - Contrôle de Lecture MIDI

### Messages à implémenter pour SirenConsole → PureData

**Chargement d'un fichier** :
```json
{
    "type": "MIDI_FILE_LOAD",
    "path": "louette/AnxioGapT.midi"
}
```

**Contrôle de lecture** :
```json
{
    "type": "MIDI_TRANSPORT",
    "action": "play",    // "play", "stop", "pause"
    "tempo": 120,        // BPM (optionnel)
    "source": "console"  // "console" ou "pupitre"
}
```

**Positionnement dans le fichier** :
```json
{
    "type": "MIDI_SEEK",
    "position": 0        // Position en ms ou en beats
}
```

**MIDI Clock (synchronisation)** :
```json
{
    "type": "MIDI_CLOCK",
    "tempo": 120,        // BPM
    "beat": 42,          // Beat actuel
    "source": "console"  // Master clock
}
```

**Gestion du tempo** :
```json
{
    "type": "TEMPO_CHANGE",
    "tempo": 140,        // Nouveau BPM
    "smooth": true       // Transition progressive
}
```

**Demande de liste des fichiers** :
```json
{
    "type": "MIDI_FILES_REQUEST"
}
```

**Réponse de PureData** :
```json
{
    "type": "MIDI_FILES_LIST",
    "files": [
        {
            "path": "louette/AnxioGapT.midi",
            "name": "AnxioGapT",
            "category": "louette"
        },
        ...
    ]
}
```

---

## 🎮 MCU Contrôleurs - Communication UDP

### Architecture Contrôleurs Physiques

```
┌─────────────────────────────────────────┐
│      MCU (Microcontrôleur)              │
│      IP Fixe (ex: 192.168.1.50)         │
├─────────────────────────────────────────┤
│  • Volant (encoder rotatif)             │
│  • Joystick (3 axes + bouton)           │
│  • Faders (linéaires)                   │
│  • Pédales (modulation, expression)     │
│  • Pads (vélocité + aftertouch)         │
│  • Levier de vitesse (4 positions)      │
└────────────┬────────────────────────────┘
             │
             │ UDP packets (IP fixe)
             ▼
┌─────────────────────────────────────────┐
│         PureData (Serveur UDP)          │
│         Port UDP: 8005 (exemple)        │
├─────────────────────────────────────────┤
│  • Reçoit packets UDP                   │
│  • Parse données contrôleurs            │
│  • Applique courbes (linear/parabolic)  │
│  • Convertit → MIDI CC                  │
│  • Convertit → WebSocket (monitoring)   │
└───┬─────────────────┬───────────────────┘
    │                 │
    │ MIDI CC         │ WebSocket
    ▼                 ▼
ComposeSiren    Interfaces (visualisation)
```

### Format des Packets UDP (À documenter)

**Structure probable** (à confirmer avec le code PureData) :
```
Packet UDP depuis MCU:
[header, controller_id, value_msb, value_lsb, checksum]

Exemples :
• Volant : [0x01, 0x00, position_h, position_l, crc]
• Joystick : [0x02, axis_id, value_h, value_l, crc]
• Fader : [0x03, fader_id, value, 0x00, crc]
```

**À documenter** :
- [ ] Format exact des packets UDP
- [ ] IP fixe du MCU (configuration réseau)
- [ ] Fréquence d'envoi (combien de paquets/seconde ?)
- [ ] Gestion de la latence et du buffering
- [ ] Reconnexion automatique si perte de connexion

---

## 📊 Types de Messages MIDI

### 1. **Notes MIDI** (Hauteur + Micro-tonalité)

**Source** : Fichiers MIDI lus par PureData (via `[midifile]`)  
**Destination** : Sirènes via ComposeSiren + Interfaces (visualisation)

**Format binaire** (protocole WebSocket) :
```
[0x01, note, velocity, bend_lsb, bend_msb]
```

**Exemple** : Note 69.5 (La4 + 50 centièmes)
- Byte 0 : `0x01` (Type MIDI_NOTE)
- Byte 1 : `0x45` (Note 69)
- Byte 2 : `0x64` (Vélocité 100)
- Bytes 3-4 : Pitch Bend pour +0.5 demi-ton

**Traitement** :
- PureData → Combine Note On + Pitch Bend → Note fractionnelle
- PureData → Convertit en Hz/RPM → Envoie UDP aux sirènes physiques
- ComposeSiren → Reçoit MIDI → Synthèse audio FFT (pas de contrôle moteur)
- SirenePupitre → Reçoit WebSocket → Affiche sur portée musicale 3D

---

### 2. **Contrôleurs** (De l'UDP au MIDI CC)

**Source** : MCU via UDP (IP fixe) → PureData  
**Destination** : ComposeSiren (MIDI CC) + Interfaces (WebSocket) + Sirènes (UDP)

**Flux de données** :
```
MCU ──UDP──→ PureData ──┬──MIDI CC──→ ComposeSiren (audio)
                        ├──UDP──────→ Sirènes (hardware)
                        └──WebSocket→ Interfaces (monitoring)
```

**Format WebSocket binaire vers interfaces** (type 0x02) :
```
[0x02, wheel_pos, wheel_vel, joy_x, joy_y, joy_z, joy_btn, 
      gear_pos, gear_mode, fader, pedal, pad_vel, pad_after, pad_active]
```

**Format MIDI CC vers ComposeSiren** :
```
CC1  = Vibrato Amount (depuis pédale modulation)
CC7  = Volume (depuis fader)
CC9  = Vibrato Frequency (depuis pédale expression)
CC10 = Pan (depuis joystick X)
CC11 = Vibrato Attack (depuis joystick Y)
CC15 = Tremolo Frequency (depuis pad aftertouch)
CC92 = Tremolo Depth (depuis pad velocity)
Pitch Bend = Micro-tonalité (depuis volant)
```

### Contrôleurs MIDI Utilisés dans ComposeSiren

#### **Canaux 1-7 (Sirènes individuelles)**

| CC# | Nom | Usage | Valeurs | Effet |
|-----|-----|-------|---------|-------|
| **1** | Vibrato Amount | Profondeur du vibrato | 0-127 | Modulation de hauteur |
| **5** | Portamento | Glissando entre notes | 0-127 | Transition douce |
| **7** | Volume | Volume principal | 0-127 | Intensité sonore |
| **9** | Vibrato Frequency | Vitesse du vibrato | 0-127 | Fréquence 0-12.7 Hz |
| **10** | Pan | Panoramique stéréo | 0-127 | Gauche (-0.5) ↔ Droite (+0.5) |
| **11** | Vibrato Attack | Vitesse montée vibrato | 0-127 | Temps d'établissement |
| **15** | Tremolo Frequency | Vitesse du tremolo | 0-127 | Fréquence modulation amplitude |
| **70** | Master Volume | Volume indépendant mixage | 0-127 | Mixage final |
| **72** | Release Time | Temps de relâchement | 0-127 | Extinction de la note |
| **73** | Attack Time | Temps d'attaque | 0-127 | Montée de la note |
| **92** | Tremolo Depth | Profondeur du tremolo | 0-127 | Amplitude modulation |

**Pitch Bend** : Micro-tonalité (±2 demi-tons)

#### **Canal 16 (Contrôles globaux + Reverb)**

| CC# | Nom | Usage | Valeurs | Effet |
|-----|-----|-------|---------|-------|
| **64** | Reverb Enable | Activation reverb | 0-63=OFF, 64-127=ON | ON/OFF |
| **65** | Room Size | Taille de la pièce | 0-127 | Espace acoustique |
| **66** | Dry/Wet | Mélange dry/wet | 0-127 | Signal direct ↔ Reverb |
| **67** | Damp | Amortissement | 0-127 | Absorption hautes fréquences |
| **68** | Reverb HPF | Highpass filter | 0-127 | 20 Hz - 2 kHz |
| **69** | Reverb LPF | Lowpass filter | 0-127 | 2 kHz - 20 kHz |
| **70** | Reverb Width | Largeur stéréo | 0-127 | Mono ↔ Wide |
| **121** | Reset All | Reset toutes sirènes | 127 | Réinitialisation complète |

#### **Mapping PureData → ComposeSiren**

**MCU Contrôleurs (UDP) → PureData → MIDI CC** :

Le MCU envoie les données via **UDP (IP fixe)** à PureData qui les convertit en MIDI CC :

| Contrôleur MCU | UDP → PureData | MIDI CC | Paramètre ComposeSiren |
|----------------|----------------|---------|------------------------|
| Pédale Modulation | UDP packet | CC1 | Vibrato Amount |
| Pédale Expression | UDP packet | CC9 | Vibrato Frequency |
| Fader | UDP packet | CC7 | Volume |
| Joystick X | UDP packet | CC10 | Pan (stéréo) |
| Joystick Y | UDP packet | CC11 | Vibrato Attack |
| Pad Aftertouch | UDP packet | CC15 | Tremolo Frequency |
| Pad Velocity | UDP packet | CC92 | Tremolo Depth |
| Volant | UDP packet | Pitch Bend | Micro-tonalité |

**Architecture de contrôle** :
```
MCU (IP fixe) ──UDP──→ PureData ──MIDI CC──→ ComposeSiren
                          │
                          └──WebSocket──→ Interfaces (monitoring)
```

**Avantages** :
- ✅ MCU simple (pas de MIDI, juste UDP)
- ✅ IP fixe pour connexion fiable
- ✅ PureData centralise toutes les conversions
- ✅ Courbes appliquées dans PureData avant envoi MIDI

**Courbes applicables (PureData)** :
- Linear
- Parabolic
- Hyperbolic
- S-Curve
- Exponential

---

### 3. **Séquences MIDI** (fichiers .midi)

**Source** : Repository `mecaviv/compositions/`  
**Destination** : Reaper → PureData → ComposeSiren

**Organisation** :
```
mecaviv/compositions/
├── louette/Midi/      # 40+ compositions
├── patwave/Midi/      # 4 compositions
└── covers/            # Reprises
```

**Workflow simplifié** :
1. **SirenConsole** : Utilisateur sélectionne fichier MIDI (API `/api/midi/files`)
2. **SirenConsole** → **PureData** : Message WebSocket `MIDI_FILE_LOAD` avec chemin
3. **PureData** : External `[midifile]` charge le fichier (ex: `read louette/AnxioGapT.midi`)
4. **PureData** : Lecture démarrée via toggle, avancement via `[metro 40]`
5. **PureData** : Route MIDI selon canaux (1-7 = physiques, 8-14 = VST)
6. **PureData** → **Sorties multiples** (en parallèle) :
   - **→ Sirènes physiques** : UDP ou MIDI direct (contrôle moteurs)
   - **→ ComposeSiren** : MIDI via ALSA (génération audio)
   - **→ Interfaces** : WebSocket binaire (monitoring visuel)
7. **ComposeSiren** : Génère l'audio pour les canaux 1-14
8. **Sirènes physiques** : Reçoivent contrôle direct via UDP/MIDI (canaux 1-7)

**Avantages** :
- ✅ **Pas de DAW** (Reaper éliminé)
- ✅ **Workflow ultra-simplifié** : Console → PureData → Sirènes
- ✅ **Tout centralisé** dans PureData (hub unique)
- ✅ **Contrôle direct** depuis SirenConsole
- ✅ **Double sortie** : Audio (ComposeSiren) + Contrôle direct (UDP/MIDI)
- ✅ **Un seul point de configuration** (PureData)

---

## 🔀 Routage MIDI dans PureData

### Double sortie depuis PureData

PureData distribue les données MIDI vers **deux destinations** :

**1. Sirènes Physiques (S1-S7)** :
- **Protocole** : UDP ou MIDI série (selon configuration)
- **Port MIDI** : Port 1 de PureData (via `[midiout]` ou abstraction `sirenMidi2Udp`)
- **UDP** : Communication directe pour contrôle moteurs (préféré)
- **Canaux** : 1-7 (un canal par sirène, S1=canal 1, S2=canal 2, etc.)
- **Données** : Note, vélocité, bend, contrôleurs CC
- **Usage** : Contrôle direct des moteurs physiques
- **Note** : Mêmes canaux que ComposeSiren mais sur port différent

**2. ComposeSiren (VST/AU)** :
- **Protocole** : MIDI via ALSA (aconnect) ou CoreMIDI (macOS)
- **Port MIDI** : Port 2 de PureData → Entrée MIDI de ComposeSiren
- **Canaux** : 
  - 1-7 : Audio des sirènes physiques (mêmes canaux que le hardware)
  - 8-14 : Sirènes VST virtuelles (audio uniquement, pas de hardware)
- **Données** : MIDI standard (Note On/Off, Pitch Bend, CC1-92)
- **Usage** : Synthèse audio et rendu sonore
- **Note** : Reçoit les **mêmes données MIDI** que les sirènes physiques sur le Port 1

**3. Interfaces de Monitoring** :
- **Protocole** : WebSocket binaire
- **Port** : 10001 (configurable)
- **Données** : Note fractionnelle + états contrôleurs
- **Usage** : Visualisation temps réel (portées, LED, etc.)

### Configuration des canaux et ports MIDI

#### **Canaux MIDI (identiques sur tous les ports)**

```
Canal 1-7   → Sirènes S1-S7 individuelles
Canal 8-14  → Sirènes S1-S7 (VST virtuelles sans hardware)
Canal 15    → Contrôle global (harmonizer, effets)
Canal 16    → Métadonnées / sync / reverb
```

#### **Ports MIDI (destinations différentes depuis PureData)**

**Port MIDI 1 : Sirènes Physiques** :
- **Destination** : Hardware (UDP ou MIDI direct)
- **Canaux utilisés** : 1-7 uniquement
- **Protocole** : UDP (via abstraction `sirenMidi2Udp`) ou MIDI série
- **Données** : Note, vélocité, bend, contrôleurs → Contrôle moteurs
- **Latence** : Très faible (optimisée temps réel, pas de buffer)

**Port MIDI 2 : ComposeSiren (DSP Audio)** :
- **Destination** : Plugin VST/AU (via ALSA aconnect)
- **Canaux utilisés** : 1-14 (physiques + virtuelles)
- **Protocole** : MIDI standard (ALSA sur Linux, CoreMIDI sur macOS)
- **Données** : Note, vélocité, bend, CC1-92 → Synthèse audio
- **Latence** : < 10ms (acceptable pour audio)

**Port MIDI 3 : WebSocket vers Interfaces** :
- **Destination** : SirenePupitre, SirenConsole (monitoring + jeu)
- **Canaux** : 1-7 (sirènes actives)
- **Protocole** : WebSocket binaire (protocole custom)
- **Données** : Note fractionnelle + états contrôleurs
- **Latence** : Très faible (optimisée pour mode jeu, pas de buffer)

**Architecture de routage** :
```
PureData [midifile] lit composition.midi
   │
   ├─ Route canal 1-7  ──→ Port MIDI 1 ──→ Sirènes Physiques (UDP/MIDI)
   │                                       └─ S1-S7 moteurs
   │
   ├─ Route canal 1-14 ──→ Port MIDI 2 ──→ ComposeSiren (ALSA)
   │                                       ├─ Canaux 1-7: Audio physiques
   │                                       └─ Canaux 8-14: Audio virtuelles
   │
   └─ Route canal 1-7  ──→ WebSocket ───→ Interfaces (monitoring)
                                          └─ SirenePupitre (×7)
```

**Note importante** : Les **mêmes canaux MIDI (1-7)** sont envoyés sur **3 ports différents** en parallèle pour contrôler physique, audio et visualisation simultanément.

### Séparation Hardware / Audio

**PureData → Sirènes Physiques (Port MIDI 1)** :
- PureData gère **exclusivement** le contrôle hardware
- Protocole : UDP (via `sirenMidi2Udp`) ou MIDI série
- Contrôle direct des moteurs (Hz → RPM)
- ComposeSiren **ne touche jamais** aux sirènes physiques

**PureData → ComposeSiren (Port MIDI 2)** :
- ComposeSiren = **moteur audio uniquement**
- Standalone avec ou sans GUI
- 7 canaux physiques (1-7) + 7 canaux virtuels (8-14)
- Mixage multi-canal avec CC70 (volume) et CC10 (pan)
- Reverb globale (CC64-70 sur canal 16)

**Cas d'usage** :

1. **Concert** :
   - Sirènes physiques jouent (PureData → Hardware)
   - ComposeSiren génère backup audio
   - Public écoute les sirènes physiques

2. **Entraînement casque (Mode Jeu)** :
   - **SirenePupitre** lance morceau MIDI complet (toutes les sirènes)
   - Instrumentiste joue **une sirène** avec ses contrôleurs (ex: S3 sur canal 3)
   - **ComposeSiren** joue les 7 sirènes :
     - S3 (canal 3) = audio du **joueur** (contrôlé en temps réel)
     - S1,S2,S4,S5,S6,S7 = audio **d'accompagnement** (séquence MIDI)
   - Mix dans ComposeSiren (volumes relatifs via CC70)
   - Écoute au **casque**, sirènes physiques au repos
   - **Zéro risque** pour les moteurs (entraînement sûr)

3. **Studio** :
   - ComposeSiren pour enregistrement multi-canal
   - Pas de sirènes physiques nécessaires
   - Sirènes virtuelles (canaux 8-14) pour doublage

### Abstractions PureData clés

### External MIDI Player : `midifile`

**Object PureData** : `[midifile]` (standard PureData)  
**Localisation** : `mecaviv/puredata-abstractions/application.layer/M645.pd` (ligne 1630)

**Configuration** :
```pd
[midifile]               # Object de lecture MIDI
[text define midifiles]  # Base de données des fichiers
[file cwd]               # Définit le chemin de base
[metro 40]               # Timer de lecture (40ms = 25 fps)
```

**Système de fichiers** :
- Chemin de base : `~/SirenePupitre-midifiles` (configurable)
- Structure : `louette/`, `patwave/`, `covers/`
- Format lecture : `read louette/AnxioGapT.midi`

**Contrôles** :
- Play/Stop via toggle
- Metro pour avancer dans le fichier
- Routing automatique par canal MIDI

### Communication WebSocket - Mécanisme interne PureData

**Abstraction** : `websocket-server` (basée sur `purest_json`)  
**Port** : 10001 (défini dans M645.pd)  
**Patch principal** : `application.layer/M645.pd` → sous-patch `[pd web-interface]`

**Architecture d'envoi** :
```
PureData patches
   │
   ├─ Note MIDI (de [midifile] ou contrôleurs)
   ├─ Contrôleurs UDP (du MCU)
   ├─ État sirènes (RPM, Hz, etc.)
   │
   └─→ Formatage JSON/Binaire
       │
       ├─ Texte : [s $0webserver]      → JSON text
       └─ Binaire : [s $0webserver-binary] → Protocole binaire
          │
          ▼
   [websocket-server 10001]
          │
          ├─ [broadcast text] → Tous les clients
          ├─ [broadcast binary] → Tous les clients
          └─ [send <socket#>] → Client spécifique
          │
          ▼
   Clients WebSocket (SirenePupitre, SirenConsole)
```

**Mécanisme de collecte des données** :
```pd
# Dans M645.pd, les données sont collectées et packagées :

1. Note MIDI actuelle → variable PureData
2. Contrôleurs UDP → variables PureData
3. Timer (ex: [metro 40]) déclenche envoi périodique
4. Formatage en JSON ou binaire
5. Envoi via [s $0webserver] ou [s $0webserver-binary]
6. websocket-server diffuse aux clients connectés
```

**Format de sortie** :
- **Texte** : JSON (CONFIG_FULL, PARAM_UPDATE, etc.)
- **Binaire** : Protocole custom (0x00=CONFIG, 0x01=MIDI_NOTE, 0x02=CONTROLLERS)

**Gestion des clients** :
- Liste des sockets connectés dans `websockets-list`
- Broadcast à tous ou envoi ciblé
- **Pas de buffer intentionnel** (temps réel prioritaire)
- Delay 30ms seulement pour éviter overflow réseau (sécurité)

**Optimisation temps réel** :
- ✅ Pas de buffer FIFO (pas d'accumulation)
- ✅ Envoi immédiat des données
- ✅ Latence totale très faible (< 20ms estimée)
- ✅ Critical pour le mode jeu (réactivité essentielle)

**À documenter** :
- [ ] `mecaviv/puredata-abstractions/` - Abstractions principales
- [ ] **Réception UDP depuis MCU** : IP fixe, format des packets, mapping contrôleurs
- [ ] Routage MIDI par sirène (1 canal MIDI = 1 sirène)
- [ ] Gestion des courbes de contrôleurs (linear, parabolic, hyperbolic, s-curve)
- [ ] Conversion UDP (MCU) → MIDI CC (ComposeSiren/Sirènes)
- [X] **Communication WebSocket** : Mécanisme via `websocket-server` + `purest_json`
- [ ] Commandes WebSocket pour contrôle lecture (MIDI_FILE_LOAD, PLAY, STOP)
- [ ] Gestion de config.json (chargement, sauvegarde, distribution)

---

## 🎛️ ComposeSiren - Architecture Interne

### Connexion MIDI via JUCE

**Mécanisme simple et automatique** :
1. ComposeSiren démarre (plugin VST/AU ou Standalone)
2. L'utilisateur sélectionne **PureData** comme source MIDI
3. JUCE établit automatiquement la connexion via `aconnect` (ALSA MIDI sous Linux)
4. Les messages MIDI de PureData arrivent directement dans ComposeSiren
5. Aucune configuration manuelle requise ✅

**Avantages** :
- ✅ Configuration transparente
- ✅ Gestion native par JUCE
- ✅ Compatible avec tous les DAWs
- ✅ Reconnexion automatique si déconnexion

### Structure JUCE

**Fichiers source** (`Source/`) :
- `PluginProcessor.cpp/h` - Traitement audio principal
- `PluginEditor.cpp/h` - Interface graphique du plugin
- `CS_midiIN.cpp/h` - Gestion des entrées MIDI
- `Sirene.cpp/h` - Synthèse des sons de sirène
- `synth.cpp/h` - Moteur de synthèse
- `parameters.h` - Définition des paramètres

**À analyser** :
- [X] **Gestion des canaux MIDI** : 1-7 (audio physiques), 8-14 (audio virtuelles)
- [X] **Ne contrôle PAS le hardware** : PureData gère les sirènes physiques exclusivement
- [X] **Standalone** : Application autonome (pas VST uniquement)
- [X] **Interface graphique** : Présente (paramètres, debug, mix)
- [X] **Lancement headless** : Possible via script sans GUI sur Raspberry Pi
- [X] **Synthèse audio** : FFT basée sur enregistrements réels (voir ci-dessous)
- [X] **Presets et configuration** : Mix presets dans config.json (voir ci-dessous)

### Paramètres contrôlables

#### **Synthèse sonore**
- [X] **Fréquence de base** : Note MIDI + Pitch Bend (micro-tonalité)
- [X] **Vitesse moteur (RPM)** : Calculée depuis fréquence × multiplicateur (5.0 pour S1)
- [X] **Volume** : CC7 (volume principal) × CC70 (master volume mixage)
- [X] **Pan** : CC10 (panoramique stéréo -0.5 à +0.5)

#### **Modulations**
- [X] **Vibrato** :
  - CC1 : Amount (profondeur 0-127)
  - CC9 : Frequency (0-12.7 Hz)
  - CC11 : Attack speed (vitesse de montée)
- [X] **Tremolo** :
  - CC15 : Frequency (vitesse modulation amplitude)
  - CC92 : Depth (profondeur 0-127)

#### **Enveloppe**
- [X] **Attack** : CC73 (temps de montée)
- [X] **Release** : CC72 (temps d'extinction)
- [X] **Portamento** : CC5 (glissando entre notes)

#### **Reverb (nouvelle fonctionnalité)**

**⚠️ Important** : La reverb **n'est PAS exposée aux contrôleurs MIDI temps réel**

**Configuration uniquement** (pas de contrôle live) :
- [X] **Enable** : CC64 sur canal 16 (ON/OFF) - Via config uniquement
- [X] **Room Size** : CC65 (taille pièce) - Via config
- [X] **Dry/Wet** : CC66 (mélange) - Via config
- [X] **Damp** : CC67 (amortissement HF) - Via config
- [X] **Highpass Filter** : CC68 (20 Hz - 2 kHz) - Via config
- [X] **Lowpass Filter** : CC69 (2 kHz - 20 kHz) - Via config
- [X] **Width** : CC70 (largeur stéréo) - Via config

**Gestion de la reverb** :
1. **config.js / config.json** : Paramètres par défaut au démarrage
2. **SirenConsole** : Interface de configuration globale
3. **SirenePupitre** : Panneau admin → Paramètres reverb
4. **Envoi à PureData** : Via WebSocket (PARAM_UPDATE)
5. **PureData** : Envoie CC sur canal 16 à ComposeSiren

**Architecture reverb** :
```
Signal → Highpass → Reverb → Lowpass → Mix (dry/wet)
```

**Implémentation** :
- Classe `mareverbe` (reverb custom)
- Filtres IIR (highpass et lowpass) 
- Traitement stéréo indépendant
- Contrôles via canal MIDI 16 (configuration seulement, pas live)

### Synthèse Audio - FFT et Psychoacoustique

**Voir documentation détaillée** : [FLUX_COMPLET_NOTE_MIDI.md](../../mecaviv/ComposeSiren/FLUX_COMPLET_NOTE_MIDI.md)

#### **Principe de base**

ComposeSiren utilise des **enregistrements FFT réels** de sirènes mécaniques (pas de synthèse artificielle) :

```
Note MIDI 75 (D#4, 311.13 Hz)
    ↓
Conversion vitesse moteur → 1555.65 RPM
    ↓
Reconversion midicent → 6300
    ↓
Note FFT → 63
    ↓
Données FFT → [80 notes × 1000 fenêtres × 200 partiels]
    ↓
Addition harmoniques 2-31 (30 partiels par défaut)
    ↓
Son de sirène authentique
```

#### **Caractéristiques clés**

**Fondamentale absente** :
- Les données FFT ne contiennent **QUE les harmoniques 2, 3, 4, 5...**
- La fondamentale (harmonique 1) est absente des données

**Psychoacoustique - "Missing Fundamental"** :
- Le cerveau humain **reconstruit la hauteur fondamentale** à partir des harmoniques
- Détection de l'espacement régulier entre harmoniques
- Perception de la bonne hauteur malgré l'absence de fondamentale

**Exemple - Note E4 (329.63 Hz)** :
- Fondamentale manquante : 329.63 Hz
- Harmoniques présentes : 659.26 Hz (×2), 988.89 Hz (×3), 1318.52 Hz (×4)...
- Hauteur perçue : **E4 (329.63 Hz)** ✅

**Avantages** :
- ✅ **Son 100% authentique** (enregistrements réels)
- ✅ **Timbre naturel** de sirènes mécaniques
- ✅ **Qualité** : 30 partiels = riche spectre harmonique
- ✅ **Performance** : FFT optimisée, faible latence

**Paramètres de synthèse** :
- **qualite** : Nombre de partiels (défaut 30, max 200)
- **Format données** : float 32-bit
- **Taille** : 80 notes × 1000 fenêtres × 200 partiels ≈ 64 MB

### Mix Presets - Configuration Simplifiée

#### **Structure dans config.json**

```json
{
  "sirenConfig": { /* ... */ },
  "displayConfig": { /* ... */ },
  "reverbConfig": { /* ... */ },
  "controllerCurves": { /* ... */ },
  
  "mixPresets": {
    "current": "balanced",
    "presets": {
      "balanced": {
        "name": "Mix Équilibré",
        "description": "Toutes sirènes au même niveau",
        "volumes": [100, 100, 100, 100, 100, 100, 100],
        "pans": [-0.5, -0.33, -0.16, 0, 0.16, 0.33, 0.5],
        "reverb": {
          "enabled": true,
          "roomSize": 0.5,
          "dryWet": 0.3,
          "damp": 0.5,
          "highpass": 20,
          "lowpass": 20000,
          "width": 1.0
        }
      },
      "training": {
        "name": "Entraînement Solo",
        "description": "Sirène active en avant (+6dB), autres en retrait",
        "activeSiren": 3,
        "volumes": [70, 70, 127, 70, 70, 70, 70],
        "pans": [0, 0, 0, 0, 0, 0, 0],
        "reverb": {
          "enabled": true,
          "roomSize": 0.3,
          "dryWet": 0.2,
          "damp": 0.7,
          "highpass": 100,
          "lowpass": 18000,
          "width": 0.5
        }
      },
      "outdoor": {
        "name": "Concert Extérieur",
        "description": "Reverb minimale, simulation plein air",
        "volumes": [100, 100, 100, 100, 100, 100, 100],
        "pans": [-0.4, -0.27, -0.13, 0, 0.13, 0.27, 0.4],
        "reverb": {
          "enabled": true,
          "roomSize": 0.2,
          "dryWet": 0.05,
          "damp": 0.8,
          "highpass": 50,
          "lowpass": 20000,
          "width": 1.0
        }
      },
      "concerthall": {
        "name": "Salle de Concert",
        "description": "Grande acoustique, reverb ample",
        "volumes": [100, 100, 100, 100, 100, 100, 100],
        "pans": [-0.5, -0.33, -0.16, 0, 0.16, 0.33, 0.5],
        "reverb": {
          "enabled": true,
          "roomSize": 0.8,
          "dryWet": 0.5,
          "damp": 0.3,
          "highpass": 20,
          "lowpass": 20000,
          "width": 1.0
        }
      },
      "studio": {
        "name": "Studio Mixé",
        "description": "Panoramique large, acoustique studio",
        "volumes": [100, 100, 100, 100, 100, 100, 100],
        "pans": [-0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6],
        "reverb": {
          "enabled": true,
          "roomSize": 0.6,
          "dryWet": 0.35,
          "damp": 0.5,
          "highpass": 30,
          "lowpass": 20000,
          "width": 0.8
        }
      }
    }
  }
}
```

#### **Presets disponibles**

| Preset | Description | Usage | Reverb | Mix |
|--------|-------------|-------|--------|-----|
| **balanced** | Mix équilibré | Défaut, concert | Medium (30%) | Égal, pan large |
| **training** | Solo en avant | Mode Practice | Sec (20%) | Sirène jouée +6dB |
| **outdoor** | Plein air | Concert extérieur | Minimale (5%) | Égal, pan moyen |
| **concerthall** | Grande salle | Concert intérieur | Ample (50%) | Égal, pan large |
| **studio** | Studio | Enregistrement | Medium (35%) | Égal, pan très large |

#### **Preset "training" dynamique**

Le preset **training** adapte automatiquement le volume selon la sirène jouée :

```json
{
  "activeSiren": 3,  // S3 contrôlée par le joueur
  "volumes": [70, 70, 127, 70, 70, 70, 70]
                    // ^^^
                    // S3 en avant (+6dB)
}
```

**Workflow** :
1. SirenePupitre démarre en mode Practice
2. `activeSiren` = numéro de sirène du joueur (ex: S3 = index 3)
3. Volumes ajustés automatiquement : S3 à 127, autres à 70
4. ComposeSiren mixe : joueur bien audible, accompagnement en retrait

#### **Interface utilisateur simplifiée**

**Proposition UI (SirenConsole & SirenePupitre)** :

```
┌─────────────────────────────────────────────┐
│  🎚️  Configuration Audio                    │
├─────────────────────────────────────────────┤
│                                             │
│  Preset Mix :  [▼ Entraînement Solo     ]  │
│                                             │
│  Description : Sirène active en avant,      │
│                accompagnement en retrait    │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Volumes (aperçu) :                  │   │
│  │ S1: ████████░░  70                  │   │
│  │ S2: ████████░░  70                  │   │
│  │ S3: ██████████ 127 ⭐ (vous)        │   │
│  │ S4: ████████░░  70                  │   │
│  │ S5: ████████░░  70                  │   │
│  │ S6: ████████░░  70                  │   │
│  │ S7: ████████░░  70                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Reverb : Studio Sec                        │
│  • Room Size : 0.3                          │
│  • Dry/Wet   : 20%                          │
│  • Damp      : 0.7                          │
│                                             │
│  [Mode Avancé...] pour édition manuelle    │
│                                             │
└─────────────────────────────────────────────┘
```

**Avantages** :
- ✅ **Dropdown simple** au lieu de 15 sliders
- ✅ **Aperçu visuel** des volumes
- ✅ **Descriptions claires** pour chaque preset
- ✅ **Mode avancé** optionnel pour experts
- ✅ **Cohérent** avec config.json existant

#### **Messages WebSocket - Changement de preset**

**De l'interface → PureData** :
```json
{
    "type": "PARAM_UPDATE",
    "params": {
        "mixPreset": "training",
        "activeSiren": 3
    }
}
```

**PureData → ComposeSiren** :
- CC70 (Master Volume) sur chaque canal avec volumes du preset
- CC10 (Pan) sur chaque canal avec pans du preset
- CC64-70 sur canal 16 avec paramètres reverb

**Résultat** : Changement instantané du mix, sans coupure audio

---

## 🔌 Intégration avec les Interfaces

### SirenePupitre (Visualisation locale)

**Données reçues via WebSocket** :
```json
{
    "type": "MIDI_NOTE",
    "note": 69.5,
    "velocity": 100,
    "controllers": {
        "wheel": { "position": 45, "velocity": 10.5 },
        "joystick": { "x": 0, "y": 0, "z": 0, "button": false },
        "gearShift": { "position": 2, "mode": "THIRD" },
        "fader": { "value": 64 },
        "modPedal": { "value": 0 },
        "pad": { "velocity": 0, "aftertouch": 0 }
    }
}
```

**Affichages** :
- Portée musicale 3D avec note actuelle
- Hz et RPM en temps réel
- État des contrôleurs (3D)
- Ambitus et progression

### SirenConsole (Contrôle central)

**Fonctions** :
- Configuration des 7 pupitres
- Assignation sirènes (exclusive)
- Chargement presets
- Monitoring global
- **Lancement de ComposeSiren** (via installeur)
- **Sélection et chargement de compositions MIDI**

#### **Architecture de Communication**

**Problème WebAssembly** :
- SirenConsole tourne en **WebAssembly** (navigateur)
- Les WebSockets natifs QML ne sont **pas disponibles en WASM**
- Communication directe QML → PureData impossible

**Solution : Proxy via server.js** :

```
┌─────────────────────────────────────────────────────┐
│         SirenConsole (WebAssembly Qt)               │
│         http://localhost:8001                       │
├─────────────────────────────────────────────────────┤
│  • Interface QML dans le navigateur                 │
│  • Envoie requêtes HTTP POST à server.js           │
│  • Pas d'accès WebSocket direct                    │
└──────────┬──────────────────────────────────────────┘
           │
           │ HTTP POST /api/puredata/command
           │ { "type": "MIDI_FILE_LOAD", "path": "..." }
           ▼
┌─────────────────────────────────────────────────────┐
│         server.js (Node.js Proxy)                   │
│         Port 8001                                   │
├─────────────────────────────────────────────────────┤
│  • Serveur HTTP (fichiers WASM + API REST)         │
│  • Client WebSocket vers PureData                  │
│  • Proxy bidirectionnel                            │
│  • Convertit HTTP ↔ WebSocket                      │
└──────────┬──────────────────────────────────────────┘
           │
           │ WebSocket ws://localhost:10001
           │ Messages JSON bidirectionnels
           ▼
┌─────────────────────────────────────────────────────┐
│         PureData (Hub Central)                      │
│         WebSocket Server Port 10001                 │
├─────────────────────────────────────────────────────┤
│  • Reçoit commandes (MIDI_FILE_LOAD, etc.)         │
│  • Envoie état temps réel                          │
│  • Broadcast à tous les clients                    │
└─────────────────────────────────────────────────────┘
```

**Flux de données** :

**1. Commande (SirenConsole → PureData)** :
```
SirenConsole (QML)
    ↓ HTTP POST /api/puredata/command
    ↓ { "type": "MIDI_FILE_LOAD", "path": "louette/file.midi" }
server.js (proxy)
    ↓ WebSocket.send(JSON)
PureData
```

**2. État temps réel (PureData → SirenConsole)** :
```
PureData
    ↓ WebSocket.send({ "type": "MIDI_NOTE", ... })
server.js (proxy)
    ↓ Stocke dans buffer
    ↓ Polling HTTP ou Server-Sent Events
SirenConsole (QML)
```

**API REST** :
- GET `/api/midi/files` - Liste compositions ✅
- GET `/api/midi/categories` - Catégories MIDI ✅
- GET `/api/presets` - Liste presets ✅
- POST `/api/presets` - Sauvegarder preset ✅
- **POST `/api/puredata/command`** - Envoyer commande à PureData (nouveau)
- **GET `/api/puredata/status`** - État de la connexion PureData (nouveau)
- **GET `/api/puredata/events`** - Polling événements temps réel (nouveau)

#### **API MIDI - Gestion des Fichiers**

**Fichier** : `SirenConsole/webfiles/api-midi.js`  
**Intégration** : `server.js` (port 8001)

**Configuration** :
```javascript
// Chemin vers le repository MIDI
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH 
    || path.resolve(__dirname, '../../../mecaviv/compositions');
```

**Route GET `/api/midi/files`** :
```json
{
    "success": true,
    "count": 45,
    "files": [
        {
            "name": "AnxioGapT.midi",
            "path": "louette/AnxioGapT.midi",
            "category": "louette",
            "fullPath": "/Users/.../mecaviv/compositions/louette/AnxioGapT.midi"
        }
    ],
    "repositoryPath": "/Users/.../mecaviv/compositions"
}
```

**Route GET `/api/midi/categories`** :
```json
{
    "success": true,
    "categories": [
        {
            "name": "louette",
            "count": 40,
            "files": [...]
        },
        {
            "name": "patwave",
            "count": 4,
            "files": [...]
        }
    ]
}
```

**Fonctionnalités** :
- ✅ Scan récursif du dépôt `mecaviv/compositions`
- ✅ Groupement automatique par catégories
- ✅ Filtrage fichiers `.midi` et `.mid`
- ✅ Chemins relatifs pour portabilité
- ✅ Variable d'environnement `MECAVIV_COMPOSITIONS_PATH` pour override

**Configuration locale (test)** :
```bash
# Répertoires côte-à-côte
~/repo/mecaviv-qml-ui/     # Ce projet
~/repo/mecaviv/            # Dépôt parent avec compositions/

# Chemin automatique : ../../../mecaviv/compositions
# Fonctionne depuis SirenConsole/webfiles/api-midi.js
```

**Configuration production (Raspberry Pi)** :
```bash
# Avec variable d'environnement
export MECAVIV_COMPOSITIONS_PATH=/home/pi/mecaviv/compositions

# Ou structure identique à dev
~/dev/src/mecaviv-qml-ui/
~/dev/src/mecaviv/
```

---

## 🔀 sirenRouter - Serveur de Routage (À développer)

### Rôle et Architecture

**Problème à résoudre** :
- Plusieurs sources peuvent vouloir contrôler la même sirène simultanément :
  - Console envoie une note
  - Pupitre local envoie une autre note
  - Séquence MIDI joue en parallèle
  - Contrôleur physique actif

**Solution** : **sirenRouter** comme serveur central de routage

```
┌─────────────────────────────────────────────────────────┐
│                     sirenRouter                          │
│              Serveur de Routage Central                  │
├─────────────────────────────────────────────────────────┤
│  • Reçoit requêtes de toutes les sources                │
│  • Arbitrage selon priorités configurables              │
│  • Gestion des exclusivités (1 sirène = 1 source)      │
│  • Détection et résolution des conflits                 │
│  • Monitoring de l'état global                          │
└──────────┬────────────────────────────────┬─────────────┘
           │                                │
           │ Commandes validées             │ État temps réel
           ▼                                ▼
       PureData                        Interfaces (monitoring)
```

### Système de Priorités (À implémenter)

**Niveaux de priorité** (ordre décroissant) :
1. **Console** (SirenConsole) - Priorité maximale
2. **Pupitre local** (SirenePupitre) - Contrôle manuel
3. **Séquence MIDI** - Lecture automatique
4. **Contrôleurs physiques** - Input temps réel

**Règles d'arbitrage** :
- Console peut **toujours** prendre le contrôle
- Pupitre local prend le contrôle si Console inactive
- Séquence MIDI joue si aucun contrôle manuel
- Transitions douces lors des changements de source

### APIs du sirenRouter

**REST API (port 8002)** :
```
GET  /api/sirens/status        # État de toutes les sirènes
GET  /api/sirens/:id           # État d'une sirène
POST /api/sirens/:id/claim     # Réclamer exclusivité
POST /api/sirens/:id/release   # Libérer la sirène
GET  /api/conflicts            # Conflits actifs
```

**WebSocket API (port 8003)** :
```json
{
    "type": "CLAIM_SIREN",
    "sirenId": "S3",
    "source": "console",
    "priority": 100
}
```

**UDP Monitoring (port 8004)** :
- Écoute passive des sirènes
- Collecte état temps réel
- Distribution aux clients

### À implémenter

- [ ] Système de priorités configurables
- [ ] Gestion des conflits et arbitrage
- [ ] API REST pour contrôle
- [ ] WebSocket pour notifications temps réel
- [ ] Monitoring UDP passif
- [ ] Logs et debug des conflits
- [ ] Interface de configuration (web)

---

## 🎮 Mode Jeu "Siren Hero"

**Document détaillé** : Voir [GAME_MODE.md](./GAME_MODE.md)

### Résumé

Jeu de type Guitar Hero adapté aux sirènes mécaniques :
- **Ligne mélodique continue** qui serpente sur la portée fixe
- **Encodage visuel** : Épaisseur (volume), ondulation (vibrato), segments (tremolo)
- **Anticipation** : Lookahead adaptatif selon tempo/difficulté
- **Scoring** : Perfect/Good/Ok/Miss avec système de combo
- **Modes** : Practice (autonome), Performance (synchronisé), Challenge

**Cas d'usage principal** :
- Entraînement casque avec ComposeSiren (7 sirènes mixées)
- Apprentissage gestuel ludique
- Moteurs au repos (sécurité)

---

## ✅ Accompli Récemment (Octobre 2025)

### Configuration Centralisée
- ✅ **config.json unique** à la racine du projet (chemins relatifs portables)
- ✅ **config-loader.js** : Chargement avec expansion de chemins (Node.js)
- ✅ **pdjson external** : Lecture et broadcast depuis PureData
- ✅ **Migration complète** : SirenConsole et SirenePupitre utilisent config.json
- ✅ **Un seul fichier** pour toute la configuration système

### Infrastructure WebSocket
- ✅ **Port 10002** : Migration depuis 10001 (évite conflit avec Cursor)
- ✅ **Mode binaire** : Messages Buffer UTF-8 (compatibilité PureData)
- ✅ **Proxy Node.js** : puredata-proxy.js pour SirenConsole WASM
- ✅ **WebSocket direct QML** : SirenePupitre natif → PureData
- ✅ **Reconnexion automatique** : Gestion robuste des déconnexions
- ✅ **Communication bidirectionnelle** testée et fonctionnelle

### Paramètres Configurables
- ✅ **Caméra 3D** : Position et fieldOfView dans config.json
- ✅ **Affichage notes** : showNoteNames, noteNameSettings (couleur, taille, position)
- ✅ **Contrôleurs** : Scale, couleurs, visibilité
- ✅ **Mise à jour dynamique** : Modifier config.json → PureData recharge → Interfaces refresh

### Workflow Opérationnel
```
config.json (mecaviv-qml-ui)
    ↓
├─→ config-loader.js → SirenConsole (Node.js)
├─→ pdjson → PureData → WebSocket binaire (3672 bytes)
└─→ ConfigController.qml → SirenePupitre
```

---

## 🎯 Prochaines Étapes

### Phase 1 : Analyse du Code
- [ ] Examiner `ComposeSiren/Source/` pour comprendre l'architecture JUCE
- [ ] Identifier les points d'entrée MIDI
- [ ] Documenter les paramètres contrôlables
- [ ] Analyser la communication avec le hardware

### Phase 2 : Documentation PureData
- [ ] Cartographier les abstractions dans `puredata-abstractions/`
- [ ] **Documenter réception UDP depuis MCU** :
  - Format des packets UDP (contrôleurs)
  - IP fixe du MCU (configuration réseau)
  - Mapping UDP → variables PureData
- [ ] **Documenter conversions** :
  - UDP → MIDI CC (pour ComposeSiren)
  - UDP → WebSocket (pour interfaces)
  - UDP → UDP sirènes (via sirenMidi2Udp)
- [ ] Documenter le routage MIDI multi-destination
- [ ] Expliquer les courbes de transformation
- [X] Documenter la communication WebSocket bidirectionnelle
- [X] **Documenter config.json** :
  - [X] Structure centralisée (chemins relatifs portables)
  - [X] Chargement avec config-loader.js (Node.js)
  - [X] Lecture avec pdjson (PureData)
  - [X] Broadcast binaire via WebSocket
  - [X] Mise à jour dynamique dans SirenePupitre/SirenConsole

### Phase 3 : Intégration Console et Lecture MIDI
- [ ] **Lancement ComposeSiren** :
  - Script de démarrage headless (Raspberry Pi)
  - Configuration via arguments CLI
  - Pas d'interface graphique en production
- [X] **API REST** `/api/midi/files` - Liste des compositions disponibles (46 fichiers)
- [X] **Infrastructure WebSocket opérationnelle** :
  - [X] Proxy Node.js → PureData (puredata-proxy.js)
  - [X] Mode binaire (Buffer UTF-8)
  - [X] Port 10002 (évite conflit Cursor sur 10001)
  - [X] Reconnexion automatique
- [ ] Créer l'interface de sélection de fichiers MIDI dans SirenConsole
- [ ] **Messages WebSocket** pour contrôle lecture (Console/Pupitre → PureData) :
  - [X] Infrastructure prête (messages reçus par PureData)
  - [ ] `MIDI_FILE_LOAD` : Charger un fichier (à implémenter dans PureData)
  - [ ] `MIDI_FILE_PLAY` : Démarrer lecture
  - [ ] `MIDI_FILE_STOP` : Arrêter lecture
  - [ ] `MIDI_FILE_PAUSE` : Mettre en pause
  - [ ] `MIDI_FILE_SEEK` : Se déplacer dans le fichier
- [ ] **Configuration reverb** :
  - Interface dans SirenConsole (onglet Audio/Effects)
  - Panneau admin SirenePupitre (section Advanced)
  - Messages PARAM_UPDATE → PureData → CC canal 16
- [ ] **Mode entraînement casque** :
  - SirenePupitre peut lancer morceau complet
  - Joueur contrôle 1 sirène, les 6 autres jouent la séquence
  - Mix dans ComposeSiren (CC70 pour balance)
- [X] Documenter l'external PureData : `[midifile]`
- [ ] Tester le workflow complet (Console → PureData → ComposeSiren)

### Phase 4 : Documentation Finale
- [ ] Schémas détaillés des flux
- [ ] Guide d'utilisation complet
- [ ] Troubleshooting
- [ ] Exemples concrets

---

## 📚 Références

### Documentation mecaviv-qml-ui
- [SirenePupitre README](../SirenePupitre/README.md) - Visualiseur musical
- [SirenConsole README](../SirenConsole/README.md) - Console de contrôle
- [pedalierSirenium README](../pedalierSirenium/README.md) - Pédalier 3D
- [COMMUNICATION.md](./COMMUNICATION.md) - Protocoles WebSocket
- [GAME_MODE.md](./GAME_MODE.md) - Mode Jeu "Siren Hero"

### Documentation mecaviv (repository parent)
- [ComposeSiren README](../../mecaviv/ComposeSiren/README.md) - VST/AU
- [FLUX_COMPLET_NOTE_MIDI.md](../../mecaviv/ComposeSiren/FLUX_COMPLET_NOTE_MIDI.md) - Traitement MIDI détaillé
- [puredata-abstractions](../../mecaviv/puredata-abstractions/) - Abstractions PureData

### Patches PureData clés
- `M645.pd` - Patch principal avec `[midifile]`
- `sirenMidi2Udp.pd` - Conversion MIDI → UDP pour sirènes
- `harmonizer.pd` - Transformations harmoniques
- `websocket-server.pd` - Communication WebSocket

---

**Document de travail** - À compléter au fur et à mesure de l'analyse  
**Dernière mise à jour** : Octobre 2025

