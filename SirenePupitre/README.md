# MECANIQUE VIVANTE M645 - Visualiseur Musical

## Vue d'ensemble
Application de visualisation en temps réel des données musicales et mécaniques d'une sirène mécanique contrôlée. Interface locale d'un pupitre dans le système SirenConsole.

## Architecture du système

```
Console (SirenConsole) → Pupitres (SirenePupitre) → PureData (Exécution) → Sirènes Physiques
     ↑                        ↑                           ↑                    ↑
   Priorité Max          Contrôle Local              Routage MIDI         Instruments
                                                      + VST Virtuelles
```

### Hiérarchie de Contrôle
- **Console** : Priorité maximale, peut contrôler tous les pupitres
- **Pupitre** : Mode autonome, contrôlé localement ou par la console
- **PureData** : Exécution, routage MIDI et communication avec les sirènes
- **Sirènes** : Instruments physiques et virtuels (VST)

## Architecture du projet

```
SirenePupitre/
├── README.md                       # Documentation du projet
├── main.cpp                        # Point d'entrée C++
├── data.qrc                        # Ressources Qt
├── CMakeLists.txt                  # Configuration de build
├── config.js                       # Configuration unique (sirènes + affichage + serveur)
├── build/                          # Dossier de compilation
├── webFiles/                       # Fichiers pour WebAssembly
│   ├── server.js                   # Serveur Node.js pour tests
│   └── [fichiers compilés]
└── QML/                            # Tous les fichiers QML
    ├── Main.qml                    # Fenêtre principale
    ├── components/                 # Composants visuels
    │   ├── SirenDisplay.qml        ✅ 
    │   ├── NumberDisplay3D.qml     ✅ 
    │   ├── ControllersPanel.qml    ✅ 
    │   ├── StudioView.qml          ✅ (Visualiseur 3D)
    │   ├── ambitus/                # Composants musicaux
    │   │   ├── AmbitusDisplay3D.qml     ✅
    │   │   ├── MusicalStaff3D.qml       ✅
    │   │   ├── NoteCursor3D.qml         ✅
    │   │   ├── NoteProgressBar3D.qml    ✅
    │   │   ├── LedgerLines3D.qml        ✅
    │   │   └── NotePositionCalculator.qml ✅
    │   └── indicators/             # Composants indicateurs
    │       ├── GearShiftIndicator.qml   ✅
    │       ├── FaderIndicator.qml       ✅
    │       ├── PedalIndicator.qml       ✅
    │       ├── PadIndicator.qml         ✅
    │       ├── JoystickIndicator.qml    ✅
    │       └── WheelIndicator.qml       ✅
    ├── controllers/                # Contrôleurs logiques
    │   ├── ConfigController.qml    ✅
    │   ├── SirenController.qml     ✅
    │   └── WebSocketController.qml ✅
    ├── utils/                      # Utilitaires réutilisables
    │   ├── Clef3D.qml              ✅
    │   ├── MusicUtils.qml          ✅ 
    │   ├── LEDText3D.qml           ✅
    │   ├── DigitLED3D.qml          ✅ 
    │   ├── Ring3D.qml              ✅ 
    │   ├── LEDSegment.qml          ✅ 
    │   ├── Knob.qml                ✅ 
    │   ├── Knob3D.qml              ✅
    │   └── ColorPicker.qml         ✅
    └── admin/                      # Interface d'administration ✅
        ├── AdminPanel.qml          ✅
        ├── PasswordDialog.qml      ✅
        ├── SirenSelectionSection.qml    ✅
        ├── VisibilitySection.qml        ✅
        ├── AdvancedSection.qml          ✅
        ├── visibility/             # Sous-sections de visibilité
        │   ├── VisibilityMainDisplays.qml   ✅
        │   ├── VisibilityControllers.qml    ✅
        │   └── VisibilityMusicalStaff.qml   ✅
        └── advanced/               # Sous-sections avancées
            ├── AdvancedAbout.qml        ✅
            ├── AdvancedConfig.qml       ✅
            ├── AdvancedWebSocket.qml    ✅
            ├── AdvancedColors.qml       ✅
            └── AdvancedSizes.qml        ✅
```

### Organisation des imports
Les composants dans les sous-dossiers (visibility/, advanced/) nécessitent des imports relatifs dans leurs sections parentes.

## Fichier de configuration

