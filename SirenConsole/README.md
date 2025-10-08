# SirenConsole - Console de Contrôle des Pupitres

## 🎯 Vue d'ensemble

**SirenConsole** est une application de contrôle centralisée pour gérer jusqu'à 7 instances de **SirenePupitre** (interprètes). Elle fonctionne comme un chef d'orchestre numérique, permettant de superviser, configurer et contrôler tous les pupitres depuis une interface unique.

## 🏗️ Architecture du Système

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

## 🚀 Fonctionnalités Principales

### 1. **Vue d'Ensemble des Pupitres**
- Affichage de tous les pupitres connectés (max 7)
- Statut de connexion en temps réel
- Informations clés : sirènes assignées, contrôleurs, état des connexions
- Interface optimisée pour écran 1080p en plein écran

### 2. **Configuration Centralisée**
- Modification des paramètres de chaque pupitre
- **Assignation exclusive des sirènes** : Une sirène ne peut être assignée qu'à un seul pupitre à la fois
- **Désassignation automatique** : Quand une sirène est assignée à un pupitre, elle est automatiquement retirée des autres
- **Mode "All"** : Application des mêmes réglages à tous les pupitres simultanément
- Configuration des contrôleurs et courbes
- Chargement de presets de configuration

### 3. **Monitoring en Temps Réel**
- Visualisation de l'état de chaque pupitre
- Messages MIDI en temps réel via WebSocket binaire
- État des contrôleurs physiques
- Logs centralisés de tous les pupitres

### 4. **Priorité Console**
- Quand la console est connectée à un pupitre :
  - La console a priorité sur les contrôles locaux
  - Le panneau admin du pupitre est désactivé
  - Bandeau "Console connectée" affiché sur le pupitre

## 🛠️ Technologies Utilisées

- **Qt 6** avec **QtQuick 3D** pour l'interface
- **QML** pour la logique d'interface
- **WebSocket** pour la communication temps réel
- **Node.js** pour le serveur web
- **WebAssembly** pour l'exécution dans le navigateur
- **JavaScript** pour la configuration et les presets
- **PureData** pour le routage MIDI et la communication avec les sirènes

## 📁 Structure du Projet

```
SirenConsole/
├── QML/
│   ├── Main.qml                    # Application principale
│   ├── components/                 # Composants UI
│   │   ├── OverviewPage.qml        # Page vue d'ensemble
│   │   ├── ConfigPage.qml          # Page configuration
│   │   ├── LogsPage.qml            # Page logs
│   │   ├── OverviewRow.qml         # Rangée pupitre (vue d'ensemble)
│   │   ├── SirenConfigRow.qml      # Rangée configuration sirène
│   │   ├── AmbitusBar.qml          # Barre de progression ambitus
│   │   ├── PresetSelector.qml      # Sélecteur de presets
│   │   ├── LogViewer.qml           # Visualiseur de logs
│   │   ├── StatusIndicator.qml     # Indicateur de statut
│   │   ├── PupitreCard.qml         # Carte pupitre (legacy)
│   │   ├── ControlPanel.qml        # Panneau de contrôle
│   │   ├── PupitreViewer.qml       # Visualiseur de pupitre
│   │   └── DataModels.qml          # Modèles de données
│   ├── controllers/                # Contrôleurs
│   │   ├── ConsoleController.qml   # Contrôleur principal
│   │   ├── WebSocketManager.qml    # Gestionnaire WebSocket
│   │   └── ConfigController.qml    # Contrôleur de configuration
│   └── utils/                      # Utilitaires
│       ├── DataModels.qml          # Modèles de données
│       └── NetworkUtils.qml        # Utilitaires réseau
├── scripts/
│   ├── run.sh                      # Script principal (build + serveur + Chrome)
│   ├── build.sh                    # Script de build
│   ├── deploy.sh                   # Script de déploiement (futur)
│   └── test-connections.sh         # Script de test (futur)
├── webfiles/
│   ├── server.js                   # Serveur Node.js
│   ├── qtloader.js                 # Loader Qt WebAssembly
│   └── [fichiers compilés]         # Fichiers WebAssembly
├── config.js                       # Configuration principale
├── CMakeLists.txt                  # Configuration CMake
├── data.qrc                        # Ressources Qt
├── main.cpp                        # Point d'entrée C++
└── README.md                       # Documentation
```

## 🚀 Installation et Utilisation

### Prérequis
- Qt 6.10+ avec WebAssembly
- Node.js 18+
- Chrome/Chromium pour le développement

### Démarrage Rapide
```bash
# Cloner le projet
git clone <repository>
cd SirenConsole

# Lancer l'application (build + serveur + Chrome)
./scripts/run.sh
```

### Scripts Disponibles

