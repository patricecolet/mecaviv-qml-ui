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

## État actuel (janvier 2026)

**Vue 3D retirée du flux principal.** L'application n'affiche plus que la **vue 2D** (`Test2D.qml`), chargée par défaut dans `Main.qml`. Plus de bascule 2D/3D ni de `SirenDisplay` dans le flux.

- **Main** : une seule propriété `gameMode` ; un seul `Loader` qui charge `Test2D.qml` (vue principale).
- **Mode jeu** : entièrement dans Test2D. Quand `gameMode` est actif, un overlay affiche portée 2D compacte, NumberDisplay2D (RPM/Hz avec scale), Play/Stop et Mode Normal en bas, et `GameAutonomyPanel` (sélection morceau).
- **Boutons** : en vue normale, Test2DButtons (Contrôleurs, Fretté, Mode Jeu, Play quand en mode jeu, Admin). En mode jeu (overlay), Play/Stop (1/4 bas) et Mode Normal (3/4 bas).

---

## Phase 0 : Infrastructure de test (PRÉREQUIS)

**✅ TERMINÉE**

Infrastructure de test devenue **vue principale** : `Test2D.qml` est la seule vue affichée au démarrage (plus de bouton debug pour ouvrir/fermer).

---

## Phase 1 : Composants simples (gain rapide)

**Durée estimée : 2-3 jours**

**Statut : En cours** (1.1 et 1.5 terminés)

### Objectif
Migrer les composants les plus simples pour obtenir des gains immédiats avec un effort minimal.

### ⚠️ Prérequis
**✅ Phase 0 terminée** - Infrastructure de test prête

### Composants à migrer

#### ✅ 1.1 NumberDisplay3D → NumberDisplay2D
**TERMINÉ** - Composant créé et ajouté à la vue de test


#### 1.5 Affichage note MIDI
**TERMINÉ** - Affichage simple de la note MIDI (nom, numéro, vélocité, bend) entre les deux NumberDisplay

---

## Phase 2 : Composants de la portée musicale

**Durée estimée : 3-4 jours**

**✅ TERMINÉE** — MusicalStaff2D complet (lignes, Clef2D, AmbitusDisplay2D, LedgerLines2D, NoteCursor2D, NoteProgressBar2D).

### ⚠️ Note importante

Cette phase migre tous les **sous-composants** de `MusicalStaff3D`. L’organisation 2D doit **refléter celle du 3D** : même hiérarchie de classes, composants en parallèle. On dessine d’abord la portée (les 5 lignes), puis on ajoute les sous-composants dans le même ordre que dans `MusicalStaff3D.qml`.

### Objectif
Migrer la portée musicale en 2D en gardant la même structure que la version 3D (orchestrateur + sous-composants).

### Organisation parallèle (3D → 2D)

| MusicalStaff3D.qml        | MusicalStaff2D.qml        |
|---------------------------|----------------------------|
| Repeater3D (5 lignes)      | Repeater (5 Rectangle)     |
| Clef3D                    | Clef2D (existant)          |
| AmbitusDisplay3D         | AmbitusDisplay2D          |
| NoteCursor3D             | NoteCursor2D              |
| NoteProgressBar3D        | NoteProgressBar2D          |

### Layout et mode jeu

- **Zone portée pleine largeur** : Dans `Test2D.qml`, une zone dédiée `staffZone` affiche `MusicalStaff2D` sur presque toute la largeur de la fenêtre (marges gauche/droite 24 px), comme en 3D (`SirenDisplay` avec `staffWidth: 1600`). Les 5 lignes s’étendent donc sur toute cette zone.
- **Mode jeu** : accessible via le **bouton Mode Jeu** en bas à droite (3/4). Quand actif, un **overlay** recouvre la vue et affiche : portée 2D compacte, NumberDisplay2D RPM/Hz (avec scale), Play/Stop en bas à gauche, Mode Normal en bas à droite, et GameAutonomyPanel. La migration 2D des notes en chute (FallingNote2D, MelodicLine2D) s'intégrera dans cet overlay.

