# Mode Jeu - Siren Hero

## 🎮 Vue d'ensemble

Mode jeu de type "Guitar Hero" où des cubes tombent sur la portée musicale et doivent être joués au bon moment.

## 📁 Fichiers créés

### `MelodicLine3D.qml`
Composant qui affiche une ligne mélodique composée de cubes 3D qui tombent.
- **Style** : Cubes métalliques turquoise
- **Encodage visuel** :
  - **Largeur (X)** : Volume (vélocité MIDI)
  - **Hauteur (Y)** : Durée de la note (en ms)
  - **Position Y** : Hauteur de note (sur la portée)
  - **Position X** : Position de la note sur l'ambitus
  - **Couleur** : Dépend de la hauteur de la note (bleu → rouge)

### `FallingCube.qml`
Composant pour un cube qui tombe (version simple avec shader).
- Animation de chute depuis `spawnHeight` jusqu'à `targetY`
- Vitesse de chute : `fallSpeed` (150 par défaut)
- Auto-destruction quand il atteint la cible
- Modulations tremolo/vibrato via shaders

### `FallingNoteCustomGeo.qml`
Composant avancé avec géométrie C++ custom pour visualisation ADSR complète.
- **Statut** : ancien chemin C++ (`TaperedBoxGeometry`) retiré du build.
- **Enveloppe ADSR** visualisée en 3D :
  - **Attack** : Pyramide inversée en bas (pointe vers le bas)
  - **Sustain** : Cube central (hauteur variable)
  - **Release** : Pyramide effilée en haut (pointe vers le haut)
- **Modulations** tremolo/vibrato proportionnelles au sustain
- **Contrôle MIDI CC** pour tous les paramètres

### `GameMode.qml`
Vue du mode jeu qui affiche :
- La portée musicale (MusicalStaff3D)
- La ligne mélodique (MelodicLine3D)
- Gestion des événements MIDI

### Intégration dans `SirenDisplay.qml`
- Bouton "Mode Jeu" en haut à droite
- Switch entre mode normal et mode jeu
- Masque les contrôleurs en mode jeu
- Déplace les afficheurs (RPM, Hz, Speedometer) en bas de la portée en mode jeu

## 🎯 Fonctionnement

### 1. Activation du mode jeu
- Cliquer sur le bouton "Mode Jeu" en haut à droite
- Le mode normal disparaît
- La vue jeu s'affiche avec la portée + cubes qui tombent

### 2. Réception des événements MIDI
- Les messages MIDI arrivent via WebSocket depuis PureData
- **Format binaire optimisé** : `[0x04, note, velocity, duration_lsb, duration_msb]` (5 bytes)
- **0x04** est envoyé **en avance** par Pd (délai ≥ `midiDelayMs`, ex. 5 s) pour que l’UI affiche la chute des notes au bon moment.
- **0x01** (position) est envoyé **au moment** où Pd joue le MIDI, pour l’affichage mesure/beat (monitoring).
- `WebSocketController` décode le format binaire et les transmet à `Main.qml`
- `Main.qml` les transmet à `GameMode` si le mode jeu est actif
- `GameMode` ajoute les événements à la liste `midiEvents` avec un timestamp = temps écoulé depuis le Play

### 3. Traitement des événements
- `GameMode.processMidiEvents()` traite la liste des événements
- **NoteOn uniquement** : Crée un segment pour chaque note avec velocity > 0
- **Durée** : Utilise `event.duration` du paquet binaire (500ms par défaut)
- Les noteOff sont ignorés (la durée est déjà dans le paquet)

### 4. Création des cubes
- `MelodicLine3D` crée un cube pour chaque nouveau segment
- **Position X** : Calculée avec `calculateNoteXPosition()` pour aligner avec l'ambitus
- **Position Y** : Calculée avec `calculateNoteYPosition()` pour aligner avec la portée
- **Hauteur du cube** : `(duration / 1000.0) * fallSpeed / 200.0` (proportionnelle à la durée de la note)
- **Largeur du cube** : Proportionnelle à la vélocité

### 5. Animation de chute
- Les cubes tombent depuis `spawnHeight` (500) jusqu'à `targetY` (position de la note)
- Vitesse : `fallSpeed` (150 par défaut)
- **Comportement** :
  - Le **bas du cube** (noteOn) arrive sur la note au moment où elle doit être jouée
  - Le **haut du cube** (noteOff) représente la fin de la note
  - Le cube disparaît quand le bas a atteint la note (le haut a passé la note)

## 🎨 Style Visuel

### Matériau des cubes
```qml
PrincipledMaterial {
    baseColor: "#00CED1"  // Turquoise
    metalness: 0.7        // Métallique
    roughness: 0.2        // Poli
    emissiveFactor: 0.5   // Légèrement lumineux
}
```