#### `./scripts/run.sh` - Script Principal
- Tue les serveurs existants
- Build WebAssembly
- Lance le serveur Node.js (port 8001)
- Ouvre Chrome avec les outils de développement
- Interface tout-en-un pour le développement

#### `./scripts/build.sh` - Build
```bash
./scripts/build.sh web    # Build WebAssembly
./scripts/build.sh desktop # Build desktop (futur)
```

## 🎨 Interface Utilisateur

### Page Vue d'Ensemble
- **7 rangées de pupitres** avec informations clés
- **Sirènes assignées** par pupitre
- **Statut de connexion** en temps réel
- **Boutons d'action** par pupitre

### Page Configuration
- **Sélecteur de presets** en haut avec sauvegarde/suppression
- **Sélecteur de pupitres** avec bouton "All" pour configuration globale
- **Onglets spécialisés** : Sirènes, Contrôleurs, Sorties
- **Configuration détaillée** par pupitre :
  - **Sirènes assignées** avec désassignation automatique
  - **Mode "All"** pour appliquer les mêmes réglages à tous les pupitres
  - Contrôleurs et courbes
  - Paramètres réseau
  - Mode admin

### Page Logs
- **Logs centralisés** de tous les pupitres
- **Filtrage par niveau** (INFO, WARNING, ERROR)
- **Recherche** dans les logs
- **Export** des logs

## 🎯 Fonctionnalités Avancées

### Gestion Intelligente des Sirènes

#### Assignation Exclusive
- **Une sirène = Un pupitre** : Chaque sirène ne peut être assignée qu'à un seul pupitre à la fois
- **Désassignation automatique** : Quand vous assignez une sirène à un pupitre, elle est automatiquement retirée des autres pupitres
- **Interface visuelle** : 
  - 🔵 **Bleu** : Sirène assignée au pupitre actuel
  - ⚫ **Gris** : Sirène disponible
  - 🔴 **Rouge** : Sirène utilisée par le séquenceur

#### Mode "All" - Configuration Globale
- **Bouton "All"** dans le sélecteur de pupitres
- **Application simultanée** : Les réglages s'appliquent à tous les pupitres en même temps
- **Indicateurs visuels** : 
  - 🟠 **Orange** : Contrôles dont les valeurs diffèrent entre pupitres
  - ⚫ **Gris** : Boutons de sirènes désactivés (logique car assignation exclusive)
- **Réglages concernés** : Ambitus, Mode fretté, Contrôleurs

#### Interface Optimisée
- **Boutons compacts** : S1, S2, S3... au lieu de "Sirène 1 Activée" + checkbox
- **Gain d'espace** : Plus de place pour les autres contrôles
- **Feedback immédiat** : Changements visuels instantanés

### Gestion des Presets

#### Sauvegarde et Chargement
- **API REST** : Sauvegarde persistante des presets sur le serveur
- **Interface intuitive** : Boutons "Sauvegarder" et "Supprimer" dans le sélecteur
- **Validation** : Vérification des données avant sauvegarde
- **Synchronisation** : Mise à jour automatique de la liste des presets

## 🔧 Configuration

### Structure des Données

#### Configuration Principale (config.js)
```javascript
const config = {
    // Configuration des pupitres (7 pupitres max)
    pupitres: [
        {
            id: "P1",
            name: "Sirene 1",
            host: "192.168.1.41",     // IP fixe (41-47)
            port: 8000,                 // Port HTTP
            websocketPort: 10001,       // Port WebSocket
            enabled: true,              // Pupitre activé
            ambitus: { min: 48, max: 72 }, // Ambitus musical (C3 à C6)
            frettedMode: false,         // Mode fretté
            motorSpeed: 0,              // Vitesse moteur (RPM)
            frequency: 440,             // Fréquence (Hz)
            midiNote: 60,               // Note MIDI (C4)
            status: "disconnected"      // Statut de connexion
        }
        // ... P2 à P7 (192.168.1.42 à 192.168.1.47)
    ],
    
    // Presets de configuration
    presets: {
        "Concert Standard": {
            description: "Configuration standard pour concert",
            sirenConfig: {
                ambitus: { min: 48, max: 72 },
                frettedMode: false,
                uiScale: 1.0
            },
            uiConfig: {
                controllersPanelVisible: true,
                adminMode: false
            }
        }
        // ... Autres presets
    },
    
    // Configuration de l'interface
    ui: {
        fullScreen: false,
        currentPage: 0,                 // 0=Overview, 1=Config, 2=Logs
        theme: "dark",
        autoConnect: true,
        reconnectInterval: 5000         // ms
    },
    
    // Configuration des couleurs
    colors: {
        background: "#1a1a1a",
        surface: "#2a2a2a",
        primary: "#00ff00",
        secondary: "#ff6b6b",
        accent: "#ffaa00",
        text: "#ffffff",
        textSecondary: "#cccccc"
    }
}
```