### config.js - Configuration unique (format JavaScript pour WebAssembly)
```javascript
var configData = {
    "serverUrl": "ws://localhost:10001",  // URL du serveur WebSocket
    "admin": {
        "enabled": true  // Accès panneau admin (1/true = autorisé, 0/false = bloqué)
    },
    "ui": {
        "scale": 0.5  // Facteur d'échelle global de l'interface (0.1 à 2.0)
    },
    "controllersPanel": {
        "visible": false  // Visibilité du panneau des contrôleurs (fermé par défaut)
    },
    "sirenConfig": {
        "mode": "restricted",  // "restricted" ou "admin"
        "currentSiren": "1",   // ID de la sirène active
        "sirens": [
            {
                "id": "1",
                "name": "S1",
                "outputs": 12,  // Nombre de sorties mécaniques
                "ambitus": {
                    "min": 43,  // Note MIDI minimale
                    "max": 86   // Note MIDI maximale
                },
                "clef": "bass",
                "restrictedMax": 72,  // Note max en mode restricted
                "transposition": 1,    // En octaves (affecte le son)
                "displayOctaveOffset": 0,  // Décalage visuel (-4 à +4 octaves)
                "frettedMode": {
                    "enabled": false  // Mode fretté : force les notes entières (gamme tempérée)
                }
            }
            // Autres sirènes...
        ]
    },
    "displayConfig": {
        "components": {
            "rpm": { 
                "visible": true,
                "ledSettings": {
                    "color": "#FFFF99",
                    "digitSize": 1.0,
                    "spacing": 10
                }
            },
            "frequency": { 
                "visible": true,
                "ledSettings": {
                    "color": "#FFFF99",
                    "digitSize": 1.0,
                    "spacing": 10
                }
            },
            "sirenCircle": { "visible": true },
            "noteDetails": { "visible": true },
            "studioButton": { "visible": true },
            "musicalStaff": {
                "visible": true,
                "noteName": {
                    "visible": true
                },
                "lines": {
                    "color": "#CCCCCC"
                },
                "ambitus": {
                    "visible": true,
                    "noteFilter": "natural",  // "all" ou "natural"
                    "noteSize": 0.15,
                    "noteColor": "#E69696",
                    "showNoteNames": true
                },
                "cursor": {
                    "visible": true,
                    "color": "#FF3333",
                    "width": 3,
                    "offsetY": 30
                },
                "progressBar": {
                    "visible": true,
                    "barHeight": 5,
                    "showPercentage": true,
                    "colors": {
                        "background": "#333333",
                        "progress": "#33CC33",
                        "cursor": "#FFFFFF"
                    }
                }
            }
        },
        "controllers": {
            "visible": true
        }
    }
};
```

### Architecture de configuration

#### Gestion hybride config.js / PureData
- **config.js** : Configuration par défaut chargée au démarrage
- **PureData** : Peut remplacer ou modifier la configuration via WebSocket
- **Synchronisation bidirectionnelle** : Les changements dans l'interface sont envoyés à PureData

#### Format de transmission WebSocket
- **Format** : Les messages sont envoyés en **binaire** (pas en texte)
- **Encodage** : JSON converti en ArrayBuffer/bytes avant envoi
- **Reception** : Les messages binaires sont décodés en JSON côté récepteur

**3. Dans ConfigController**, la méthode d'envoi devra être adaptée** :

```qml
// Au lieu de sendMessage, peut-être :
webSocketController.sendBinaryMessage({
    type: "PARAM_CHANGED",
    path: ["displayConfig", "components", componentName, "visible"],
    value: visible
})
```

#### Conversions de types automatiques
- **Champs "visible"** : Les valeurs numériques sont automatiquement converties en booléens
  - `0` → `false`
  - `1` (ou tout autre nombre) → `true`
  - Permet la compatibilité avec PureData qui utilise 0/1 au lieu de false/true
- **Implémentation** : Conversion dans `ConfigController.setValueAtPath()`

#### Exemple de message PARAM_UPDATE avec conversion
```json
{
    "type": "PARAM_UPDATE",
    "path": ["displayConfig", "components", "rpm", "visible"],
    "value": 0
}
```
→ La valeur `0` sera automatiquement convertie en `false` pour le champ "visible"

#### Messages WebSocket pour la configuration

##### QML → PureData
```json
{
    "type": "REQUEST_CONFIG"
}
```

