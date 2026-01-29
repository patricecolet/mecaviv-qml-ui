# Refonte 3D → 2D - Plan de Migration

## Vue d'ensemble

Ce document détaille le plan de migration de l'affichage 3D vers 2D pour améliorer les performances sur Raspberry Pi et réduire la consommation de ressources.

### Objectifs

- **Performance** : Réduire l'utilisation GPU de 50-70% en mode normal
- **Latence** : Réduire la latence d'affichage de 20-30%
- **Compatibilité** : Optimiser pour Raspberry Pi 4/5 (GPU VideoCore VI)
- **Maintenabilité** : Simplifier le code en supprimant la complexité 3D non essentielle

### Gains estimés

| Métrique | Mode Normal | Mode Jeu |
|----------|-------------|----------|
| **Draw calls** | -60% à -80% | -30% à -50% |
| **Utilisation GPU** | -50% à -70% | -30% à -40% |
| **Mémoire VRAM** | -40% à -60% | -20% à -30% |
| **Temps de rendu** | -40% à -60% | -30% à -40% |
| **FPS (Raspberry Pi)** | 30-45 → **50-60 fps** | Variable |
| **CPU usage** | 40-60% → **20-30%** | Variable |
| **Latence** | 20-40ms → **10-20ms** | Variable |

---

## Phase 0 : Infrastructure de test (PRÉREQUIS)

**✅ TERMINÉE**

Infrastructure de test créée :
- Vue de test `Test2D.qml` avec tous les éléments 2D existants reproduits (boutons, ComboBox, GearShiftPositionIndicator, ControllersPanel)
- Bouton "Test 2D" dans `Main.qml` (mode debug uniquement) pour ouvrir/fermer la vue de test
- Loader pour charger la vue de test
- Tous les boutons 2D et éléments UI existants positionnés exactement comme dans l'application principale

**Branche** : `pupitre-2D-test` (commit: Phase 0)

---

## Phase 1 : Composants simples (gain rapide)

**Durée estimée : 2-3 jours**

**Statut : En cours** (1.1 terminé)

### Objectif
Migrer les composants les plus simples pour obtenir des gains immédiats avec un effort minimal.

### ⚠️ Prérequis
**✅ Phase 0 terminée** - Infrastructure de test prête

### Composants à migrer

#### ✅ 1.1 NumberDisplay3D → NumberDisplay2D
**Effort : 0.5 jour** - **TERMINÉ**

**Actuel** :
- `NumberDisplay3D.qml` : 8 digits LED 3D (`DigitLED3D`) avec boîte 3D, cadre, vitre
- ~15 `Model` 3D avec `PrincipledMaterial`

**Nouveau** :
- `NumberDisplay2D.qml` : `Text` avec police monospace LCD
- Fond et cadre avec `Rectangle`
- Style CSS pour effet LED rétro-éclairé

**Fichiers** :
- ✅ Créé `QML/components/NumberDisplay2D.qml`
- ✅ Ajouté à `Test2D.qml` pour tests

---

#### 1.2 LEDText3D → LEDText2D
**Effort : 0.5 jour**

**Actuel** :
- `LEDText3D.qml` : 40+ segments 3D par caractère (`LEDSegment` avec `Repeater3D`)
- Très coûteux : ~200-400 objets 3D pour un texte court

**Nouveau** :
- `LEDText2D.qml` : Police bitmap custom ou `Canvas` avec segments 2D
- Alternative : Police TrueType avec style LED (ex: `LCD.ttf`)

**Fichiers** :
- Créer `QML/utils/LEDText2D.qml`
- Remplacer dans `NumberDisplay2D`, `NoteSpeedometer2D`, etc.

---

#### 1.3 LEDSegment → LEDSegment2D
**Effort : 0.25 jour**

**Actuel** :
- `LEDSegment.qml` : `Model` 3D avec `#Cube` pour chaque segment

**Nouveau** :
- `LEDSegment2D.qml` : `Rectangle` avec rotation 2D

**Fichiers** :
- Créer `QML/utils/LEDSegment2D.qml`
- Utilisé par `LEDText2D`

---

#### 1.4 DigitLED3D → DigitLED2D
**Effort : 0.25 jour**

**Actuel** :
- `DigitLED3D.qml` : Utilise `LEDText3D` pour afficher un chiffre

