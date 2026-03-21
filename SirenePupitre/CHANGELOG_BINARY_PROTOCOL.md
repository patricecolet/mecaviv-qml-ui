# Changelog - Protocole Binaire pour Contrôleurs

## Date : 19 octobre 2025

### Changements majeurs

#### 🎯 Séparation des contrôleurs et séquences MIDI

**Problème** : Les contrôleurs physiques et les notes de séquence MIDI étaient mélangés dans le même flux JSON, causant :
- Surcharge réseau importante (~600 bytes par message)
- Parsing JSON coûteux en CPU
- Confusion entre données temps réel et séquence

**Solution** : Protocole binaire avec types distincts

### Nouveaux formats binaires

#### Type 0x01 - POSITION (4 bytes) ⭐ Mesure seule — resync + extrapolation UI
- **Usage** : Resync sur le **numéro de mesure**. L’UI a la tempo map et time signature map du fichier ; elle convertit « début de mesure N » en ms et extrapole au tempo entre deux messages. Envoyer à chaque changement de mesure (et play/stop).
- **Source** : PureData/Séquenceur
- **Destination** : SirenePupitre (mode jeu)
- **Fréquence** : 1× par mesure (ou play/stop)

**Structure (4 octets)** :
| Byte | Champ | Type | Description |
|------|-------|------|-------------|
| 0 | Type | uint8 | 1 (0x01) |
| 1 | Flags | uint8 | bit0=playing (1=lecture, 0=stop) |
| 2-3 | mesure | uint16 LE | Numéro de mesure (1-based) |

**Exemple décimal** : playing=true, mesure 5 → `1, 1, 5, 0` ; arrêt → `1, 0, 1, 0`

#### Type 0x01 - POSITION (6 bytes) — Tick seul — JS dérive bar/beat
- **Usage** : Position de lecture = **tick MIDI** uniquement. Le Pupitre a déjà BPM/PPQ du fichier et dérive bar/beat/currentTimeMs côté JS.
- **Source** : PureData/Séquenceur
- **Destination** : SirenePupitre (mode jeu)
- **Fréquence** : 50-100 Hz pendant lecture

**Structure (6 octets)** :
| Byte | Champ | Type | Plage | Description |
|------|-------|------|-------|-------------|
| 0 | Type | uint8 | 0x01 | Identifiant POSITION |
| 1 | Flags | uint8 | 0-255 | bit0=playing, autres réservés |
| 2-5 | tick | uint32 | 0-4294967295 | Position en ticks MIDI (LE) |

**Exemple décimal** : playing=true, tick=9600 → `1, 1, 128, 37, 0, 0`

**Format legacy (9 bytes)** : bar, beatInBar, beat — toujours accepté.

#### Type 0x03 - MIDI_NOTE_VOLANT (5 bytes) ⭐ NOUVEAU (Remplace ancien 0x01)
- **Usage** : Position du volant convertie en note MIDI
- **Source** : Contrôleur physique (volant)
- **Destination** : Curseur sur la portée musicale
- **Fréquence** : ~100 Hz

**Structure** :
| Byte | Champ | Type | Plage | Description |
|------|-------|------|-------|-------------|
| 0 | Type | uint8 | 0x03 | Identifiant MIDI_NOTE_VOLANT |
| 1 | Note | uint8 | 0-127 | Note MIDI du volant |
| 2 | Velocity | uint8 | 0-127 | Vélocité |
| 3 | Bend LSB | uint8 | 0-255 | Pitch Bend LSB |
| 4 | Bend MSB | uint8 | 0-255 | Pitch Bend MSB |

**Exemple** : Note 69 (La4)
```
[0x03, 0x45, 0x64, 0x00, 0x40]
```

#### Type 0x02 - CONTROLLERS (16 bytes)
- **Usage** : État de tous les contrôleurs physiques
- **Fréquence** : ~60 Hz
- **Performance** : 40x plus compact que JSON (16 bytes vs 600 bytes)

**Structure** :
| Byte | Champ | Type | Plage | Description |
|------|-------|------|-------|-------------|
| 0 | Type | uint8 | 0x02 | Identifiant CONTROLLERS |
| 1-2 | Volant | uint16 | 0-360 | Position en degrés (LSB/MSB) |
| 3 | Pad1_After | uint8 | 0-127 | Aftertouch pad 1 |
| 4 | Pad1_Vel | uint8 | 0-127 | Vélocité pad 1 |
| 5 | Pad2_After | uint8 | 0-127 | Aftertouch pad 2 (NOUVEAU) |
| 6 | Pad2_Vel | uint8 | 0-127 | Vélocité pad 2 (NOUVEAU) |
| 7 | Joy_X | uint8 | 0-255 | Position X (0-127=+, 128-255=-) |
| 8 | Joy_Y | uint8 | 0-255 | Position Y (0-127=+, 128-255=-) |
| 9 | Joy_Z | uint8 | 0-255 | Rotation Z (0-127=+, 128-255=-) |
| 10 | Joy_Btn | uint8 | 0/1 | Bouton joystick |
| 11 | Selector | uint8 | 0-4 | Sélecteur 5 vitesses (ÉTENDU) |
| 12 | Fader | uint8 | 0-127 | Potentiomètre |
| 13 | Pedal | uint8 | 0-127 | Pédale modulation |
| 14 | Button1 | uint8 | 0/1 | Bouton 1 (NOUVEAU) |
| 15 | Button2 | uint8 | 0/1 | Bouton 2 (NOUVEAU) |