### Ordre de migration

**2.1 MusicalStaff2D (squelette)** — Dessiner la portée en premier  
- Créer `MusicalStaff2D.qml` avec uniquement les **5 lignes** (5 Rectangle explicites), les mêmes propriétés que la 3D (`lineSpacing`, `lineThickness`, `staffWidth`, `lineColor`, etc.).
- Reprendre la logique de `MusicalStaff3D` lignes 78-91 en 2D.
- Ensuite on ajoute les sous-composants un par un, dans l’ordre ci-dessous.

**2.2 Clef2D** — **TERMINÉ** — Déjà existant, intégré dans `MusicalStaff2D` (comme Clef3D dans MusicalStaff3D).

**2.3 AmbitusDisplay3D → AmbitusDisplay2D**  
- Créer `AmbitusDisplay2D.qml` : notes (cercles 2D ou Canvas). Les lignes supplémentaires (ledger) sont gérées en 2.4.
- Utilisé par `MusicalStaff2D` au même endroit logique que `AmbitusDisplay3D` dans `MusicalStaff3D`.
- Maintenir le positionnement selon la clé (treble/bass), en réutilisant `NotePositionCalculator` si besoin.
- Détail : `AmbitusDisplay3D` = ~40 sphères 3D + `LedgerLines3D` → en 2D : `Repeater` avec cercles (`Rectangle` radius) ou `Canvas` ; `LedgerLines2D` est ajouté à l’étape 2.4.

---

#### 2.4 LedgerLines3D → LedgerLines2D — **TERMINÉ**
**Effort : 0.25 jour** — À faire juste après l’ambitus : les ledger lines s’adaptent à l’ambitus (lignes au-dessus/en-dessous de la portée). Créer `LedgerLines2D.qml` : Repeater + Rectangle horizontal. Utilisé par `AmbitusDisplay2D`.

---

#### 2.5 NoteCursor3D → NoteCursor2D — **TERMINÉ**
**Effort : 0.5 jour**

**Actuel** :
- `NoteCursor3D.qml` : `Model` 3D avec `#Cube` vertical
- Animation avec `Behavior` sur `position.y`

**Nouveau** :
- `NoteCursor2D.qml` : `Rectangle` vertical avec `Behavior` sur `y`
- Même logique de positionnement que la version 3D

**Fichiers** :
- Créer `QML/components/ambitus/NoteCursor2D.qml` — **fait**
- Intégration dans `MusicalStaff2D.qml`

---

#### 2.6 NoteProgressBar3D → NoteProgressBar2D — **TERMINÉ**
**Effort : 0.5 jour**

**Actuel** :
- `NoteProgressBar3D.qml` : Barre de progression avec `Model` 3D

**Nouveau** :
- `NoteProgressBar2D.qml` : `Rectangle` avec `width` animé selon progression
- Curseur avec `Rectangle` circulaire

**Fichiers** :
- Créer `QML/components/ambitus/NoteProgressBar2D.qml` — **fait**
- Intégration dans `MusicalStaff2D.qml` avec `progressConfig` (couleurs, barHeight, barOffsetY, cursorSize, etc.)

---

#### 2.7 Tests et intégration — **TERMINÉ**
**Effort : 1 jour**

- Tester chaque composant individuellement
- Vérifier l'alignement et le positionnement
- Valider les performances sur Raspberry Pi

---


## Phase 3 : Mode Jeu (le plus complexe)

**Durée estimée : 5-8 jours**

**Statut : En cours** — 3.1 et 3.3 sont **implémentés** mais **en attente de ta validation**. On ne passe à l’étape suivante qu’après validation explicite de chaque étape.