**Nouveau** :
- `DigitLED2D.qml` : Utilise `LEDText2D` pour afficher un chiffre

**Fichiers** :
- Créer `QML/utils/DigitLED2D.qml`
- Utilisé par `NumberDisplay2D`

---

#### 1.5 Tests et ajustements
**Effort : 1 jour** - **EN COURS**

- Vérifier le rendu sur Raspberry Pi
- Ajuster les couleurs et tailles pour correspondre au style 3D
- Valider les performances

---

## Phase 2 : Composants de la portée musicale

**Durée estimée : 3-4 jours** 

### ⚠️ Note importante

Cette phase migre tous les **sous-composants** de `MusicalStaff3D`. Ces composants doivent être migrés **AVANT** la Phase 3, car `MusicalStaff3D` (puis `MusicalStaff2D`) les orchestre tous ensemble.

### Objectif
Migrer les composants visuels principaux qui nécessitent plus de réflexion sur l'implémentation 2D.

### Composants à migrer

#### 2.1 NoteSpeedometer3D → NoteDisplay2D
**Effort : 0.5 jour**

**Actuel** :
- `NoteSpeedometer3D.qml` : 2 cylindres 3D rotatifs avec texte LED 3D
- 12 notes + 8 octaves = 20 caractères LED 3D
- Cadres rouges avec 8 `Model` 3D
- Complexité élevée pour un affichage simple

**Nouveau** :
- `NoteDisplay2D.qml` : Label 2D classique avec `Column` et `Text`
- **Priorité visuelle** : Nom de la note (grand, accentué)
- Informations secondaires : Numéro MIDI, vélocité, pitch bend
- Layout organisé et clair visuellement

**Structure proposée** :
```qml
Rectangle {
    Column {
        spacing: 5
        
        // Nom de la note (priorité visuelle)
        Text {
            text: noteName  // Ex: "La4"
            font.pixelSize: 48
            font.bold: true
            color: accentColor
        }
        
        // Informations secondaires
        Row {
            spacing: 15
            Text { text: "MIDI: " + midiNote }
            Text { text: "Vel: " + velocity }
            Text { text: "Bend: " + pitchBend }
        }
    }
}
```

**Fichiers** :
- Créer `QML/components/NoteDisplay2D.qml`
- Modifier `SirenDisplay.qml` ligne 237-245

**Avantages** :
- Beaucoup plus simple que la version 3D
- Performance optimale (pas de rotation, pas de LED 3D)
- Lisibilité améliorée
- Maintenance facilitée

---

#### 2.2 AmbitusDisplay3D → AmbitusDisplay2D
**Effort : 1 jour**

**Actuel** :
- `AmbitusDisplay3D.qml` : ~40 sphères 3D (`Model` avec `#Sphere`)
- `Repeater3D` avec matériaux `PrincipledMaterial`
- Lignes supplémentaires (`LedgerLines3D`)

**Nouveau** :
- `AmbitusDisplay2D.qml` : `Repeater` avec cercles 2D (`Rectangle` avec `radius`)
- Ou `Canvas` pour dessiner toutes les notes en une passe
- Lignes supplémentaires avec `Rectangle` horizontal

**Fichiers** :
- Créer `QML/components/ambitus/AmbitusDisplay2D.qml`
- Modifier `MusicalStaff3D.qml` ligne 106-153 (ou `MusicalStaff2D.qml`)

**Défi** : Maintenir le positionnement précis selon la clé (treble/bass)

---

#### 2.3 NoteCursor3D → NoteCursor2D
**Effort : 0.5 jour**

**Actuel** :
- `NoteCursor3D.qml` : `Model` 3D avec `#Cube` vertical
- Animation avec `Behavior` sur `position.y`

**Nouveau** :
- `NoteCursor2D.qml` : `Rectangle` vertical avec `Behavior` sur `y`
- Même logique de positionnement que la version 3D

**Fichiers** :
- Créer `QML/components/ambitus/NoteCursor2D.qml`
- Modifier `MusicalStaff3D.qml` ligne 156-245 (ou `MusicalStaff2D.qml`)

---

#### 2.4 NoteProgressBar3D → NoteProgressBar2D
**Effort : 0.5 jour**

**Actuel** :
- `NoteProgressBar3D.qml` : Barre de progression avec `Model` 3D