```json
{
    "type": "PARAM_CHANGED",
    "path": ["displayConfig", "components", "rpm", "visible"],
    "value": false
}
```

##### PureData → QML
```json
{
    "type": "CONFIG_FULL",
    "config": {
        "serverUrl": "ws://localhost:10001",
        "sirenConfig": { },
        "displayConfig": { }
    }
}
```

```json
{
    "type": "PARAM_UPDATE",
    "path": ["displayConfig", "components", "rpm", "visible"],
    "value": true
}
```

##### Console → Pupitre (Système de priorité)
```json
{
    "type": "CONSOLE_CONNECT",
    "source": "console"
}
```
→ La console prend le contrôle du pupitre. Le panneau admin est désactivé et les modifications locales sont bloquées.

```json
{
    "type": "CONSOLE_DISCONNECT",
    "source": "console"
}
```
→ La console libère le contrôle. Le pupitre repasse en mode autonome.

```json
{
    "type": "PARAM_UPDATE",
    "path": ["displayConfig", "components", "rpm", "visible"],
    "value": false,
    "source": "console"
}
```
→ Modification de paramètre depuis la console. Le paramètre `source: "console"` empêche la réémission vers PureData.

##### Contrôle d'accès au panneau admin
```json
{
    "type": "PARAM_UPDATE",
    "path": ["admin", "enabled"],
    "value": 1
}
```
→ Utiliser `1` pour autoriser l'ouverture du panneau admin, `0` pour le bloquer.


##### Contrôle du panneau des contrôleurs
```json
{
    "type": "PARAM_UPDATE",
    "path": ["controllersPanel", "visible"],
    "value": 1
}
```
→ Utiliser `1` pour afficher le panneau des contrôleurs, `0` pour le masquer.

##### Contrôle de l'échelle de l'interface
```json
{
    "type": "PARAM_UPDATE",
    "path": ["ui", "scale"],
    "value": 0.5
}
```
→ Utiliser une valeur entre 0.1 et 2.0 pour ajuster la taille globale de l'interface.

##### Mode fretté par sirène
```json
{
    "type": "PARAM_UPDATE",
    "path": ["sirenConfig", "sirens", 0, "frettedMode", "enabled"],
    "value": 1
}
```
→ Utiliser `1` pour activer le mode fretté (notes entières uniquement) pour une sirène spécifique, `0` pour le désactiver.

### Formats des contrôleurs

#### Volant (Wheel)
- **position** : entier (0-360) - position en degrés
- **velocity** : flottant (-100.0 à +100.0 deg/s)

#### Joystick
- **x** : int (-127 à +127)
- **y** : int (-127 à +127)
- **z** : int (-127 à +127) - rotation baton joystick
- **button** : booléen

#### Levier de vitesse (GearShift)
- **position** : entier (0-3)
- **mode** : enum ["SEMITONE", "THIRD", "MINOR_SIXTH", "OCTAVE"]

#### Fader
- **value** : entier (0-127)

#### Pédale de modulation (ModPedal)
- **value** : entier (0-127)
- **percent** : flottant (0.0-100.0)

#### Pad
- **velocity** : entier (0-127)
- **aftertouch** : entier (0-127)
- **active** : booléen
- **x** : entier (0-1)
- **y** : entier (0-1)

## Flux de données

### Phase 1 - Infrastructure de base
1. **ConfigController** charge config.js au démarrage
2. **WebSocketController** se connecte au serveur défini dans la config
3. **WebSocketController** reçoit les messages avec la note MIDI
4. **SirenController** :
   - Récupère la configuration de la sirène active
   - Limite la note selon le mode et l'ambitus
   - Calcule la fréquence avec transposition
   - Calcule les RPM selon le nombre de sorties
5. **SirenDisplay** affiche Hz et RPM avec des afficheurs LED 3D

### Phase 2 - Visualisation musicale
1. **MusicalStaff3D** affiche une portée musicale en 3D
   - Gère le mode restricted via sirenInfo passé directement
   - Utilise restrictedMax si mode="restricted"
2. **AmbitusDisplay3D** affiche toutes les notes de l'ambitus sur la portée
3. **NoteCursor3D** suit la note actuelle avec un curseur vertical dynamique
4. **NoteProgressBar3D** affiche la progression dans l'ambitus
5. **LedgerLines3D** ajoute des lignes supplémentaires pour les notes hors portée
6. **Clef3D** affiche la clé de sol ou de fa