**Contexte** : Le mode jeu est une **vue différente**, accessible via le **bouton de droite** (en bas de l'écran). Les composants 2D (FallingNote2D, MelodicLine2D) seront intégrés dans cette vue, pas dans la vue de test 2D.

**Layout actuel (mode jeu dans Test2D)** :
- Dans `Test2D.qml`, overlay `gameModeOverlay` visible quand `gameMode` est actif : fond, portée 2D compacte (StaffZone2D, lineSpacing 16, lineThickness 1.5), NumberDisplay2D RPM/Hz en bas avec `scaleX`/`scaleY` (1.6×uiScale, 0.75×uiScale pour RPM ; 1.4×uiScale, 0.65×uiScale pour Hz), boutons Play/Stop (1/4 bas) et Mode Normal (3/4 bas), et GameAutonomyPanel (Loader).
- `StaffZone2D` reçoit `configController` et le transmet à `MusicalStaff2D`.
- **Fait** : `GameMode.qml` est un `Item` 2D ; il contient `MelodicLine2D` (anchors.fill parent). Un `Loader` charge `GameMode` dans l'overlay (même zone que `StaffZone2D`). Les notes en chute (FallingNote2D) utilisent les mêmes coordonnées que la portée 2D. Main transmet les événements MIDI séquence (0x04) et CC (0x05) à `testViewLoader.item.gameModeItem`.


### Architecture retenue pour le mode jeu (préparation phase 3)

**À implémenter pour préparer la phase 3** :

1. **Séquenceur JS pour l'animation, PureData pour la lecture**
   - **Animation (UI)** : un séquenceur JavaScript gère l'affichage des notes en vol **en avance** (lookahead). Il calcule quelles notes afficher et quand, indépendamment du flux temps réel PureData.
   - **Lecture (audio/MIDI)** : PureData reste le moteur de lecture. Il charge le **fichier MIDI complet** (toutes les pistes), reçoit la sync (0x06 position, transport) et joue. Aucun envoi de « joue cette note à ce tick » depuis Node.
   - **Sync** : PureData reçoit 0x06 (position en ticks) et play/stop ; le séquenceur JS reçoit la même position (ou la dérive depuis le démarrage) et aligne **visuellement** l'animation. Une seule source de vérité pour la lecture (PureData), une pour l'affichage (JS).

2. **Option « Jouer l'accompagnement » (on/off) — indispensable**
   - Quand le joueur est seul, les **autres sirènes** doivent pouvoir jouer la partition (accompagnement). Cela impose que le fichier MIDI soit **complet** (toutes les pistes) et que PureData le lise ; la variante « Node = maître » (un seul séquenceur JS qui envoie 0x06 + toutes les notes à PureData) est **écartée**.
   - Une option UI **« Jouer l'accompagnement »** (on/off) doit être ajoutée (ex. dans le mode jeu / GameAutonomyPanel) pour activer ou désactiver les autres pistes côté lecture.

3. **Source des données d'animation pour le séquenceur JS**
   - **Option retenue (A)** : le **fichier MIDI est parsé en JS** (Pupitre ou Node) pour alimenter le séquenceur d'animation. Même fichier que PureData (même `path`), chargé une fois pour l'affichage. Le JS n'envoie jamais de commandes de lecture à PureData ; il utilise ces données **uniquement** pour l'animation (notes, temps, durées, lookahead).
   - Cohérence : même fichier, même path ; duplication acceptable (une fois pour l'audio dans PureData, une fois pour l'affichage en JS).

### Ce qu’il faut observer (mode jeu)

1. **Activer le mode jeu** : bouton **« Mode Jeu »** en bas à droite (3/4) → l’overlay s’affiche (fond sombre, portée 2D compacte au centre, RPM/Hz en bas, Play/Stop à gauche, Mode Normal à droite, sélection de morceau).
2. **Lancer un morceau** : depuis l’overlay, charger un fichier MIDI (GameAutonomyPanel) puis **Play** (bouton overlay ou transport). Le **Pupitre** doit être connecté en WebSocket à la **Console** (SirenConsole).
3. **Animation attendue** : pendant la lecture, des **barres colorées** (notes) tombent du **haut** vers la **portée**, alignées sur les hauteurs de note (grave → gauche, aigu → droite), et disparaissent à la **ligne du curseur** (sous la portée). Une note = une barre verticale avec dégradé (couleur selon la hauteur), qui descend à vitesse constante (~5 s de chute).
4. **Source des notes** : c’est **PureData** qui envoie les notes aux pupitres (voir [COMMUNICATION.md](COMMUNICATION.md) — PureData → Pupitre, MIDI binaire ; [GAME_MODE.md](GAME_MODE.md) — PureData = serveur de jeu). À terme, l'animation sera alimentée par le séquenceur JS (étape 3.0) ; la lecture reste PureData. Le Pupitre se connecte à PureData (WebSocket, port 10002) et reçoit les messages MIDI binaires. Si tu ne vois pas l’animation, vérifier que PureData envoie bien les notes au format attendu par le Pupitre (ex. **0x04** en 5 octets : type, note, vélocité, durée LSB, durée MSB — voir SirenePupitre README / protocole binaire).

### ⚠️ Approche esthétique — validation obligatoire par étape

Le **comportement** reste le même : tremolo, vibrato, vélocité, attack et release continuent de piloter l’animation. En revanche, leur **représentation visuelle** en 2D ne reprend pas telle quelle l’esthétique 3D : on définit une **nouvelle esthétique** au fur et à mesure de l’implémentation.

- Chaque notion (chute, tremolo, vibrato, vélocité, attack, release) est traduite en un rendu 2D à définir.
- **Chaque étape doit être validée par toi** : l’esthétique (et le comportement) sont validés avant de passer à la suivante. Pas d’enchaînement automatique des étapes.
- Le principe (données, timing, paramètres) reste inchangé ; seul le rendu visuel évolue.

**Validation Phase 3 (à cocher par toi)** :
- [ ] **3.0** Séquenceur JS d'animation (lookahead) + option « Jouer l'accompagnement » (on/off) — voir architecture retenue ci‑dessus
- [ ] **3.1** FallingNote2D — chute, forme, gradient, troncature monophonique
- [ ] **3.2** Shaders vibrato/tremolo → 2D (à faire après validation 3.1)
- [ ] **3.3** MelodicLine2D + GameMode 2D + intégration overlay — notes en vol dans le mode jeu
- [ ] **3.4** puis **3.5** après validations ci‑dessus

### Objectif
Migrer le mode jeu avec les notes en vol ; les effets (vibrato, tremolo, vélocité, attack, release) sont représentés par une esthétique 2D à définir et valider à chaque étape.

### Composants à migrer

#### 3.0 Séquenceur JS d'animation + option « Jouer l'accompagnement » — **à implémenter**
**Effort : 2-3 jours**

**Objectif** : Préparer la phase 3 en mettant en place l'architecture retenue (séquenceur JS pour l'animation en avance, PureData pour la lecture) et l'option indispensable « Jouer l'accompagnement » (on/off).