**Nouveau** :
- `NoteProgressBar2D.qml` : `Rectangle` avec `width` animé selon progression
- Curseur avec `Rectangle` circulaire

**Fichiers** :
- Créer `QML/components/ambitus/NoteProgressBar2D.qml`
- Modifier `MusicalStaff3D.qml` ligne 248-291 (ou `MusicalStaff2D.qml`)

---

#### 2.5 LedgerLines3D → LedgerLines2D
**Effort : 0.25 jour**

**Actuel** :
- `LedgerLines3D.qml` : Lignes supplémentaires avec `Model` 3D

**Nouveau** :
- `LedgerLines2D.qml` : `Repeater` avec `Rectangle` horizontal

**Fichiers** :
- Créer `QML/components/ambitus/LedgerLines2D.qml`
- Utilisé par `AmbitusDisplay2D`

---

#### 2.6 Clef3D → Clef2D (déjà existant)
**Effort : 0.5 jour**

**Actuel** :
- `Clef3D.qml` : Modèles `.mesh` importés (TrebleKey.mesh, BassKey.mesh)

**Nouveau** :
- `Clef2D.qml` : **Déjà implémenté** ! Utilise `Text` avec polices musicales (NotoMusic, MusiSync)

**Fichiers** :
- Modifier `MusicalStaff3D.qml` ligne 94-103 pour utiliser `Clef2D` au lieu de `Clef3D`
- Ou créer `MusicalStaff2D.qml` qui utilise directement `Clef2D`

---

#### 2.7 Tests et intégration
**Effort : 1 jour**

- Tester chaque composant individuellement
- Vérifier l'alignement et le positionnement
- Valider les performances sur Raspberry Pi

---

## Phase 3 : NoteDisplay (remplacement NoteSpeedometer)

**Durée estimée : 0.5 jour**

### Objectif
Remplacer le tachymètre rotatif 3D par un affichage simple et clair du nom de la note.

### Composant à créer

#### 3.1 NoteSpeedometer3D → NoteDisplay2D
**Effort : 0.5 jour**

**Actuel** :
- `NoteSpeedometer3D.qml` : 2 cylindres 3D rotatifs avec texte LED 3D
- 12 notes + 8 octaves = 20 caractères LED 3D
- Cadres rouges avec 8 `Model` 3D
- Complexité élevée pour un affichage simple

**Nouveau** :
- `NoteDisplay2D.qml` : Label 2D classique avec `Column` et `Text`
- **Priorité visuelle** : Nom de la note (grand, accentué)
- Informations secondaires : Numéro MIDI, vélocité, pitch bend
- Layout organisé et clair visuellement

**Structure proposée** :
```qml
Rectangle {
    Column {
        spacing: 5
        
        // Nom de la note (priorité visuelle)
        Text {
            text: noteName  // Ex: "La4"
            font.pixelSize: 48
            font.bold: true
            color: accentColor
        }
        
        // Informations secondaires
        Row {
            spacing: 15
            Text { text: "MIDI: " + midiNote }
            Text { text: "Vel: " + velocity }
            Text { text: "Bend: " + pitchBend }
        }
    }
}
```

**Fichiers** :
- Créer `QML/components/NoteDisplay2D.qml`
- Modifier `SirenDisplay.qml` ligne 237-245

**Avantages** :
- Beaucoup plus simple que la version 3D
- Performance optimale (pas de rotation, pas de LED 3D)
- Lisibilité améliorée
- Maintenance facilitée

---

## Phase 4 : Mode Jeu (le plus complexe)

**Durée estimée : 5-8 jours**

### Objectif
Migrer le mode jeu avec les notes en vol et les effets visuels (vibrato, tremolo).

### Composants à migrer

#### 4.1 FallingNoteCustomGeo → FallingNote2D
**Effort : 2-3 jours**

**Actuel** :
- `FallingNoteCustomGeo.qml` : Géométrie C++ custom (`TaperedBoxGeometry`)
- Shaders GLSL (`tremolo_vibrato.vert`, `bend.frag`)
- Animation de chute avec `NumberAnimation`

**Options pour le nouveau** :

**Option A : Canvas animé** (recommandé pour simplicité)
- `FallingNote2D.qml` : `Canvas` avec `requestAnimationFrame`
- Dessiner les cubes avec `ctx.fillRect()` et gradients
- Gérer l'animation de chute manuellement