### Phase 3 - Contrôleurs visuels
- Les composants reçoivent directement sirenInfo pour simplifier les bindings
- ControllersPanel gère la disposition des indicateurs
- Esthétique à valider pour terminer cette phase


### Format du message WebSocket
```json
{
    "device": "MUSIC_VISUALIZER",
    "midiNote": 69.5,
    "controllers": {
        "wheel": {
            "position": 45,
            "velocity": 10.5
        },
        "joystick": {
            "x": 0.0,
            "y": 0.0,
            "z": 0.0,
            "button": false
        },
        "gearShift": {
            "position": 2,
            "mode": "THIRD"
        },
        "fader": {
            "value": 64,
            "percent": 50.0,
            "curve": "LINEAR"
        },
        "modPedal": {
            "value": 0,
            "percent": 0.0,
            "calibratedMin": 0,
            "calibratedMax": 127
        },
        "pad": {
            "velocity": 0,
            "aftertouch": 0,
            "active": false,
            "x": 0,
            "y": 0
        }
    }
}
```

## Conversions mathématiques

### Note MIDI vers fréquence (avec transposition)
```
noteTransposée = noteMIDI + (transposition × 12)
fréquence = 440 × 2^((noteTransposée - 69) / 12)
```

### Fréquence vers RPM
```
RPM = (fréquence × 60) / nombreDeSorties
```

### Limitation de la note MIDI
- **Mode restricted** : min ≤ note ≤ restrictedMax
- **Mode admin** : min ≤ note ≤ max

## Théorie musicale - Positionnement sur la portée

### Système diatonique (7 notes)

Le calcul des positions Y utilise la **gamme diatonique** (Do, Ré, Mi, Fa, Sol, La, Si) plutôt que chromatique (12 demi-tons). Chaque position diatonique = une ligne ou un interligne.

#### Position diatonique
```javascript
// Note naturelle de la classe (0-11 MIDI → 0-6 diatonique)
positionDiatonique = octave × 7 + noteDiatonique

// Espacement vertical
positionY = différenceDiatonique × 0.5 × lineSpacing
```

### Clé de Sol (treble) 🎼

**Note de référence** : Sol4 (MIDI 67)  
**Position** : 2ème ligne (Y = -1 × lineSpacing)

**Les 5 lignes** (de bas en haut) :
| Ligne | Note | MIDI | Position Y |
|-------|------|------|------------|
| 1 | Mi4 | 64 | -2 × lineSpacing |
| 2 | Sol4 | 67 | -1 × lineSpacing (référence) |
| 3 | Si4 | 71 | 0 (ligne du milieu) |
| 4 | Ré5 | 74 | +1 × lineSpacing |
| 5 | Fa5 | 77 | +2 × lineSpacing |

**Position du modèle 3D** : Origine (0,0,0) sur la boucle qui entoure Sol4

### Clé de Fa (bass) 🎵

**Note de référence** : Fa3 (MIDI 53)  
**Position** : 4ème ligne (Y = +1 × lineSpacing)

**Les 5 lignes** (de bas en haut) :
| Ligne | Note | MIDI | Position Y |
|-------|------|------|------------|
| 1 | Sol2 | 43 | -2 × lineSpacing |
| 2 | Si2 | 47 | -1 × lineSpacing |
| 3 | Ré3 | 50 | 0 (ligne du milieu) |
| 4 | Fa3 | 53 | +1 × lineSpacing (référence) |
| 5 | La3 | 57 | +2 × lineSpacing |

**Position du modèle 3D** : Origine (0,0,0) entre les deux points, sur la ligne Fa3

### Notes altérées (dièses/bémols)

Les notes altérées **partagent la même position Y** que leur note naturelle voisine :
- Do# / Réb → position de Do ou Ré (selon contexte)
- Les altérations sont représentées visuellement par des symboles ♯ ou ♭ (non implémenté actuellement)

## État actuel du développement

### Phase 1 - Infrastructure de base ✅
- [X] Créer le composant NumberDisplay3D pour afficher Hz et RPM
- [X] Adapter SirenDisplay pour afficher RPM et Hz côte à côte -> reparer les Hz
- [X] Implémenter la conversion MIDI vers fréquence dans MusicUtils
- [X] Créer config.js avec les données des sirènes
- [X] Créer ConfigController pour charger la configuration
- [X] Adapter SirenController pour utiliser la configuration
- [X] Tester les conversions avec transposition et calcul RPM
- [X] Connexion WebSocket fonctionnelle