**Séquenceur JS d'animation** :
- Créer un séquenceur JavaScript (côté Pupitre ou Node) qui **parse le fichier MIDI** (même `path` que PureData) pour en extraire les notes de la piste du joueur (filtrage par canal / sirène selon `currentSirens`).
- Le séquenceur calcule les segments de ligne (notes + durées + temps) avec un **lookahead** (ex. 3–8 s) et alimente `MelodicLine2D` / `GameMode` (propriété `lineSegments` ou équivalent).
- Réception de la **position de lecture** (0x06 ou dérivée) pour aligner l'animation sur le transport ; pas d'envoi de commandes de lecture à PureData.
- Fichier MIDI chargé une fois au choix du morceau (GameAutonomyPanel) ; même path envoyé à PureData via `MIDI_FILE_LOAD`.

**Option « Jouer l'accompagnement » (on/off)** :
- Ajouter une option UI dans le mode jeu (ex. dans `GameAutonomyPanel` ou à côté du sélecteur de morceau) : case à cocher ou toggle « Jouer l'accompagnement ».
- Persister la préférence (config locale ou message vers PureData/Console) et transmettre à PureData (ou ComposeSiren) pour activer/désactiver les pistes d'accompagnement (sirènes autres que celle du joueur).

**Fichiers / emplacements** :
- Nouveau module JS (ex. `GameSequencer.js` ou équivalent dans SirenePupitre webfiles ou QML utils) pour le parsing MIDI et le calcul des segments avec lookahead.
- API ou endpoint pour récupérer le contenu MIDI d'un fichier (liste de morceaux existante ; étendre si besoin pour « métadonnées / notes du fichier X »).
- `GameAutonomyPanel.qml` (ou parent) : intégration du séquenceur (appel au chargement du morceau, mise à jour des segments) et ajout du contrôle « Jouer l'accompagnement ».