**Option B : ShaderEffect QML 2D** (pour garder les effets visuels)
- `FallingNote2D.qml` : `ShaderEffect` avec shaders 2D simplifiés
- Plus complexe mais garde les effets vibrato/tremolo

**Recommandation** : Option A pour commencer, Option B si les effets visuels sont essentiels

**Fichiers** :
- Créer `QML/game/FallingNote2D.qml`
- Supprimer `taperedboxgeometry.cpp/h` (nettoyage Phase 5)

---

#### 4.2 Shaders vibrato/tremolo → 2D
**Effort : 1-2 jours**

**Actuel** :
- Shaders GLSL 3D : `tremolo_vibrato.vert`, `bend.frag`
- Modulations en temps réel avec `time` animé

**Nouveau** :
- Si Option A (Canvas) : Calculer les modulations en JavaScript
- Si Option B (ShaderEffect) : Adapter les shaders pour 2D (GLSL simplifié)

**Fichiers** :
- Adapter `FallingNote2D.qml` selon l'option choisie
- Supprimer `QML/game/shaders/*.vert` et `*.frag` (nettoyage Phase 5)

---

#### 4.3 MelodicLine3D → MelodicLine2D
**Effort : 1 jour**

**Actuel** :
- `MelodicLine3D.qml` : Gère les segments de ligne et crée les cubes 3D

**Nouveau** :
- `MelodicLine2D.qml` : Gère les segments et crée les notes 2D
- `Repeater` dynamique avec `FallingNote2D`

**Fichiers** :
- Créer `QML/game/MelodicLine2D.qml`
- Modifier `GameMode.qml` ligne 112-133

---

#### 4.4 Supprimer TaperedBoxGeometry C++
**Effort : 0.5 jour**

**Action** :
- Supprimer `taperedboxgeometry.cpp` et `taperedboxgeometry.h`
- Retirer de `CMakeLists.txt`
- Retirer `GameGeometry` du `main.cpp`

**Fichiers** :
- `SirenePupitre/taperedboxgeometry.cpp`
- `SirenePupitre/taperedboxgeometry.h`
- `SirenePupitre/CMakeLists.txt`
- `SirenePupitre/main.cpp`

---

#### 4.5 Tests mode jeu
**Effort : 1-2 jours**

- Tester le timing des notes en vol
- Valider les animations (chute, vibrato, tremolo)
- Vérifier les performances avec plusieurs notes simultanées
- Tester le mode monophonique (troncature des notes)

---

## Phase 5 : Nettoyage et optimisation

**Durée estimée : 1-2 jours**

### Objectif
Nettoyer le code en supprimant les dépendances 3D et optimiser les performances.

### Tâches

#### 5.1 Supprimer les imports QtQuick3D
**Effort : 0.25 jour**

**Action** :
- Chercher tous les `import QtQuick3D` dans le projet
- Les supprimer ou les remplacer par `import QtQuick` si nécessaire

**Fichiers** :
- `QML/Main.qml` ligne 4
- `QML/components/SirenDisplay.qml` ligne 2
- Tous les fichiers `*3D.qml` (à supprimer ou renommer)

---

#### 5.2 Supprimer les fichiers .mesh et shaders 3D
**Effort : 0.25 jour**

**Action** :
- Supprimer `QML/utils/meshes/*.mesh`
- Supprimer `QML/game/shaders/*.vert` et `*.frag`
- Retirer de `data.qrc`

**Fichiers** :
- `QML/utils/meshes/TrebleKey.mesh`
- `QML/utils/meshes/BassKey.mesh`
- `QML/utils/meshes/OldClef3D.mesh`
- `QML/game/shaders/*`

---

#### 5.3 Supprimer le code C++ de géométrie
**Effort : 0.25 jour**

**Action** :
- Supprimer `taperedboxgeometry.cpp/h` (déjà fait en Phase 4)
- Vérifier qu'aucun autre code C++ 3D n'est utilisé

---

#### 5.4 Optimiser les bindings QML
**Effort : 0.5 jour**

**Action** :
- Vérifier les bindings coûteux (calculs dans les propriétés)
- Utiliser `Qt.binding()` si nécessaire
- Optimiser les `Repeater` avec `delegate` léger