### Configuration des Pupitres

#### Paramètres Modifiables
- **Ambitus musical** : Notes MIDI min/max (ex: 48-72 pour C3-C6)
- **Mode fretté** : Force les notes entières (gamme tempérée)
- **Vitesse moteur** : RPM en temps réel
- **Fréquence** : Hz en temps réel
- **Note MIDI** : Note actuelle (0-127)
- **Statut** : Connexion (connected/disconnected/error)
- **Réseau** : Host, port HTTP, port WebSocket

#### Interface de Configuration
- **Sélecteur de presets** : Menu déroulant en haut de la page
- **Scroll global** : Navigation entre les 7 pupitres
- **Contrôles par pupitre** : Sliders, boutons, et sélecteurs
- **Sauvegarde automatique** : Les modifications sont sauvegardées localement

### Gestion des Presets

#### Chargement d'un Preset
1. Sélectionner le preset dans le menu déroulant
2. Cliquer sur "Charger Preset"
3. Tous les pupitres sont mis à jour automatiquement

#### Création d'un Preset
1. Configurer manuellement tous les pupitres
2. Cliquer sur "Sauvegarder Preset"
3. Entrer le nom et la description
4. Le preset est ajouté à la liste

#### Modification d'un Preset
1. Charger le preset à modifier
2. Apporter les modifications nécessaires
3. Cliquer sur "Mettre à Jour Preset"
4. Le preset est mis à jour

### Configuration Réseau

#### Adresses IP des Pupitres
Les adresses IP sont fixes :
```javascript
const pupitres = [
    { host: "192.168.1.41", port: 8000, websocketPort: 10001 },  // Pupitre 1
    { host: "192.168.1.42", port: 8000, websocketPort: 10001 },  // Pupitre 2
    { host: "192.168.1.43", port: 8000, websocketPort: 10001 },  // Pupitre 3
    { host: "192.168.1.44", port: 8000, websocketPort: 10001 },  // Pupitre 4
    { host: "192.168.1.45", port: 8000, websocketPort: 10001 },  // Pupitre 5
    { host: "192.168.1.46", port: 8000, websocketPort: 10001 },  // Pupitre 6
    { host: "192.168.1.47", port: 8000, websocketPort: 10001 }   // Pupitre 7
];
```

#### Ports
- **Port HTTP** : 8000 (interface web SirenePupitre)
- **Port WebSocket** : 10001 (communication temps réel)
- **Port serveur SirenConsole** : 8001

### Sauvegarde et Persistance

#### Sauvegarde Locale
- Les configurations sont sauvegardées dans le navigateur
- Persistance entre les sessions
- Synchronisation automatique

#### Export/Import
- **Export** : Télécharger la configuration actuelle
- **Import** : Charger une configuration sauvegardée
- **Format** : JSON standard

### Validation et Contraintes

#### Contraintes de Valeurs
- **Ambitus Min** : 0 ≤ valeur ≤ 127 (notes MIDI)
- **Ambitus Max** : 0 ≤ valeur ≤ 127 (notes MIDI)
- **Note MIDI** : 0 ≤ valeur ≤ 127
- **Vitesse moteur** : 0 ≤ valeur ≤ 10000 (RPM)
- **Fréquence** : 20 ≤ valeur ≤ 20000 (Hz)
- **Échelle UI** : 0.1 ≤ valeur ≤ 2.0
- **ID Pupitre** : 1 ≤ valeur ≤ 7
- **Port** : 1 ≤ valeur ≤ 65535

#### Validation en Temps Réel
- Vérification des valeurs lors de la saisie
- Messages d'erreur pour valeurs invalides
- Correction automatique des valeurs hors limites
- Validation des adresses IP et ports

## 🌐 Communication WebSocket

### Architecture de Communication
```
SirenConsole ←→ SirenePupitre ←→ PureData
     ↑              ↑              ↑
   JSON          JSON/Binaire    Binaire MIDI
```

### Messages SirenConsole ↔ SirenePupitre (JSON)
```javascript
// Console → Pupitre (Configuration)
{
    "type": "CONSOLE_CONNECT",
    "source": "console"
}

// Console → Pupitre (Paramètres)
{
    "type": "PARAM_UPDATE",
    "path": ["displayConfig", "components", "rpm", "visible"],
    "value": false,
    "source": "console"
}

// Pupitre → Console (Statut)
{
    "type": "PUPITRE_STATUS",
    "pupitreId": "P1",
    "status": "connected",
    "data": {
        "id": "P1",
        "name": "Pupitre 1",
        "ip": "192.168.1.41",
        "port": 10001,
        "status": "connected",
        "assignedSirenes": [1, 2, 3],
        "vstEnabled": true,
        "udpEnabled": true,
        "rtpMidiEnabled": true,
        "controllerMapping": {
            "joystickX": { "cc": 1, "curve": "linear" },
            "joystickY": { "cc": 2, "curve": "parabolic" },
            "fader": { "cc": 3, "curve": "hyperbolic" },
            "selector": { "cc": 4, "curve": "s" },
            "pedalId": { "cc": 5, "curve": "linear" }
        }
    }
}
```

