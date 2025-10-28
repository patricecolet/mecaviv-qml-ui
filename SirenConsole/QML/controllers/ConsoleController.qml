import QtQuick 2.15

Item {
    id: consoleController
    
    // Test simple pour voir si le fichier se charge
    Component.onCompleted: {
        // ConsoleController initialisé
        initializeManagers()
    }
    
    // === PROPRIÉTÉS PUBLIQUES ===
    
    // Données du volant P3
    property real volantNote: 60
    property real volantVelocity: 0
    property real volantPitchbend: 8192
    property real volantFrequency: 261.63
    property real volantRpm: 1308.15
    property real volantNoteFloat: 60
    // Exposer les managers pour accès externe
    property alias commandManager: commandManager
    property alias configManager: configManager
    property alias pupitreManager: pupitreManager
    property alias webSocketManager: webSocketManager
    
    // Managers - Utilisation directe des composants
    ConfigManager {
        id: configManager
    }
    
    PresetManager {
        id: presetManager
        configManager: configManager
    }
    
    PupitreManager {
        id: pupitreManager
        configManager: configManager
        webSocketManager: webSocketManager
    }
    
    CommandManager {
        id: commandManager
        pupitreManager: pupitreManager
        webSocketManager: webSocketManager
    }
    
    SireneManager {
        id: sireneManager
    }
    
    SirenRouterManager {
        id: sirenRouterManager
    }
    
    WebSocketManager {
        id: webSocketManager
        consoleController: consoleController
    }
    
    // Exposer les managers publiquement
    property var sireneManager: sireneManager
    property var sirenRouterManager: sirenRouterManager
    
    // Propriétés des pupitres (pour compatibilité avec l'UI existante)
    property string pupitre1Status: "disconnected"
    property string pupitre2Status: "disconnected"
    property string pupitre3Status: "disconnected"
    property string pupitre4Status: "disconnected"
    property string pupitre5Status: "disconnected"
    property string pupitre6Status: "disconnected"
    property string pupitre7Status: "disconnected"
    
    // Objets pupitres pour l'interface (compatibilité) - Réactifs
    property var pupitre1: QtObject {
        property string status: consoleController.pupitre1Status
        property string name: "Pupitre 1"
        property string host: "192.168.1.41"
        property string id: "P1"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre2: QtObject {
        property string status: consoleController.pupitre2Status
        property string name: "Pupitre 2"
        property string host: "192.168.1.42"
        property string id: "P2"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre3: QtObject {
        property string status: "disconnected"
        property string name: "Pupitre 3"
        property string host: "192.168.1.43"
        property string id: "P3"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre4: QtObject {
        property string status: consoleController.pupitre4Status
        property string name: "Pupitre 4"
        property string host: "192.168.1.44"
        property string id: "P4"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre5: QtObject {
        property string status: consoleController.pupitre5Status
        property string name: "Pupitre 5"
        property string host: "192.168.1.45"
        property string id: "P5"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre6: QtObject {
        property string status: consoleController.pupitre6Status
        property string name: "Pupitre 6"
        property string host: "192.168.1.46"
        property string id: "P6"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitre7: QtObject {
        property string status: consoleController.pupitre7Status
        property string name: "Pupitre 7"
        property string host: "192.168.1.47"
        property string id: "P7"
        property int ambitusMin: 48
        property int ambitusMax: 72
        property int motorSpeed: 0
        property real frequency: 440.0
        property int midiNote: 60
        property bool frettedMode: false
        property var sirenes: ({})
    }
    property var pupitres: []

    // Ambitus issus de config.json (lecture directe, fallback 48-72)
    // P1 correspond à sirens[0]
    property int p1AmbitusMin: (configManager && configManager.config && configManager.config.sirens && configManager.config.sirens.length > 0 && configManager.config.sirens[0].ambitus) ? configManager.config.sirens[0].ambitus.min : 48
    property int p1AmbitusMax: (configManager && configManager.config && configManager.config.sirens && configManager.config.sirens.length > 0 && configManager.config.sirens[0].ambitus) ? configManager.config.sirens[0].ambitus.max : 72
    
    // Propriétés des presets
    property var presets: []
    property string currentPreset: ""
    
    // État de l'application
    property bool isInitialized: false
    property bool isConnected: false
    property int connectedPupitresCount: 0
    
    // Fonction pour tester le séquenceur
    function testSequencer(sireneIds) {
        if (sireneManager) {
            sireneManager.setSequencerSirenes(sireneIds || [])
        }
    }
    
    // === SIGNALS ===
    
    signal initializationComplete()
    signal connectionStatusChanged(bool connected)
    signal pupitreStatusChanged(string pupitreId, string status)
    signal volantDataChanged(int note, int velocity, int pitchbend, real frequency, real rpm)
    signal presetLoaded(string presetName)
    signal presetsListChanged(var presetsList)
    signal errorOccurred(string error)
    
    // === TIMER DE VÉRIFICATION ===
    Timer {
        id: statusCheckTimer
        interval: 2000 // Vérifier toutes les 2 secondes (backup)
        running: true
        repeat: true
        onTriggered: {
            if (consoleController.webSocketManager) {
                consoleController.webSocketManager.checkPupitresStatus()
            }
        }
    }
    
    // === INITIALISATION ===
    
    // Initialisation déplacée dans le premier Component.onCompleted
    
    function initializeManagers() {
        
        // Connecter les signaux
        connectSignals()
        
        // Initialiser les pupitres
        if (configManager && configManager.isLoaded) {
            initializePupitres()
        } else {
            // Attendre que la configuration soit chargée
            if (configManager) {
                configManager.configLoaded.connect(function(config) {
                    initializePupitres()
                })
            }
        }
        
        // Charger les presets au démarrage
        if (presetManager) {
            presetManager.loadPresetsFromStorage()
        }
        
        // Construire le modèle pupitres depuis la config
        buildPupitresFromConfig()
    }
    
    function connectSignals() {
        // ConfigManager
        if (configManager) {
            configManager.configError.connect(function(error) {
                errorOccurred("Configuration: " + error)
            })
        }
        
        // PresetManager
        if (presetManager) {
            presetManager.presetsListChanged.connect(function(presetsList) {
                presets = presetsList
                presetsListChanged(presetsList) // Propager le signal
            })
            
            presetManager.presetLoaded.connect(function(presetName) {
                currentPreset = presetName
                presetLoaded(presetName)
            })
            
            presetManager.presetError.connect(function(error) {
                errorOccurred("Preset: " + error)
            })
        }
        
        // PupitreManager
        if (pupitreManager) {
            pupitreManager.pupitreConnected.connect(function(pupitreId) {
                updateConnectionStatus()
                updatePupitreStatus(pupitreId, "connected")
            })
            
            pupitreManager.pupitreDisconnected.connect(function(pupitreId) {
                updateConnectionStatus()
                updatePupitreStatus(pupitreId, "disconnected")
            })
            
            pupitreManager.pupitreStatusChanged.connect(function(pupitreId, status) {
                console.log("🔍 pupitreStatusChanged:", pupitreId, "=", status)
                pupitreStatusChanged(pupitreId, status)
                updatePupitreStatus(pupitreId, status)
            })
            
        }
        
        // CommandManager
        if (commandManager) {
            commandManager.commandError.connect(function(command, error) {
                errorOccurred("Commande " + command + ": " + error)
            })
        }
    }
    
    function initializePupitres() {
        if (!pupitreManager || !configManager) {
            // Managers non disponibles
            return false
        }
        
        
        // Initialiser les pupitres via PupitreManager
        if (pupitreManager.initializePupitres()) {
            // Mettre à jour les propriétés pour compatibilité
            pupitres = pupitreManager.pupitres
            
            // Mapper les pupitres individuels
            pupitre1 = pupitres.length > 0 ? pupitres[0] : null
            pupitre2 = pupitres.length > 1 ? pupitres[1] : null
            pupitre3 = pupitres.length > 2 ? pupitres[2] : null
            pupitre4 = pupitres.length > 3 ? pupitres[3] : null
            pupitre5 = pupitres.length > 4 ? pupitres[4] : null
            pupitre6 = pupitres.length > 5 ? pupitres[5] : null
            pupitre7 = pupitres.length > 6 ? pupitres[6] : null
            
            // Auto-connexion si activée
            if (configManager.config && configManager.config.console && configManager.config.console.autoConnect) {
                connectAllPupitres()
            }
            
            isInitialized = true
            initializationComplete()
            return true
        }
        
        return false
    }

    // Construire le tableau pupitres[] depuis config.json
    function buildPupitresFromConfig() {
        var built = []
        if (configManager && configManager.config && configManager.config.sirens) {
            for (var i = 0; i < configManager.config.sirens.length; i++) {
                var s = configManager.config.sirens[i]
                built.push({
                    id: "P" + (i + 1),
                    status: "disconnected",
                    ambitusMin: (s.ambitus && s.ambitus.min !== undefined) ? s.ambitus.min : 48,
                    ambitusMax: (s.ambitus && s.ambitus.max !== undefined) ? s.ambitus.max : 72,
                    currentNote: 60.0,
                    currentHz: 440.0,
                    currentRpm: 0,
                    velocity: 0
                })
            }
        }
        pupitres = built
    }
    
    // === MÉTHODES PUBLIQUES (COMPATIBILITÉ) ===
    
    // Gestion des connexions
    function connectAllPupitres() {
        if (pupitreManager) {
            return pupitreManager.connectAllPupitres()
        }
        return false
    }
    
    function disconnectAllPupitres() {
        if (pupitreManager) {
            return pupitreManager.disconnectAllPupitres()
        }
        return false
    }
    
    function connectPupitre(pupitreId) {
        if (pupitreManager) {
            return pupitreManager.connectPupitre(pupitreId)
        }
        return false
    }
    
    function disconnectPupitre(pupitreId) {
        if (pupitreManager) {
            return pupitreManager.disconnectPupitre(pupitreId)
        }
        return false
    }
    
    // Gestion des presets
    function loadPreset(presetName) {
        if (presetManager) {
            return presetManager.loadPreset(presetName)
        }
        return false
    }
    
    function createPresetFromCurrent(presetName, presetDescription) {
        if (presetManager) {
            return presetManager.createPresetFromCurrent(presetName, presetDescription)
        }
        return false
    }
    
    function deletePreset(presetName) {
        if (presetManager) {
            return presetManager.deletePreset(presetName)
        }
        return false
    }
    
    function savePresetsToStorage() {
        if (presetManager) {
            // Les presets sont automatiquement sauvegardés via l'API
            return true
        }
        return false
    }
    
    function loadPresetsFromStorage() {
        if (presetManager) {
            presetManager.loadPresetsFromStorage()
            return true
        }
        return false
    }
    
    // Gestion des pupitres
    function getCurrentPupitre() {
        if (pupitreManager) {
            return pupitreManager.getCurrentPupitre()
        }
        return null
    }
    
    function setCurrentPupitre(index) {
        if (pupitreManager) {
            return pupitreManager.setCurrentPupitre(index)
        }
        return false
    }
    
    function getPupitreById(pupitreId) {
        if (pupitreManager) {
            return pupitreManager.getPupitreById(pupitreId)
        }
        return null
    }
    
    // === MÉTHODES DE COMPATIBILITÉ POUR L'UI ===
    
    // Méthodes pour l'interface utilisateur
    function sendMidiCommand(command) {
        if (webSocketManager && webSocketManager.connected) {
            return webSocketManager.sendMidiCommand(command)
        }
        return false
    }
    
    function sendPureDataCommand(command) {
        if (webSocketManager && webSocketManager.connected) {
            return webSocketManager.sendPureDataCommand(command)
        }
        return false
    }
    
    function requestStatus() {
        if (webSocketManager && webSocketManager.connected) {
            return webSocketManager.requestStatus()
        }
        return false
    }
    
    // Contrôle des sirènes
    function controlSirene(pupitreId, sireneNumber, enabled, ambitusRestreint, modeFrette) {
        if (pupitreManager) {
            return pupitreManager.controlSirene(pupitreId, sireneNumber, enabled, ambitusRestreint, modeFrette)
        }
        return false
    }
    
    function setPupitreAmbitus(pupitreId, min, max) {
        if (pupitreManager) {
            return pupitreManager.setPupitreAmbitus(pupitreId, min, max)
        }
        return false
    }
    
    function setPupitreFrettedMode(pupitreId, frettedMode) {
        if (pupitreManager) {
            return pupitreManager.setPupitreFrettedMode(pupitreId, frettedMode)
        }
        return false
    }
    
    // Contrôle des sorties
    function setPupitreOutputSettings(pupitreId, settings) {
        if (configManager) {
            return configManager.setOutputSettings(pupitreId, settings)
        }
        return false
    }
    
    function getPupitreOutputSettings(pupitreId) {
        if (configManager) {
            return configManager.getOutputSettings(pupitreId)
        }
        return { vstEnabled: false, udpEnabled: false, rtpMidiEnabled: false }
    }
    
    // Mapping des contrôleurs
    function setPupitreControllerMapping(pupitreId, controllerType, cc, curve) {
        if (commandManager) {
            return commandManager.setControllerMapping(pupitreId, controllerType, cc, curve)
        }
        return false
    }
    
    function getPupitreControllerMapping(pupitreId) {
        if (configManager) {
            return configManager.getControllerMapping(pupitreId)
        }
        return {}
    }
    
    // Commandes
    function sendCommand(pupitreId, command, parameters) {
        if (commandManager) {
            return commandManager.executeCommand(pupitreId, command, parameters)
        }
        return false
    }
    
    // === MÉTHODES UTILITAIRES ===
    
    function updateConnectionStatus() {
        if (pupitreManager) {
            var stats = pupitreManager.getPupitresStats()
            connectedPupitresCount = stats.connected
            isConnected = stats.connected > 0
            connectionStatusChanged(isConnected)
        }
    }
    
    // Mettre à jour les données du volant (compat ancienne signature)
    function updateVolantData(noteFloat, velocity, pitchbend, frequency, rpm) {
        // Par défaut, considérer P1
        updatePupitreVolantData("P1", noteFloat, frequency, rpm, velocity)
    }

    // Nouvelle API: mise à jour d'un pupitre par id avec note continue
    function updatePupitreVolantData(pupitreId, noteFloat, frequency, rpm, velocity) {
        if (!pupitres || pupitres.length === 0) return
        for (var i = 0; i < pupitres.length; i++) {
            if (pupitres[i].id === pupitreId) {
                var p = pupitres[i]
                p.currentNote = noteFloat
                p.currentHz = frequency
                p.currentRpm = rpm
                p.velocity = velocity
                pupitres[i] = p // forcer la notification
                break
            }
        }
        // Maintenir les anciennes props pour compat (pilotent P1)
        if (pupitreId === "P1") {
            volantNoteFloat = noteFloat
            volantNote = Math.round(noteFloat)
            volantVelocity = velocity
            volantFrequency = frequency
            volantRpm = rpm
        }
    }
    
    function updatePupitreStatus(pupitreId, status) {
        // Mise à jour statut pupitre
        
        // Mettre à jour les propriétés de statut
        if (pupitreId === "P1") {
            pupitre1Status = status
            // P1 mis à jour
        } else if (pupitreId === "P2") {
            pupitre2Status = status
            // P2 mis à jour
        } else if (pupitreId === "P3") {
            pupitre3Status = status
            // P3 mis à jour
        } else if (pupitreId === "P4") {
            pupitre4Status = status
            // P4 mis à jour
        } else if (pupitreId === "P5") {
            pupitre5Status = status
            // P5 mis à jour
        } else if (pupitreId === "P6") {
            pupitre6Status = status
            // P6 mis à jour
        } else if (pupitreId === "P7") {
            pupitre7Status = status
            // P7 mis à jour
        }
        pupitreStatusChanged(pupitreId, status)
    }
    
    
    
    
    
    function getPupitresStats() {
        if (pupitreManager) {
            return pupitreManager.getPupitresStats()
        }
        return { total: 0, enabled: 0, connected: 0, disconnected: 0, connecting: 0 }
    }
    
    function getConnectedPupitres() {
        if (pupitreManager) {
            return pupitreManager.getConnectedPupitres()
        }
        return []
    }
    
    function getEnabledPupitres() {
        if (pupitreManager) {
            return pupitreManager.getEnabledPupitres()
        }
        return []
    }
    
    // Configuration
    function getConfiguration() {
        if (configManager) {
            return configManager.config
        }
        return null
    }
    
    function exportConfiguration() {
        if (configManager) {
            return configManager.exportConfig()
        }
        return null
    }
    
    function importConfiguration(configJson) {
        if (configManager) {
            return configManager.importConfig(configJson)
        }
        return false
    }
    
    // Presets
    function getPresetNames() {
        if (presetManager) {
            return presetManager.getPresetNames()
        }
        return []
    }
    
    function presetExists(presetName) {
        if (presetManager) {
            return presetManager.presetExists(presetName)
        }
        return false
    }
    
    // === PROPRIÉTÉS DE COMPATIBILITÉ ===
    
    // Pour maintenir la compatibilité avec l'UI existante
    property int currentPupitreIndex: pupitreManager ? pupitreManager.currentPupitreIndex : 0
    property int pupitresCount: pupitres ? pupitres.length : 0
    property bool isReady: isInitialized
    
    // Méthodes de compatibilité
    function refreshPupitres() {
        if (pupitreManager) {
            pupitreManager.syncWithConfig()
            pupitres = pupitreManager.pupitres
        }
    }
    
    function resetPupitres() {
        if (pupitreManager && configManager) {
            pupitreManager.disconnectAllPupitres()
            pupitreManager.initializePupitres()
            pupitres = pupitreManager.pupitres
        }
    }
}