---

#### 5.5 Tests de performance finaux
**Effort : 0.5 jour**

- Mesurer les FPS avant/après sur Raspberry Pi
- Vérifier l'utilisation CPU/GPU
- Valider la latence d'affichage

---

## Stratégie de migration

### Approche recommandée

1. **Migration incrémentale** : Migrer composant par composant, garder le système fonctionnel à chaque étape
2. **Tests parallèles** : Tester chaque composant refait dans une vue dédiée avant de migrer les vues principales
3. **Tests sur Raspberry Pi** : Tester après chaque phase pour valider les gains
4. **Branche dédiée** : Créer une branche `refonte-2d` pour isoler les changements
5. **Garder une branche 3D** : Conserver `main` avec la version 3D au cas où

### Stratégie de test parallèle

**Principe** : Créer des vues de test dédiées pour chaque composant migré, permettant de valider le rendu et le comportement sans toucher aux vues existantes.

#### Vue de test pour les composants simples (Phase 1)

**Créer** : `QML/pages/Test2DComponents.qml`

```qml
import QtQuick
import QtQuick.Controls

Page {
    title: "Test Composants 2D"
    
    ScrollView {
        anchors.fill: parent
        Column {
            spacing: 20
            padding: 20
            
            // Test NumberDisplay2D
            Rectangle {
                width: 400
                height: 150
                border.color: "gray"
                Column {
                    anchors.centerIn: parent
                    Text { text: "NumberDisplay2D"; font.bold: true }
                    NumberDisplay2D {
                        value: 1234
                        label: "RPM"
                    }
                }
            }
            
            // Test LEDText2D
            Rectangle {
                width: 400
                height: 100
                border.color: "gray"
                Column {
                    anchors.centerIn: parent
                    Text { text: "LEDText2D"; font.bold: true }
                    LEDText2D {
                        text: "TEST"
                    }
                }
            }
            
            // Test DigitLED2D
            Rectangle {
                width: 200
                height: 100
                border.color: "gray"
                Column {
                    anchors.centerIn: parent
                    Text { text: "DigitLED2D"; font.bold: true }
                    DigitLED2D {
                        value: 7
                    }
                }
            }
        }
    }
}
```

**Accès** : Ajouter un bouton dans `Main.qml` pour ouvrir cette vue de test (mode debug uniquement)

---

#### Vue de test pour la portée musicale (Phase 2)

**Créer** : `QML/pages/TestMusicalStaff2D.qml`

```qml
import QtQuick
import QtQuick.Controls
import "../components/ambitus"

Page {
    title: "Test MusicalStaff2D"
    
    // Simuler sirenInfo et configController pour les tests
    property var testSirenInfo: {
        return {
            ambitus: { min: 48, max: 84 },
            clef: "treble",
            mode: "restricted",
            restrictedMax: 72,
            displayOctaveOffset: 0
        }
    }
    
    MusicalStaff2D {
        anchors.centerIn: parent
        width: 1600
        height: 400
        
        currentNoteMidi: 69.0  // La4
        sirenInfo: testSirenInfo
        configController: null  // Ou créer un mock configController
        
        // Tester avec différentes notes
        SequentialAnimation on currentNoteMidi {
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: 60; duration: 2000 }
            NumberAnimation { to: 72; duration: 2000 }
            NumberAnimation { to: 69; duration: 2000 }
        }
    }
}
```

**Avantages** :
- Permet de tester `MusicalStaff2D` isolément
- Comparer visuellement avec la version 3D
- Valider le positionnement et les animations
- Tester avec différentes configurations sans affecter l'application principale

---

#### Vue de test pour NoteDisplay2D (Phase 3)

**Créer** : `QML/pages/TestNoteDisplay2D.qml`

```qml
import QtQuick
import QtQuick.Controls
import "../components"

Page {
    title: "Test NoteDisplay2D"
    
    Column {
        anchors.centerIn: parent
        spacing: 30
        
        NoteDisplay2D {
            noteName: "La4"
            midiNote: 69
            velocity: 100
            pitchBend: 0
        }
        
        // Tester avec différentes valeurs
        NoteDisplay2D {
            noteName: "Do#5"
            midiNote: 73
            velocity: 127
            pitchBend: 200
        }
    }
}
```

---

### Workflow de développement