### Messages SirenePupitre ↔ PureData
- **Configuration** : JSON (paramètres, presets)
- **Temps réel** : Binaire MIDI (notes, contrôleurs)

### Messages Temps Réel (MIDI Binaire)
Les données temps réel sont transmises en **binaire** suivant le protocole MIDI :

#### Format des Messages Binaires
```
[PupitreID:1 byte][MIDI Message:3 bytes] = 4 bytes total
```

#### Types de Messages MIDI
```javascript
// Note On/Off
[0x90, note, velocity]  // Note On (Channel 1)
[0x80, note, velocity]  // Note Off (Channel 1)

// Control Change
[0xB0, controller, value]  // Contrôleur (Channel 1)

// Pitch Bend
[0xE0, lsb, msb]  // Pitch Bend (Channel 1)
```

#### Mapping des Contrôleurs
```javascript
// Contrôleurs physiques → MIDI CC
const controllerMapping = {
    joystickX: { cc: 1, curve: "linear" },      // CC 1, courbe linéaire
    joystickY: { cc: 2, curve: "parabolic" },   // CC 2, courbe parabolique
    fader: { cc: 3, curve: "hyperbolic" },      // CC 3, courbe hyperbolique
    selector: { cc: 4, curve: "s" },            // CC 4, courbe S
    pedalId: { cc: 5, curve: "linear" }         // CC 5, courbe linéaire
}

// Types de courbes disponibles
const curveTypes = {
    "linear": "y = x",
    "parabolic": "y = x²",
    "hyperbolic": "y = 1/x",
    "s": "Courbe en S (logarithmique)"
}
```

#### Exemple de Message Binaire Complet
```javascript
// Pupitre 1, Note On (C4, vélocité 127)
[0x01, 0x90, 0x3C, 0x7F]

// Pupitre 2, Control Change (CC 1, valeur 64)
[0x02, 0xB0, 0x01, 0x40]

// Pupitre 3, Pitch Bend (centre)
[0x03, 0xE0, 0x00, 0x40]
```

### Flux de Données
1. **PureData** → **SirenePupitre** : Données MIDI binaires
2. **SirenePupitre** → **SirenConsole** : Données formatées JSON
3. **SirenConsole** → **SirenePupitre** : Commandes de configuration
4. **SirenePupitre** → **PureData** : Paramètres et contrôle

## 🔄 Workflow de Développement

1. **Modification du code QML**
2. **Build automatique** via `./scripts/run.sh`
3. **Test dans Chrome** avec outils de développement
4. **Debug** via console du navigateur
5. **Itération** rapide

## 📊 État du Projet

### ✅ Implémenté
- [x] Architecture de base Qt 6 + QML
- [x] Interface utilisateur complète
- [x] Navigation par onglets (SwipeView)
- [x] Composants factorisés et réutilisables
- [x] Simulation WebSocket pour tests
- [x] Serveur Node.js (port 8001)
- [x] Build WebAssembly
- [x] Scripts de développement
- [x] Configuration des pupitres (7 pupitres)
- [x] Presets de configuration
- [x] Logs centralisés
- [x] Structure de données cohérente
- [x] Validation des paramètres
- [x] Interface responsive

### 🚧 En Cours
- [ ] Connexions WebSocket réelles (quand les pupitres seront sur le réseau)
- [ ] Messages MIDI binaires temps réel
- [ ] Synchronisation des données en temps réel

### 🔮 Futur
- [ ] Déploiement automatisé
- [ ] Tests de connectivité
- [ ] Interface mobile
- [ ] Sauvegarde cloud des configurations
- [ ] Monitoring avancé des pupitres

## 🐛 Debug et Logs

### Console du Navigateur
- Ouvrir F12 dans Chrome
- Onglet "Console" pour voir les logs
- Onglet "Network" pour voir les WebSockets

### Logs Serveur
```bash
# Voir les logs du serveur Node.js
cd webfiles
node server.js
```

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature
3. Commiter les changements
4. Pousser vers la branche
5. Créer une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## 🆘 Support

Pour toute question ou problème :
1. Vérifier les logs de la console du navigateur
2. Consulter la documentation Qt 6
3. Ouvrir une issue sur le repository

---

**SirenConsole** - Console de contrôle centralisée pour SirenePupitre