**Exemple** : Volant à 180°, Pad1 actif
```
[0x02, 0xB4, 0x00, 0x32, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x40, 0x30, 0x00, 0x00]
```

#### Type 0x04 - MIDI_NOTE_DURATION (5 bytes)
- **Usage** : Notes de séquence MIDI avec durée
- **Source** : Fichier MIDI
- **Destination** : Mode jeu uniquement

**Structure** :
| Byte | Champ | Type | Plage | Description |
|------|-------|------|-------|-------------|
| 0 | Type | uint8 | 0x04 | Identifiant MIDI_NOTE_DURATION |
| 1 | Note | uint8 | 0-127 | Note MIDI |
| 2 | Velocity | uint8 | 0-127 | Vélocité |
| 3 | Duration LSB | uint8 | 0-255 | Durée LSB (ms) |
| 4 | Duration MSB | uint8 | 0-255 | Durée MSB (ms) |

**Exemple** : Note 69, durée 800ms
```
[0x04, 0x45, 0x64, 0x20, 0x03]
Durée = 0x20 + (0x03 << 8) = 32 + 768 = 800ms
```

#### Type 0x05 - CONTROL_CHANGE (3 bytes)
- **Usage** : CC MIDI de séquence
- **Source** : Fichier MIDI
- **Destination** : Modulations (vibrato, tremolo, enveloppe)

**Structure** :
| Byte | Champ | Type | Plage | Description |
|------|-------|------|-------|-------------|
| 0 | Type | uint8 | 0x05 | Identifiant CONTROL_CHANGE |
| 1 | CC Number | uint8 | 0-127 | Numéro du Control Change |
| 2 | CC Value | uint8 | 0-127 | Valeur du Control Change |

**Exemple** : CC 1 (Vibrato Amount), valeur 64
```
[0x05, 0x01, 0x40]
```

### Modifications du code

#### WebSocketController.qml
- ✅ Ajout du décodage du format 0x02 (16 bytes)
- ✅ Mapping des 5 positions du sélecteur
- ✅ Support des 2 pads distincts
- ✅ Support des 2 boutons supplémentaires
- ✅ Distinction claire entre contrôleurs physiques et séquence

#### Main.qml
- ✅ Ajout du flag `isControllersOnly` pour les messages 0x02
- ✅ Séparation des flux : contrôleurs physiques vs séquence MIDI
- ✅ Rétrocompatibilité JSON maintenue

#### ControllersPanel.qml
- ✅ Ajout des propriétés pour pad2 (velocity, aftertouch, active)
- ✅ Ajout des propriétés pour button1 et button2
- ✅ Modification de `updateControllers()` pour gérer les nouveaux champs
- ✅ Ajout d'un second PadIndicator pour pad2
- ✅ Ajout des indicateurs visuels pour les 2 boutons
- ✅ Labels "PAD 1" / "PAD 2" en overlay 2D
- ✅ Mise à jour de l'indicateur de connexion (pad1 || pad2)

#### GearShiftIndicator.qml
- ✅ Déjà compatible avec 5 positions (pas de modification nécessaire)

### Documentation

#### README.md
- ✅ Section complète sur le protocole binaire
- ✅ Tableau détaillé du format 0x02 (16 bytes)
- ✅ Exemples avec représentation hexadécimale
- ✅ Mapping des 5 positions du sélecteur
- ✅ Distinction contrôleurs physiques vs séquence MIDI
- ✅ Ancien format JSON marqué comme OBSOLÈTE
- ✅ Mise à jour des formats des contrôleurs
- ✅ Mise à jour du flux de données

### Avantages

#### Performance
- **40x plus compact** : 16 bytes vs ~600 bytes JSON
- **Parsing ultra-rapide** : Accès direct par index au lieu de JSON.parse()
- **Fréquence élevée** : 60-100 Hz sans surcharge réseau
- **CPU libéré** : Pas de parsing JSON coûteux

#### Architecture
- **Séparation claire** : Contrôleurs physiques ≠ Séquence MIDI ≠ Position lecture
- **Types distincts** : 0x01 (position), 0x02 (contrôleurs), 0x03 (volant), 0x04 (séquence), 0x05 (CC)
- **Extensibilité** : Facile d'ajouter de nouveaux types