1. **Créer le composant 2D** (ex: `NumberDisplay2D.qml`)
2. **Créer/ajouter à la vue de test** correspondante
3. **Tester visuellement** et comparer avec la version 3D
4. **Valider sur Raspberry Pi** si nécessaire
5. **Une fois validé**, migrer la vue principale (`SirenDisplay.qml`)
6. **Supprimer la vue de test** ou la garder pour référence

### Intégration dans Main.qml

**Option A : Bouton debug** (recommandé)
```qml
// Dans Main.qml, mode debug uniquement
Rectangle {
    visible: debugMode
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: 100
    height: 40
    color: "#2a2a2a"
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Ouvrir la vue de test appropriée
            testViewLoader.source = "pages/Test2DComponents.qml"
        }
    }
    
    Text {
        text: "Test 2D"
        anchors.centerIn: parent
        color: "white"
    }
}
```

**Option B : Menu déroulant** (pour plusieurs vues de test)
```qml
ComboBox {
    visible: debugMode
    model: [
        "Test Composants 2D",
        "Test MusicalStaff2D",
        "Test NoteDisplay2D"
    ]
    onActivated: {
        switch(index) {
            case 0: testViewLoader.source = "pages/Test2DComponents.qml"; break
            case 1: testViewLoader.source = "pages/TestMusicalStaff2D.qml"; break
            case 2: testViewLoader.source = "pages/TestNoteDisplay2D.qml"; break
        }
    }
}
```

### Avantages de cette approche

✅ **Pas de régression** : Les vues existantes continuent de fonctionner  
✅ **Tests isolés** : Chaque composant peut être testé indépendamment  
✅ **Comparaison facile** : Ouvrir les deux versions côte à côte  
✅ **Développement incrémental** : Valider avant de migrer  
✅ **Rollback facile** : Si problème, on garde la version 3D

### Workflow proposé

```bash
# 1. Créer la branche
git checkout -b refonte-2d

# 2. Créer les vues de test
# ... créer Test2DComponents.qml, TestMusicalStaff2D.qml, etc. ...
git commit -m "Ajout des vues de test pour composants 2D"

# 3. Migrer Phase 1 (composants simples)
# ... créer NumberDisplay2D, LEDText2D, etc. ...
# ... ajouter à Test2DComponents.qml ...
git commit -m "Phase 1: Composants simples migrés en 2D (avec tests)"

# 4. Tester sur Raspberry Pi via les vues de test
# ... validation visuelle et performance ...

# 5. Migrer Phase 2 (portée musicale)
# ... créer MusicalStaff2D et sous-composants ...
# ... ajouter à TestMusicalStaff2D.qml ...
git commit -m "Phase 2: Portée musicale migrée en 2D (avec tests)"

# 6. Tester MusicalStaff2D isolément
# ... validation complète ...

# 7. Migrer les vues principales (SirenDisplay.qml)
# ... remplacer MusicalStaff3D par MusicalStaff2D ...
git commit -m "Migration SirenDisplay vers MusicalStaff2D"

# 8. Continuer ainsi pour chaque phase
```

### Points d'attention