**Ce qu'il se passe quand on charge un morceau et on appuie sur Play** :
1. **Chargement du morceau** : au choix dans le sélecteur, le Pupitre envoie `MIDI_FILE_LOAD` à PureData et appelle `GET /api/midi/notes?path=...&channel=N` (serveur Node SirenePupitre webfiles sur le port 8000). Les notes de la piste du joueur sont stockées (`sequencerNotes`, `sequencerBpm`). **Prérequis** : le serveur Node doit tourner (`cd SirenePupitre/webfiles && npm install && node server.js`) et le dépôt MIDI doit contenir le fichier.
2. **Clic sur Play** : le Pupitre envoie `MIDI_TRANSPORT` play et met à jour l'état UI (bouton Stop). L'animation peut être alimentée de deux façons :
   - **Avec PureData** : PureData (ou la Console) envoie des messages **0x01 POSITION** (6 octets : type, flags playing, **tick** uint32 LE). Le JS du Pupitre dérive bar/beat/currentTimeMs depuis le tick (BPM/PPQ déjà chargés). pendant la lecture. À chaque réception, le séquenceur met à jour `lineSegmentsData` et `currentTimeMs` → les notes en chute s'affichent.
   - **Sans PureData (test)** : si aucun 0x01 n'est reçu, un **simulateur de position local** tourne dès que l'UI est en « Play » et que des notes sont chargées : le temps avance localement (BPM du fichier), les segments dans la fenêtre lookahead sont calculés et l'animation s'affiche. Ainsi on peut tester l'animation en lançant uniquement le Pupitre + le serveur Node (pas besoin de PureData pour voir les notes tomber).

---

#### 3.1 FallingNoteCustomGeo → FallingNote2D — **implémenté, en attente de ta validation**
**Effort : 2-3 jours**

**Actuel** :
- `FallingNoteCustomGeo.qml` : Géométrie C++ custom (`TaperedBoxGeometry`)
- Shaders GLSL (`tremolo_vibrato.vert`, `bend.frag`)
- Animation de chute avec `NumberAnimation`

**Approche** : L’animation de chute et les paramètres (vélocité, attack, release, tremolo, vibrato) sont conservés ; l’**esthétique 2D** (forme, couleur, mouvement visuel) est à définir puis **à valider par toi** avant de passer à 3.2.

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
- `QML/game/FallingNote2D.qml` — **créé** (Item + Canvas + NumberAnimation, API identique, `truncateNote(atLocalY)` pour mode monophonique)
- Supprimer `taperedboxgeometry.cpp/h` (nettoyage Phase 4)

---

#### 3.2 Shaders vibrato/tremolo → 2D
**Effort : 1-2 jours**

**Actuel** :
- Shaders GLSL 3D : `tremolo_vibrato.vert`, `bend.frag`
- Modulations en temps réel avec `time` animé

**Approche** : Tremolo et vibrato restent des paramètres d’animation ; leur **représentation visuelle** en 2D (oscillation, taille, opacité, etc.) est à définir et valider étape par étape.