### Dimensions des cubes
- **Hauteur (Y)** : Calculée selon la durée de la note
  - Formule : `(duration / 1000.0) * fallSpeed / 200.0`
  - Ajustable en modifiant le diviseur (100, 200, 300...)
  - Représente la durée de la note (noteOn → noteOff)
- **Largeur (X)** : Proportionnelle à la vélocité
  - Formule : `(velocity / 127.0 * 0.8 + 0.2) * cubeSize`
- **Profondeur (Z)** : Fixe (`cubeSize = 0.4`)

### Positionnement des cubes
- Le cube est positionné par son **centre** en 3D
- Le **bas du cube** (noteOn) arrive sur la note au moment où elle doit être jouée
- Le **haut du cube** (noteOff) représente la fin de la note
- Le cube disparaît quand le bas a atteint la note (le haut a passé la note)

### Couleur des cubes
- Dépend de la hauteur de la note
- Bleu (notes graves) → Rouge (notes aiguës)
- Formule : `hue = 240 - (normalized * 180)`

## 🔧 Paramètres

### Dans `GameMode.qml`
- `gameStartTime` : Timestamp de démarrage du jeu
- `gameActive` : État actif/inactif du jeu
- `midiEvents` : Liste des événements MIDI reçus

### Dans `MelodicLine3D.qml`
- `currentTime` : Temps de jeu en ms
- `lookaheadTime` : Temps d'avance (3s par défaut)
- `scrollSpeed` : Vitesse de défilement (1.0 par défaut)

## 📊 Structure des données

### Format binaire optimisé (WebSocket)
```
[0x04, note, velocity, duration_lsb, duration_msb]
```

**Exemple** : Note La4 (69), vélocité 100, durée 800ms
```
[0x04, 0x45, 0x64, 0x20, 0x03]
```

**Calcul de la durée** :
- `0x20 + (0x03 << 8)` = `32 + 768` = **800ms**

**Avantages** :
- **20x plus compact** que JSON (~5 bytes vs ~100+ bytes)
- **Parsing ultra-rapide** (pas de JSON.parse)
- **Parfait pour le mode jeu** avec beaucoup de notes

### Événement MIDI (objet JavaScript interne)
```javascript
{
    timestamp: 1234567890,  // Timestamp en ms (ajouté côté client)
    note: 69,               // Note MIDI (0-127)
    velocity: 100,          // Vélocité (0-127)
    duration: 800,          // Durée de la note en ms
    controllers: {},        // Contrôleurs (vide pour le format binaire)
    isSequence: true        // Flag pour différencier séquence/contrôleurs
}
```

### Segment de ligne
```javascript
{
    timestamp: 1234567890,  // Timestamp du noteOn
    note: 69.5,             // Note MIDI
    velocity: 100,          // Vélocité (0-127)
    duration: 800,          // Durée en ms
    x: 0,                   // Position X (calculée)
    vibrato: false,         // Vibrato actif
    tremolo: false,         // Tremolo actif
    volume: 0.79            // Volume normalisé (0-1)
}
```

## 🎼 Enveloppe ADSR et Modulations (Legacy)

### Architecture C++/QML

Cette section décrit une implémentation historique (`TaperedBoxGeometry`) qui n'est plus compilée.
Conserver ces notes uniquement comme archive de conception.

### Visualisation ADSR

```
      ___           <- Release (pyramide, hauteur variable)
     /   \
    /     \
   |-------|         <- Sustain (cube, hauteur = duration - attack)
   |       |
   |       |
    \     /
     \___/           <- Attack (pyramide inversée, hauteur variable)
```