- **Compatibilité API** : Maintenir les mêmes propriétés publiques pour éviter de casser les usages existants
- **Performance** : Mesurer avant/après chaque phase
- **Régression visuelle** : S'assurer que l'apparence reste acceptable (même si simplifiée)
- **Mode jeu** : Peut être reporté si non prioritaire (représente 40% de l'effort)

---

## Risques et mitigation

### Risques identifiés

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| Perte d'effets visuels | Moyen | Faible | Garder certains effets avec `ShaderEffect` 2D |
| Régression de performance | Faible | Très faible | Tests après chaque phase |
| Bugs de positionnement | Moyen | Moyen | Tests approfondis avec différentes configurations |
| Complexité mode jeu | Élevé | Moyen | Option A (Canvas) d'abord, Option B si nécessaire |

### Plan de rollback

Si des problèmes majeurs apparaissent :

1. Revenir sur la branche `main` (version 3D)
2. Identifier la phase problématique
3. Corriger ou reporter cette phase
4. Reprendre la migration

---

## Estimation totale

| Scénario | Durée | Priorité |
|----------|-------|----------|
| **Mode normal uniquement** (Phases 0-3 + 5) | **9.5-15.5 jours** | Haute |
| **Refonte complète** (toutes les phases) | **14.5-22.5 jours** | Moyenne |

**Notes** :
- **Phase 0 (PRÉREQUIS)** : Infrastructure de test à créer EN PREMIER (0.5 jour)
- La Phase 2 a été réorganisée : la portée musicale doit être migrée **en une seule fois** (from scratch) car elle ne peut pas cohabiter avec les éléments 3D
- La Phase 3 est maintenant dédiée uniquement au remplacement de `NoteSpeedometer3D` par `NoteDisplay2D`

### Recommandation

**Commencer par les Phases 1-3** pour obtenir des gains significatifs rapidement, puis évaluer si la Phase 4 (mode jeu) est nécessaire selon les besoins.

---

## Checklist de migration

### Phase 0 (PRÉREQUIS)
- [x] ✅ Infrastructure de test créée et fonctionnelle

### Phase 1
- [ ] NumberDisplay3D → NumberDisplay2D
- [ ] Ajouter NumberDisplay2D à `Test2DComponents.qml`
- [ ] LEDText3D → LEDText2D
- [ ] LEDSegment → LEDSegment2D
- [ ] DigitLED3D → DigitLED2D
- [ ] Ajouter tous les composants à `Test2DComponents.qml`
- [ ] Tests visuels et validation sur Raspberry Pi
- [ ] Migrer les vues principales (SirenDisplay.qml) une fois validé

### Phase 2 (Portée musicale complète - from scratch)
- [ ] Créer MusicalStaff2D.qml (composant principal, reprendre toute la logique)
- [ ] Créer AmbitusDisplay2D.qml
- [ ] Créer NoteCursor2D.qml
- [ ] Créer NoteProgressBar2D.qml
- [ ] Créer LedgerLines2D.qml (ou intégrer dans AmbitusDisplay2D)
- [ ] Intégrer Clef2D (déjà existant)
- [ ] Ajouter MusicalStaff2D à la vue de test
- [ ] Tests visuels et validation complète sur Raspberry Pi
- [ ] Comparer avec MusicalStaff3D côte à côte
- [ ] Modifier SirenDisplay.qml pour utiliser MusicalStaff2D (une fois validé)

### Phase 3 (NoteDisplay)
- [ ] NoteSpeedometer3D → NoteDisplay2D (label simple avec nom de note prioritaire)
- [ ] Ajouter NoteDisplay2D à la vue de test
- [ ] Tests visuels et validation
- [ ] Migrer SirenDisplay.qml pour utiliser NoteDisplay2D (une fois validé)

### Phase 4 (optionnel)
- [ ] FallingNoteCustomGeo → FallingNote2D
- [ ] Shaders vibrato/tremolo → 2D
- [ ] MelodicLine3D → MelodicLine2D
- [ ] Supprimer TaperedBoxGeometry C++
- [ ] Tests mode jeu

### Phase 5
- [ ] Supprimer imports QtQuick3D
- [ ] Supprimer fichiers .mesh et shaders
- [ ] Supprimer code C++ 3D
- [ ] Optimiser bindings QML
- [ ] Tests de performance finaux

---

## Notes techniques

### Alternatives pour les effets visuels

Si certains effets 3D sont essentiels :

- **ShaderEffect QML 2D** : Pour garder les effets visuels complexes
- **Canvas avec gradients** : Pour des effets plus simples
- **Animations QML** : Pour les transitions et mouvements

### Polices pour LED

Options pour remplacer `LEDText3D` :

1. **Police bitmap custom** : Créer une police TTF avec style LED
2. **Canvas** : Dessiner les segments manuellement
3. **Police existante** : Utiliser une police LCD open-source

### Performance Canvas vs Rectangle

- **Rectangle** : Plus rapide pour formes simples
- **Canvas** : Plus flexible mais plus coûteux
- **Recommandation** : Utiliser `Rectangle` quand possible, `Canvas` seulement si nécessaire

---

## Références

- [Qt Quick 2D Performance](https://doc.qt.io/qt-6/qtquick-performance.html)
- [Canvas API](https://doc.qt.io/qt-6/qml-qtquick-canvas.html)
- [ShaderEffect 2D](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html)

---

**Document créé le :** 2026-01-27  
**Dernière mise à jour :** 2026-01-27  
**Statut :** Planification