#### Maintenance
- **Code plus clair** : Chaque type a son traitement dédié
- **Débogage facilité** : Distinction immédiate par le premier byte
- **Rétrocompatibilité** : Format JSON maintenu pour anciens systèmes

### Rétrocompatibilité

Le format JSON reste supporté pour la rétrocompatibilité, mais est déprécié.  
L'application détecte automatiquement le format (binaire ou JSON) et s'adapte.

### Migration PureData

Pour profiter des optimisations, PureData doit envoyer :
1. **Type 0x01** : Position lecture (bar/beat) en mode autonome (à implémenter)
2. **Type 0x02** : Paquet de 16 bytes avec tous les contrôleurs (à implémenter)
3. **Type 0x03** : Position volant → note MIDI (à migrer depuis ancien 0x01)
4. **Type 0x04** : Notes de séquence (déjà fait)
5. **Type 0x05** : CC de séquence (déjà fait)

### Commandes mode autonome (Pupitre → PureData)

Pour le mode autonome, le Pupitre envoie des commandes JSON encodées en binaire UTF-8 :

**MIDI_FILES_REQUEST** : Demander la liste des morceaux
```json
{ "type": "MIDI_FILES_REQUEST", "source": "pupitre" }
```

**MIDI_FILE_LOAD** : Charger un morceau
```json
{ "type": "MIDI_FILE_LOAD", "path": "demo/ex1.mid", "source": "pupitre" }
```

**MIDI_TRANSPORT** : Contrôler la lecture
```json
{ "type": "MIDI_TRANSPORT", "action": "play", "source": "pupitre" }
{ "type": "MIDI_TRANSPORT", "action": "pause", "source": "pupitre" }
{ "type": "MIDI_TRANSPORT", "action": "stop", "source": "pupitre" }
```

**Réponse attendue** : PureData diffuse 0x01 (POSITION) + 0x04/0x05

### Tests requis

- [x] Vérifier la réception du format 0x02 depuis PureData ✅
- [ ] Tester les 2 pads simultanément
- [ ] Tester les 5 positions du sélecteur
- [ ] Tester les 2 boutons supplémentaires
- [ ] Valider la fréquence de mise à jour (60-100 Hz)
- [ ] Vérifier la performance CPU avec format binaire vs JSON
- [ ] Tester la rétrocompatibilité JSON

### Corrections post-implémentation

#### Fix conversion joystick (19 octobre 2025)

**Problème** : Conversion incorrecte des valeurs joystick. Le complément à 2 standard générait des valeurs hors limites.

**Mapping PureData** :
- bytes `0-127` = valeurs `+0` à `+127` (positif)
- bytes `128-255` = valeurs `-0` à `-127` (négatif)

**Solution** : Remapping linéaire au lieu du complément à 2
```javascript
// Avant (incorrect - complément à 2)
if (joyX > 127) joyX -= 256;  // 128 → -128, 255 → -1

// Après (correct - mapping PureData)
joyX = bytes[7] <= 127 ? bytes[7] : -(bytes[7] - 128);
// 0 → 0, 127 → +127, 128 → 0, 255 → -127
```

**Fichiers modifiés** :
- `WebSocketController.qml` : Conversion corrigée (lignes 54-57)
- `STRUCTURE_BINAIRE_0x02.md` : Documentation mise à jour
- `README.md` : Tableau et formats mis à jour

### Notes techniques

#### Conversion volant
- PureData fait la conversion modulo 360 (degrés)
- Plus besoin de diviser par 480 côté QML

#### Pads
- 2 pads physiques distincts (pad1 et pad2)
- Chaque pad : velocity + aftertouch
- `active` calculé automatiquement (velocity > 0)

#### Sélecteur
- 5 positions au lieu de 4
- Position 4 = DOUBLE_OCTAVE

#### Boutons
- 3 boutons au total : joystick + button1 + button2
- Affichés en overlay 2D en bas de l'écran

---

## 13 février 2026

### Vélocité et jauge manuelle

- **SirenController** : propriété `velocity` (0-127), mise à jour depuis le message binaire 0x03 (MIDI_NOTE_VOLANT, byte 2)
- **Main.qml** : propagation de `data.velocity` vers `sirenController.velocity` quand `isVolantNote`
- **Test2D** : `velocity` = `sirenController.velocity`, passé à TopDisplays2D, StaffZone2D (`currentVelocity`), AmbitusPiano2D (opacité touche courante)
- **VelocityGauge2D** : jauge réglable (Slider 0-127) affichée quand le pad n'est pas connecté
- **Message JSON PAD_CONNECTED** : PureData envoie `{ "type": "PAD_CONNECTED", "connected": true/false }` pour indiquer si le pad est connecté — la jauge est masquée quand `connected: true`

---

**Auteur** : Assistant IA  
**Validé par** : Patrice Colet  
**Statut** : Implémenté, en attente de tests