**Logique des hauteurs :**
- `totalDurationHeight` = durée de la note (MIDI duration) convertie en unités visuelles
- `attackHeight` = min(`attackTime` converti, 95% de `totalDurationHeight`)
- `sustainHeight` = calculé automatiquement en C++ : `totalDurationHeight - attackHeight`
- `releaseHeight` = `releaseTime` converti (s'AJOUTE, ne fait pas partie de duration)
- **Total affiché** = `attackHeight + sustainHeight + releaseHeight`

**Interface C++/QML :**
- **QML passe les données musicales brutes** : `attackTime`, `duration`, `totalHeight`, `releaseHeight`, `velocity`, `baseSize`
- **Le C++ calcule TOUT** : attackRatio, effectiveVelocity, proportions attack/sustain, largeur, génération des vertices
- **La géométrie est générée à la taille exacte** avec les bonnes proportions ADSR
- Le scale QML est simplement `(cubeSize, cubeSize, cubeSize)` : un facteur global uniforme à ajuster manuellement
- **Avantages** : 
  - Cohérence musicale (effectiveVelocity = velocity × attackRatio)
  - Séparation claire : QML = données, C++ = géométrie
  - Dimensions cohérentes en unités visuelles

### Contrôle MIDI CC

**Format binaire :** `[0x05, CC_number, value]` (3 bytes)

| CC# | Paramètre | Conversion | Plage |
|-----|-----------|------------|-------|
| 1 | Vibrato Amount | `value/127 * 4.0` | 0.0 - 4.0 |
| 9 | Vibrato Rate | `1.0 + value/127 * 19.0` | 1.0 - 20.0 Hz |
| 15 | Tremolo Rate | `1.0 + value/127 * 19.0` | 1.0 - 20.0 Hz |
| 72 | Release Time | `value==0 ? 0 : 38100/(128-value)` | 0ms - 38.1s |
| 73 | Attack Time | `value==0 ? 0 : 38100/(128-value)` | 0ms - 38.1s |
| 92 | Tremolo Amount | `value/127 * 0.6` | 0.0 - 0.6 |

**Flux des CC :**
1. WebSocket reçoit `[0x05, CC#, value]`
2. `WebSocketController` émet `controlChangeReceived(ccNumber, ccValue)`
3. `Main.qml` → `GameMode.handleControlChange()`
4. `GameMode` → `MelodicLine3D` (propriétés)
5. `MelodicLine3D` → `FallingNoteCustomGeo` (à la création)
6. `CustomMaterial` utilise les valeurs pour les shaders

### Modulations proportionnelles

**Problème résolu :** Les modulations étaient trop fortes sur les petits cubes (sustain court).

**Solution :** Facteur `sustainHeightNormalized` passé au shader
```glsl
float sustainFactor = clamp(sustainHeightNormalized / 75.0, 0.2, 1.0);
tremoloAmount *= sustainFactor;
vibratoAmount *= sustainFactor;
```
- Sustain petit (15) → modulations à 20%
- Sustain normal (75) → modulations à 100%

## 🚀 Prochaines étapes

1. **Améliorer l'éclairage**
   - Ajouter lumière ambiante pour uniformiser les pyramides attack/release
   - Ajuster DirectionalLight pour meilleur rendu

2. **Ajouter le scoring**
   - Détecter quand un cube atteint la note
   - Comparer avec les contrôleurs du joueur
   - Afficher le feedback (Perfect/Good/Ok/Miss)
   - Afficher un score et un combo

3. **Optimiser la performance**
   - Limiter le nombre de cubes visibles
   - Utiliser un pool d'objets réutilisables
   - Optimiser les calculs de position

4. **Améliorer le gameplay**
   - Ajouter des effets spéciaux (hold notes, slides)
   - Ajouter des power-ups
   - Ajouter des niveaux de difficulté

## 🐛 Debug

### Console logs
- `🎮 Mode jeu: ACTIVÉ/DÉSACTIVÉ` : Changement de mode
- `🎵 processMidiEvents` : Traitement des événements MIDI
- `🎵 noteToY` : Calcul de la position Y d'une note
- `🎵 noteToX` : Calcul de la position X d'une note

### Vérifications
- Les cubes apparaissent-ils au noteOn ?
- Les cubes s'alignent-ils avec les notes de la portée ?
- Le **bas** du cube atteint-il la note au moment où elle doit être jouée ?
- Le **haut** du cube représente-t-il la fin de la note (noteOff) ?
- La hauteur des cubes correspond-elle à la durée ?
- Les cubes disparaissent-ils quand le bas a atteint la note ?

### Problèmes courants

**Les cubes ne s'alignent pas avec les notes**
- Vérifier que `staffWidth` est passé à `GameMode`
- Vérifier que `octaveOffset` est appliqué dans `noteToY`

**Les cubes disparaissent avant d'atteindre les notes**
- Vérifier que `octaveOffset` est appliqué dans `noteToY`

**Les cubes sont trop grands/petits**
- Ajuster le diviseur dans `FallingCube.qml` ligne 23
- Exemple : `/ 100.0` → `/ 200.0` pour réduire de moitié

## 📝 Notes

- Le mode jeu est **fonctionnel** et prêt pour le scoring
- Les cubes s'alignent correctement avec les notes de la portée
- La durée des notes est envoyée dans le paquet binaire
- Les noteOff sont ignorés (la durée est déjà dans le paquet)

---

**Créé le** : 13 janvier 2025  
**Dernière mise à jour** : 15 octobre 2025 (v3 - Enveloppe ADSR complète avec géométrie C++ custom + contrôle MIDI CC)

