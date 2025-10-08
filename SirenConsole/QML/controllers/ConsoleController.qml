import QtQuick 2.15

Item {
    id: consoleController
    
    // === PROPRIÉTÉS PUBLIQUES ===
    
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
    
    // Exposer les managers publiquement
    property var sireneManager: sireneManager
    property var sirenRouterManager: sirenRouterManager
    
    property var webSocketManager: null
    
    // Propriétés des pupitres (pour compatibilité avec l'UI existante)
    property var pupitre1: null
    property var pupitre2: null
    property var pupitre3: null
    property var pupitre4: null
    property var pupitre5: null
    property var pupitre6: null
    property var pupitre7: null
    property var pupitres: []
    
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
    signal presetLoaded(string presetName)
    signal presetsListChanged(var presetsList)
    signal errorOccurred(string error)
    
    // === INITIALISATION ===
    
    Component.onCompleted: {
        initializeManagers()
    }
    
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
            })
            
            pupitreManager.pupitreDisconnected.connect(function(pupitreId) {
                updateConnectionStatus()
            })
            
            pupitreManager.pupitreStatusChanged.connect(function(pupitreId, status) {
                pupitreStatusChanged(pupitreId, status)
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
            console.error("❌ Managers non disponibles")
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