**Nouveau** :
- Si Option A (Canvas) : Calculer les modulations en JavaScript
- Si Option B (ShaderEffect) : Adapter les shaders pour 2D (GLSL simplifié)

**Fichiers** :
- Adapter `FallingNote2D.qml` selon l'option choisie
- Supprimer `QML/game/shaders/*.vert` et `*.frag` (nettoyage Phase 4)

---

#### 3.3 MelodicLine3D → MelodicLine2D — **implémenté, en attente de ta validation**
**Effort : 1 jour**

**Actuel** :
- `MelodicLine3D.qml` : Gère les segments de ligne et crée les cubes 3D

**Nouveau** :
- `MelodicLine2D.qml` : **créé** — Item, `NotePositionCalculator2D`, `FallingNote2D`, même API (lineSegments, lineSpacing, ambitus, staffWidth, cursorBarY, CC), troncature monophonique.
- `GameMode.qml` : **modifié** — `Node` → `Item`, `MusicalStaff3D` supprimé, `MelodicLine3D` remplacé par `MelodicLine2D` (anchors.fill parent). Intégration dans Test2D : Loader GameMode dans la zone portée de l'overlay ; Main transmet MIDI séquence et CC à `gameModeItem`.

---

#### 3.4 Supprimer TaperedBoxGeometry C++
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

#### 3.5 Tests mode jeu
**Effort : 1-2 jours**

- Tester le timing des notes en vol
- Valider les animations et l’esthétique (chute, vibrato, tremolo, vélocité, attack, release)
- Vérifier les performances avec plusieurs notes simultanées
- Tester le mode monophonique (troncature des notes)

---

## Phase 4 : Nettoyage et optimisation

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
- Supprimer `taperedboxgeometry.cpp/h` (déjà fait en Phase 3)
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
| **Mode normal uniquement** (Phases 0-2 + 5) | **9-15 jours** | Haute |
| **Refonte complète** (toutes les phases) | **14-22 jours** | Moyenne |

**Notes** :
- **Phase 0 (PRÉREQUIS)** : Infrastructure de test à créer EN PREMIER (0.5 jour)
- La Phase 2 a été réorganisée : la portée musicale doit être migrée **en une seule fois** (from scratch) car elle ne peut pas cohabiter avec les éléments 3D

### Recommandation

**Commencer par les Phases 1-2** pour obtenir des gains significatifs rapidement, puis évaluer si la Phase 3 (mode jeu) est nécessaire selon les besoins.

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
- [x] Créer LedgerLines2D.qml (ou intégrer dans AmbitusDisplay2D)
- [ ] Intégrer Clef2D (déjà existant)
- [ ] Ajouter MusicalStaff2D à la vue de test
- [ ] Tests visuels et validation complète sur Raspberry Pi
- [ ] Comparer avec MusicalStaff3D côte à côte
- [ ] Modifier SirenDisplay.qml pour utiliser MusicalStaff2D (une fois validé)

### Phase 3 (optionnel — chaque case à cocher quand **tu** as validé l’étape)
- [ ] 3.1 FallingNote2D validé (chute, gradient, troncature)
- [ ] 3.2 Shaders vibrato/tremolo 2D (après validation 3.1)
- [ ] 3.3 MelodicLine2D + intégration overlay validés
- [ ] Shaders vibrato/tremolo → 2D
- [ ] MelodicLine3D → MelodicLine2D
- [ ] Supprimer TaperedBoxGeometry C++
- [ ] Tests mode jeu

### Phase 4
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
**Dernière mise à jour :** 2026-01-30  
**Statut :** Vue 2D seule (3D retirée du flux). Mode jeu dans Test2D. Phase 3 : architecture retenue documentée (séquenceur JS + option « Jouer l'accompagnement ») ; étape 3.0 à implémenter ; 3.1 et 3.3 implémentés, **en attente de ta validation** ; on ne touche pas à 3.2 tant que 3.1 n’est pas validé.