### Phase 2 - Portée musicale ✅
- [X] Créer le composant MusicalStaff3D avec portée 5 lignes
- [X] Implémenter l'affichage des notes sur la portée (AmbitusDisplay3D)
- [X] Créer le curseur de note actuelle (NoteCursor3D)
- [X] Barre de progression horizontale (NoteProgressBar3D)
- [X] Affichage du nom de note avec LEDText3D
- [X] Ajouter l'option d'affichage dans config.js (displayConfig.components.musicalStaff)
- [X] Support des minuscules dans LEDText3D -> à corriger
- [X] Support des caractères accentués dans LEDText3D -> à revoir
- [X] Lignes supplémentaires automatiques (LedgerLines3D)
- [X] Support des clés de sol et fa (Clef3D) -> modèle 3D intégré
- [X] Calculateur de positions des notes (NotePositionCalculator)
- [X] Ajouter le cercle avec nom de sirène

### Phase 3 - Contrôleurs visuels 🎮
- [X] Composant ControllersPanel (panneau général)
- [X] Composant WheelIndicator (position + mode) -> Esthétique à valider
- [X] Composant JoystickIndicator (X/Y/Z + bouton)
- [X] Composant GearShiftIndicator (4 positions)
- [X] Composant FaderIndicator
- [X] Composant PedalIndicator
- [X] Composant PadIndicator (vélocité + aftertouch)

**Note Phase 3** : L'esthétique des composants doit être validée avant de passer à la phase suivante

### Phase 4 - Administration ✅
- [X] Créer le composant AdminPanel avec authentification
- [X] Implémenter l'authentification par mot de passe
- [X] Interface de sélection de sirène avec affichage dynamique
- [X] Changement de mode (restricted/admin) avec ajustement de l'ambitus
- [X] Configuration de la note max en mode restricted (restrictedMax)
- [X] Configuration de la visibilité des composants
- [X] Synchronisation WebSocket bidirectionnelle avec PureData
- [X] Envoyer les changements de paramètres (PARAM_CHANGED)
- [X] Recevoir les mises à jour individuelles (PARAM_UPDATE)
- [X] REQUEST_CONFIG envoyé à la connexion
- [X] Support des messages binaires
- [X] Options d'affichage avancées
- [X] Section Couleurs (LED, portée, contrôleurs)
- [X] Section Tailles (afficheurs, notes, curseur)
- [X] ColorPicker réutilisable avec envoi WebSocket
- [X] Transposition d'affichage par sirène (displayOctaveOffset)
- [X] Contrôle dans l'interface admin (-4 à +4 octaves)
- [X] Application correcte sur la portée musicale

#### Nouvelles fonctionnalités Phase 4
- **displayOctaveOffset** : Permet de décaler l'affichage des notes sur la portée indépendamment de la transposition audio
- **ColorPicker** : Composant réutilisable pour sélectionner les couleurs avec synchronisation WebSocket
- **Sections avancées** : AdvancedColors et AdvancedSizes pour personnaliser l'apparence

### Phase 5 - Système de priorité console ✅
- [X] Implémentation du système de priorité console/pupitre
- [X] Messages WebSocket CONSOLE_CONNECT/DISCONNECT
- [X] Blocage des modifications locales quand console connectée
- [X] Désactivation du panneau admin en mode console
- [X] Bandeau visuel "Console connectée"
- [X] Paramètre `source` pour éviter les boucles de communication
- [X] Mode fretté configurable par sirène individuellement
- [X] Échelle UI configurable via WebSocket

