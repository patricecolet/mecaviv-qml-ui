# Mode Jeu - Siren Hero

## 🎮 Vue d'ensemble

Mode jeu simple pour tester l'affichage d'une ligne mélodique qui descend sur la portée musicale.

## 📁 Fichiers créés

### `MelodicLine3D.qml`
Composant qui affiche une ligne mélodique composée de petits cubes 3D.
- **Style** : Cubes métalliques steampunk
- **Encodage visuel** :
  - Épaisseur du cube = Volume (fader)
  - Position Y = Hauteur de note (sur la portée)
  - Position Z = Temps (profondeur)

### `GameMode.qml`
Vue du mode jeu qui affiche :
- La portée musicale (MusicalStaff3D)
- La ligne mélodique (MelodicLine3D)
- Gestion des événements MIDI

### Intégration dans `SirenDisplay.qml`
- Bouton "Mode Jeu" en haut à droite
- Switch entre mode normal et mode jeu
- Masque les contrôleurs en mode jeu

## 🎯 Fonctionnement

### 1. Activation du mode jeu
- Cliquer sur le bouton "Mode Jeu" en haut à droite
- Le mode normal disparaît
- La vue jeu s'affiche avec la portée + ligne

### 2. Réception des événements MIDI
- Les messages MIDI arrivent via WebSocket depuis PureData
- `WebSocketController` les transmet à `Main.qml`
- `Main.qml` les transmet à `GameMode` si le mode jeu est actif
- `GameMode` ajoute les événements à la liste `midiEvents`

### 3. Affichage de la ligne
- `MelodicLine3D` lit la liste `midiEvents`
- Pour chaque événement, crée un cube 3D
- Position X = 0 (centré)
- Position Y = calculée depuis la note MIDI (hauteur sur la portée)
- Position Z = calculée depuis le timestamp (profondeur/temps)

### 4. Animation
- Timer à 60 FPS met à jour `currentTime`
- Les cubes descendent progressivement (Z diminue)
- Les cubes qui passent Z=0 disparaissent

## 🎨 Style Visuel

### Matériau Steampunk
```qml
PrincipledMaterial {
    baseColor: "#808080"  // Gris acier
    metalness: 0.9        // Très métallique
    roughness: 0.1        // Très poli
}
```

### Taille des cubes
- `cubeSize: 8` (paramétrable)
- Scale = `cubeSize / 100` pour Qt3D

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

### Événement MIDI
```javascript
{
    timestamp: 1234567890,  // Timestamp en ms
    note: 69.5,             // Note MIDI (avec micro-tonalité)
    velocity: 100,          // Vélocité (0-127)
    controllers: {          // Contrôleurs (optionnel)
        modPedal: 64,
        pad: 0,
        // ...
    }
}
```

### Segment de ligne
```javascript
{
    x: 0,                   // Position X (centré)
    y: 0,                   // Position Y (calculée depuis note)
    z: -500,                // Position Z (profondeur)
    thickness: 8,           // Épaisseur (volume)
    volume: 0.5,            // Volume normalisé (0-1)
    vibrato: false,         // Vibrato actif
    tremolo: false          // Tremolo actif
}
```

## 🚀 Prochaines étapes

1. **Tester avec de vrais événements MIDI**
   - Envoyer des notes depuis PureData
   - Vérifier que les cubes apparaissent
   - Vérifier que les cubes descendent

2. **Améliorer l'encodage visuel**
   - Ajouter le serpentin pour le vibrato
   - Ajouter la visibilité alternée pour le tremolo
   - Varier l'épaisseur selon le volume

3. **Ajouter le scoring**
   - Détecter quand un cube atteint Z=0
   - Comparer avec les contrôleurs du joueur
   - Afficher le feedback (Perfect/Good/Ok/Miss)

4. **Optimiser la performance**
   - Limiter le nombre de cubes visibles
   - Supprimer les cubes qui sont passés (Z > 0)
   - Utiliser un pool d'objets réutilisables

## 🐛 Debug

### Console logs
- `🎮 Mode jeu: ACTIVÉ/DÉSACTIVÉ` : Changement de mode
- `🎵 GameMode - Événement MIDI reçu:` : Réception d'un événement
- `🎮 GameMode - Nombre d'événements MIDI:` : Mise à jour de la liste

### Vérifications
- Les cubes apparaissent-ils ?
- Les cubes descendent-ils ?
- Les cubes disparaissent-ils quand ils passent Z=0 ?

## 📝 Notes

- Le mode jeu est **très simple** pour l'instant
- Pas encore de scoring
- Pas encore d'encodage visuel avancé (vibrato/tremolo)
- Juste pour **tester l'affichage de base**

---

**Créé le** : 13 janvier 2025  
**Dernière mise à jour** : 13 janvier 2025

