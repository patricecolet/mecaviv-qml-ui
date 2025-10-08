import QtQuick 2.15

QtObject {
    id: configManager
    
    // Propriétés
    property var config: null
    property bool isLoaded: false
    property string configSource: "config.js"
    
    // Signaux
    signal configLoaded(var config)
    signal configError(string error)
    
    // Initialisation
    Component.onCompleted: {
        loadConfiguration()
    }
    
    // Charger la configuration
    function loadConfiguration() {
        
        // Essayer de charger depuis config.js d'abord
        if (loadConfigFromFile(configSource)) {
            return
        }
        
        // Fallback vers la configuration par défaut
        loadDefaultConfig()
    }
    
    // Charger depuis un fichier (config.js)
    function loadConfigFromFile(filePath) {
        try {
            // Dans un navigateur, on utiliserait fetch() ou XMLHttpRequest
            // Pour l'instant, on simule le chargement
            
            // TODO: Implémenter le vrai chargement de fichier
            // var xhr = new XMLHttpRequest()
            // xhr.open("GET", filePath)
            // xhr.onreadystatechange = function() { ... }
            
            return false // Pour l'instant, toujours utiliser la config par défaut
        } catch (e) {
            console.error("❌ Erreur chargement config:", e)
            configError("Erreur chargement configuration: " + e.message)
            return false
        }
    }
    
    // Configuration par défaut
    function loadDefaultConfig() {
        
        config = {
            console: {
                name: "Console de Contrôle des Pupitres",
                version: "1.0.0",
                autoConnect: true,
                reconnectInterval: 5000,
                logLevel: "info"
            },
            pupitres: [
                {
                    id: "P1",
                    name: "Pupitre 1",
                    host: "192.168.1.41",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre principal - Salle A",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [1, 2, 3],
                    vstEnabled: true,
                    udpEnabled: true,
                    rtpMidiEnabled: true,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P2",
                    name: "Pupitre 2",
                    host: "192.168.1.42",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre secondaire - Salle B",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P3",
                    name: "Pupitre 3",
                    host: "192.168.1.43",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre de réserve - Salle C",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P4",
                    name: "Pupitre 4",
                    host: "192.168.1.44",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre mobile - Salle D",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P5",
                    name: "Pupitre 5",
                    host: "192.168.1.45",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre de test - Labo",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P6",
                    name: "Pupitre 6",
                    host: "192.168.1.46",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre de démo - Showroom",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P7",
                    name: "Pupitre 7",
                    host: "192.168.1.47",
                    port: 8000,
                    websocketPort: 10001,
                    enabled: true,
                    description: "Pupitre de backup - Stockage",
                    ambitus: { min: 48, max: 72 },
                    frettedMode: false,
                    motorSpeed: 0,
                    frequency: 440,
                    midiNote: 60,
                    status: "disconnected",
                    restrictedMax: 72,
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s curve" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                }
            ],
            ui: {
                theme: "dark",
                layout: "grid",
                columns: 4,
                rows: 2,
                cardSize: {
                    width: 300,
                    height: 200
                },
                colors: {
                    primary: "#2E86AB",
                    secondary: "#A23B72",
                    success: "#F18F01",
                    warning: "#C73E1D",
                    error: "#C73E1D",
                    background: "#1a1a1a",
                    surface: "#2a2a2a",
                    text: "#ffffff"
                }
            },
            logging: {
                enabled: true,
                maxEntries: 1000,
                levels: ["debug", "info", "warning", "error"],
                autoScroll: true,
                showTimestamps: true
            },
            features: {
                bulkOperations: true,
                presets: true,
                scheduling: false,
                analytics: false,
                backup: true
            }
        }
        
        isLoaded = true
        configLoaded(config)
    }
    
    // Obtenir une valeur par chemin
    function getValueAtPath(path, defaultValue) {
        if (!config || !path || path.length === 0) {
            return defaultValue
        }
        
        var current = config
        for (var i = 0; i < path.length; i++) {
            if (current && typeof current === 'object' && path[i] in current) {
                current = current[path[i]]
            } else {
                return defaultValue
            }
        }
        
        return current !== undefined ? current : defaultValue
    }
    
    // Définir une valeur par chemin
    function setValueAtPath(path, value) {
        if (!config || !path || path.length === 0) {
            return false
        }
        
        var current = config
        for (var i = 0; i < path.length - 1; i++) {
            if (!current[path[i]] || typeof current[path[i]] !== 'object') {
                current[path[i]] = {}
            }
            current = current[path[i]]
        }
        
        current[path[path.length - 1]] = value
        return true
    }
    
    // Obtenir les données d'un pupitre
    function getPupitreData(pupitreId) {
        if (!config || !config.pupitres) {
            return null
        }
        
        for (var i = 0; i < config.pupitres.length; i++) {
            if (config.pupitres[i].id === pupitreId) {
                return config.pupitres[i]
            }
        }
        
        return null
    }
    
    // Obtenir tous les pupitres
    function getAllPupitres() {
        return config ? config.pupitres : []
    }
    
    // Obtenir les pupitres activés
    function getEnabledPupitres() {
        if (!config || !config.pupitres) {
            return []
        }
        
        return config.pupitres.filter(function(pupitre) {
            return pupitre.enabled
        })
    }
    
    // Obtenir les sirènes assignées à un pupitre
    function getAssignedSirenes(pupitreId) {
        var pupitre = getPupitreData(pupitreId)
        return pupitre ? pupitre.assignedSirenes : []
    }
    
    // Définir les sirènes assignées à un pupitre
    function setAssignedSirenes(pupitreId, sirenes) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.assignedSirenes = sirenes
            return true
        }
        return false
    }
    
    // Mettre à jour l'ambitus d'un pupitre
    function setPupitreAmbitus(pupitreId, ambitus) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.ambitus = ambitus
            return true
        }
        return false
    }
    
    // Mettre à jour le mode fretté d'un pupitre
    function setPupitreFrettedMode(pupitreId, frettedMode) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.frettedMode = frettedMode
            return true
        }
        return false
    }
    
    // Mettre à jour le mapping des contrôleurs d'un pupitre
    function setPupitreControllerMapping(pupitreId, controllerMapping) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.controllerMapping = controllerMapping
            console.log("⚙️ Mapping contrôleurs mis à jour pour", pupitreId)
            return true
        }
        return false
    }
    
    // Mettre à jour les options de sortie d'un pupitre
    function setPupitreOutputOptions(pupitreId, vstEnabled, udpEnabled, rtpMidiEnabled) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.vstEnabled = vstEnabled
            pupitre.udpEnabled = udpEnabled
            pupitre.rtpMidiEnabled = rtpMidiEnabled
            console.log("⚙️ Options sortie mises à jour pour", pupitreId, "VST:", vstEnabled, "UDP:", udpEnabled, "RTP:", rtpMidiEnabled)
            return true
        }
        return false
    }
    
    // Obtenir le mapping des contrôleurs d'un pupitre
    function getControllerMapping(pupitreId) {
        var pupitre = getPupitreData(pupitreId)
        return pupitre ? pupitre.controllerMapping : {}
    }
    
    // Définir le mapping des contrôleurs d'un pupitre
    function setControllerMapping(pupitreId, mapping) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.controllerMapping = mapping
            return true
        }
        return false
    }
    
    // Obtenir les paramètres VST/UDP d'un pupitre
    function getOutputSettings(pupitreId) {
        var pupitre = getPupitreData(pupitreId)
        if (!pupitre) return { vstEnabled: false, udpEnabled: false, rtpMidiEnabled: false }
        
        return {
            vstEnabled: pupitre.vstEnabled || false,
            udpEnabled: pupitre.udpEnabled || false,
            rtpMidiEnabled: pupitre.rtpMidiEnabled || false
        }
    }
    
    // Définir les paramètres VST/UDP d'un pupitre
    function setOutputSettings(pupitreId, settings) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            if (settings.vstEnabled !== undefined) pupitre.vstEnabled = settings.vstEnabled
            if (settings.udpEnabled !== undefined) pupitre.udpEnabled = settings.udpEnabled
            if (settings.rtpMidiEnabled !== undefined) pupitre.rtpMidiEnabled = settings.rtpMidiEnabled
            return true
        }
        return false
    }
    
    // Sauvegarder la configuration
    function saveConfig() {
        console.log("💾 Sauvegarde de la configuration...")
        // TODO: Implémenter la sauvegarde vers un fichier
        return true
    }
    
    // Exporter la configuration
    function exportConfig() {
        if (!config) {
            return null
        }
        
        return JSON.stringify(config, null, 2)
    }
    
    // Importer la configuration
    function importConfig(configJson) {
        try {
            var newConfig = JSON.parse(configJson)
            config = newConfig
            isLoaded = true
            console.log("✅ Configuration importée avec succès")
            configLoaded(config)
            return true
        } catch (e) {
            console.error("❌ Erreur lors de l'import de la configuration:", e)
            configError("Erreur import configuration: " + e.message)
            return false
        }
    }
    
    // Valider la configuration
    function validateConfig() {
        if (!config) {
            return { valid: false, error: "Configuration non chargée" }
        }
        
        if (!config.pupitres || !Array.isArray(config.pupitres)) {
            return { valid: false, error: "Liste des pupitres invalide" }
        }
        
        for (var i = 0; i < config.pupitres.length; i++) {
            var pupitre = config.pupitres[i]
            if (!pupitre.id || !pupitre.name || !pupitre.host) {
                return { valid: false, error: "Pupitre invalide: " + (pupitre.id || "inconnu") }
            }
        }
        
        return { valid: true }
    }
}