### Phase 6 - Intégration finale 🚀
- [ ] Tests avec toutes les sirènes
- [ ] Optimisations de performance
- [ ] Documentation utilisateur
- [ ] Améliorer le support des minuscules dans LEDText3D
- [ ] Améliorer le support des caractères accentués dans LEDText3D
- [X] Finaliser le dessin des clefs musicales (Clef3D avec modèle 3D)
- [ ] Implémenter zoom sur ambitus selon levier de vitesse (octave=>tout l'ambitus, sixte, tierce, demi-ton => 2 tours de volant)


## Modèles 3D - Conversion .obj vers .mesh

### Outil balsam de Qt Quick 3D

Qt Quick 3D utilise des fichiers `.mesh` optimisés pour la performance. L'outil `balsam` convertit les modèles 3D depuis divers formats (.obj, .fbx, .gltf) vers le format `.mesh`.

#### Localisation de l'outil

```bash
# macOS
$HOME/Qt/6.10.0/macos/bin/balsam

# Linux
$HOME/Qt/6.10.0/gcc_64/bin/balsam

# Windows
C:\Qt\6.10.0\msvc2019_64\bin\balsam.exe

# Rechercher balsam automatiquement
find $HOME/Qt -name balsam
```

#### Commandes de conversion

```bash
# Conversion de base
balsam source.obj destination.mesh

# Avec optimisation (recommandé pour la production)
balsam --optimize source.obj destination.mesh

# Avec génération de normales et tangentes
balsam --optimize --generateNormals --generateTangents source.obj destination.mesh

# Afficher l'aide complète
balsam --help
```

#### Workflow réel pour les clés musicales

⚠️ **Note importante** : `balsam` crée un sous-dossier `meshes/` contenant le fichier `.mesh` avec un nom basé sur l'objet 3D interne. Il faut récupérer et renommer ce fichier.

```bash
# Se placer dans le dossier des meshes
cd SirenePupitre/QML/utils/meshes

# 1. Convertir la clé de Sol
$HOME/Qt/6.10.0/macos/bin/balsam TrebleKey.obj TrebleKey.mesh

# 2. Récupérer le fichier généré (chercher dans meshes/)
cp ./meshes/*.mesh ./TrebleKey.mesh

# 3. Nettoyer les fichiers temporaires
rm -f TrebleKey.qml
rm -rf ./meshes/

# 4. Répéter pour la clé de Fa
$HOME/Qt/6.10.0/macos/bin/balsam BassKey.obj BassKey.mesh
cp ./meshes/*.mesh ./BassKey.mesh
rm -f BassKey.qml
rm -rf ./meshes/

# 5. Les fichiers sont prêts avec leurs noms finaux
ls -lh *.mesh
```

**Résultat attendu** :
- `TrebleKey.mesh` (~200KB) - Clé de Sol
- `BassKey.mesh` (~95KB) - Clé de Fa

#### Script automatisé (recommandé)

Pour simplifier, utilisez les scripts fournis :

```bash
# Convertir un seul fichier
./scripts/convert-mesh.sh TrebleKey.obj TrebleKey.mesh

# Convertir les deux clés musicales automatiquement
./scripts/convert-clefs.sh
```

Les scripts gèrent automatiquement :
- ✅ Détection de l'outil balsam
- ✅ Récupération du fichier dans le sous-dossier meshes/
- ✅ Nettoyage des fichiers temporaires
- ✅ Affichage du résultat

#### ⚠️ Important : Placement du point d'origine dans le modèle 3D

Lors de la création du modèle 3D dans Blender ou autre logiciel :

**Clé de Sol (treble)** :
- Placer l'origine (0,0,0) sur la **boucle centrale** qui entoure la ligne Sol4
- Cette boucle doit croiser exactement la 2ème ligne de la portée

**Clé de Fa (bass)** :
- Placer l'origine (0,0,0) **entre les deux points**, sur la ligne Fa3
- Les deux points doivent encadrer la 4ème ligne de la portée

Cette approche simplifie grandement le positionnement dans le code QML, car la position Y du Node correspond directement à la ligne de référence de la clé.

#### Intégration dans le projet

Après conversion, ajouter les fichiers dans `data.qrc` :

```xml
<file>QML/utils/meshes/TrebleKey.mesh</file>
<file>QML/utils/meshes/BassKey.mesh</file>
```

Et référencer dans le code QML :

```qml
Model {
    source: clefType === "treble" 
        ? "qrc:/QML/utils/meshes/TrebleKey.mesh"
        : "qrc:/QML/utils/meshes/BassKey.mesh"
}
```

## Scripts de développement et déploiement

Le projet inclut un ensemble de scripts bash dans le dossier `scripts/` pour automatiser le développement et le déploiement.

### 📁 Scripts disponibles

#### 🔨 `build.sh` - Build WebAssembly
Build le projet pour WebAssembly uniquement.

```bash
./scripts/build.sh web          # Build WebAssembly
./scripts/build.sh clean        # Nettoyer les dossiers de build
./scripts/build.sh help         # Afficher l'aide
```

#### 🚀 `dev.sh` - Développement web
Script de développement qui combine build, serveur et ouverture de Chrome.

```bash
./scripts/dev.sh web            # Build + serveur + Chrome
./scripts/dev.sh server         # Serveur + Chrome (si build déjà fait)
./scripts/dev.sh help           # Afficher l'aide
```

#### 🌐 `start-server.sh` - Serveur Node.js
Démarre le serveur Node.js pour le développement WebAssembly.

```bash
./scripts/start-server.sh       # Serveur sur port 8000
./scripts/start-server.sh 8080  # Serveur sur port 8080
```

#### 🍓 `start-raspberry.sh` - Raspberry Pi 5
Script optimisé pour Raspberry Pi 5 avec Chrome et PureData.

```bash
./scripts/start-raspberry.sh start    # Application complète
./scripts/start-raspberry.sh server   # Serveur seulement
./scripts/start-raspberry.sh stop     # Arrêt de tous les processus
```

### 🎯 Workflow de développement

#### Développement Web (WebAssembly)
```bash
# Développement complet (build + serveur + Chrome)
./scripts/dev.sh web

# Ou étape par étape
./scripts/build.sh web
./scripts/start-server.sh
# Ouvrir Chrome manuellement sur http://localhost:8000
```

#### Déploiement Raspberry Pi 5
```bash
# Démarrage complet (serveur + PureData + Chrome)
./scripts/start-raspberry.sh start

# Arrêt de tous les processus
./scripts/start-raspberry.sh stop
```

### 📋 Dépendances requises

#### Pour le développement web
- CMake (3.16+)
- Qt6 pour WebAssembly (wasm_singlethread) avec qt-cmake
- Node.js
- Google Chrome (ou Chromium)

#### Pour Raspberry Pi 5
- Chromium-browser (installé par défaut sur Raspberry Pi OS)
- PureData (pd)
- Node.js

### 📖 Documentation complète
Voir `scripts/README.md` pour la documentation détaillée de tous les scripts.


## Installation sur Raspberry Pi

### Configuration du démarrage automatique (crontab)

Pour lancer automatiquement SirenePupitre au démarrage du Raspberry Pi, utilisez crontab avec la tâche `@reboot`.

#### Étapes d'installation

1. **Cloner le repository sur le Raspberry Pi**
```bash
cd /home/sirenateur/dev/src/mecaviv
git clone https://github.com/patricecolet/mecaviv-qml-ui.git
cd mecaviv-qml-ui/SirenePupitre
```

2. **Configurer le démarrage automatique**
```bash
# Éditer le crontab
crontab -e

# Ajouter cette ligne à la fin du fichier :
@reboot /home/sirenateur/dev/src/mecaviv/mecaviv-qml-ui/SirenePupitre/scripts/start-raspberry.sh
```

3. **Sauvegarder et quitter** (généralement Ctrl+O puis Ctrl+X pour nano)

#### Ce que fait le script au démarrage

Le script `start-raspberry.sh` effectue automatiquement :
1. ✅ **Configuration IP statique** (si nécessaire)
2. ✅ **Configuration du routage réseau** (WiFi prioritaire, Ethernet secondaire avec métrique 700)
3. ✅ **Démarrage du serveur Node.js** (port 8000)
4. ✅ **Lancement de PureData** (patch M645.pd)
5. ✅ **Ouverture de Chromium** en mode kiosk

#### Vérifier le démarrage automatique

```bash
# Lister les tâches cron configurées
crontab -l

# Voir les logs de démarrage en temps réel
tail -f /home/sirenateur/sirene-boot.log

# Vérifier les processus actifs
ps aux | grep node
ps aux | grep pd
ps aux | grep chromium
```

#### Configuration réseau

Le script configure automatiquement le routage pour :
- **WiFi** : Prioritaire pour l'accès Internet
- **Ethernet** : Secondaire (métrique 700) pour SSH depuis votre Mac

Cette configuration permet :
- ✅ Accès SSH via Ethernet depuis le Mac
- ✅ Accès Internet via WiFi
- ✅ Pas de conflit entre les interfaces

#### Désactiver le démarrage automatique

Si vous souhaitez désactiver le démarrage automatique :
```bash
crontab -e
# Commenter la ligne avec # ou la supprimer
# @reboot /home/sirenateur/dev/src/mecaviv/mecaviv-qml-ui/SirenePupitre/scripts/start-raspberry.sh
```

#### Arrêter manuellement les services

```bash
# Arrêter tous les processus
pkill -f "node server.js"
pkill -f "pd -nogui"
pkill -f "chromium-browser"
```


## Compilation et déploiement

> **💡 Recommandé :** Utilisez les scripts automatiques dans `scripts/` pour simplifier le processus.

### Desktop (méthode manuelle)
```bash
cd build
cmake ..
make
./SirenePupitre
```

### WebAssembly (méthode manuelle)
```bash
cd build
$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake ..
make
cp appSirenePupitre.* ../webfiles/
cd ../webfiles
node server.js
```

### Méthode automatique (recommandée)
```bash
# Développement web complet
./scripts/dev.sh web

# Ou étape par étape
./scripts/build.sh web
./scripts/start-server.sh
```

## Notes techniques
- **Framework** : Qt 6 avec Qt Quick et Qt Quick 3D
- **Qt Quick 3D** pour les affichages LED en 3D
- **WebSocket** pour la communication temps réel (Qt WebSockets)
- **Antialiasing** : SSAA avec qualité Medium/High pour compatibilité WebGL
- **Format config** : JavaScript au lieu de JSON pour WebAssembly
- **Port serveur** : ws://localhost:10001 (configurable)
- **Portée musicale** : Largeur 1200, position X -100, offset dynamique pour clé/armature
- **Imports Qt 6** : Sans numéro de version (ex: `import QtQuick` au lieu de `import QtQuick 2.15`)
- **Mode restricted** : Géré dans MusicalStaff3D via sirenInfo.restrictedMax
- **Passage de données** : sirenInfo passé directement aux composants pour simplifier les bindings
- **Limitations Qt Quick 3D** : 
  - La propriété `emissiveStrength` n'est pas disponible dans PrincipledMaterial
  - La propriété `emissive` n'est pas disponible dans les composants personnalisés
  - Les PointLight dynamiques (visible on/off) causent une latence importante (~500ms)
- **Optimisation joystick** : Utilisation d'emissiveFactor au lieu de PointLight pour l'effet bouton

#### Note technique sur les bindings
- Les CheckBox utilisent `configController.updateCounter` pour forcer la mise à jour lors des changements via WebSocket
- Nécessaire car Qt ne détecte pas toujours les changements profonds dans les objets JavaScript


## Difficultés rencontrées Phase 4

### Passage des contrôleurs aux sous-composants
Le Loader dans AdminPanel charge les sections de manière asynchrone. Les propriétés `configController` et `webSocketController` doivent être assignées après le chargement :
```qml
Loader {
    onLoaded: {
        if (item) {
            item.configController = root.configController
            if (item.hasOwnProperty("webSocketController")) {
                item.webSocketController = root.webSocketController
            }
        }
    }
}
```

## Problèmes résolus
- ✅ XMLHttpRequest bloqué en local → Utilisation de config.js
- ✅ Warning WebGL DEPTH_STENCIL_ATTACHMENT → SSAA au lieu de MSAA
- ✅ Structure des messages WebSocket adaptée
- ✅ Calcul des positions des notes selon la clé (sol/fa) → Système diatonique avec Sol4 (treble) et Fa3 (bass) comme références
- ✅ Curseur dynamique qui suit la hauteur de la note
- ✅ Lignes supplémentaires n'apparaissant que sur les positions de lignes
- ✅ Gestion du mode restricted dans MusicalStaff3D
- ✅ Latence 500ms sur le bouton du joystick → Suppression de la PointLight dynamique
- ✅ Binding loops dans TabBar → Suppression des bindings circulaires sur width
- ✅ webSocketController null dans les sous-composants → Passage explicite des propriétés
- ✅ Timing Component.onCompleted → Utilisation de onPropertyChanged pour les propriétés asynchrones
- ✅ Fond gris persistant après fermeture admin → Utiliser adminPanel.visible au lieu de isAdminMode pour SirenDisplay
- ✅ Changements de visibilité non appliqués → Ajouter bindings visible dans les composants
- ✅ Chargement des modèles 3D (.obj/.mesh) → Intégration dans data.qrc et CMakeLists.txt
- ✅ Antialiasing configuré → SSAA/MSAA activé dans les vues principales
- ✅ Positionnement des clés 3D → Origine (0,0,0) placée sur la ligne de référence (Sol4/Fa3)


## TODO
- Selection Sirene au démarrage via config