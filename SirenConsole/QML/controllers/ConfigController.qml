import QtQuick 2.15

QtObject {
    id: configController
    
    // Propriétés
    property var config: null
    property bool isLoaded: false
    
    // Initialisation
    Component.onCompleted: {
        console.log("⚙️ ConfigController initialisé")
        loadConfig()
    }
    
    // Charger la configuration
    function loadConfig() {
        console.log("📋 Chargement de la configuration...")
        
        // Configuration par défaut
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
                    port: 10001,
                    enabled: true,
                    description: "Pupitre principal - Salle A",
                    assignedSirenes: [1, 2, 3],
                    vstEnabled: true,
                    udpEnabled: true,
                    rtpMidiEnabled: true,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P2", 
                    name: "Pupitre 2",
                    host: "192.168.1.42",
                    port: 10001,
                    enabled: true,
                    description: "Pupitre secondaire - Salle B",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P3",
                    name: "Pupitre 3", 
                    host: "192.168.1.43",
                    port: 10001,
                    enabled: true,
                    description: "Pupitre de réserve - Salle C",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P4",
                    name: "Pupitre 4",
                    host: "192.168.1.44", 
                    port: 10001,
                    enabled: true,
                    description: "Pupitre mobile - Salle D",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P5",
                    name: "Pupitre 5",
                    host: "192.168.1.45",
                    port: 10001,
                    enabled: true,
                    description: "Pupitre de test - Labo",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P6",
                    name: "Pupitre 6",
                    host: "192.168.1.46",
                    port: 10001,
                    enabled: true,
                    description: "Pupitre de démo - Showroom",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
                        pedalId: { cc: 5, curve: "linear" }
                    }
                },
                {
                    id: "P7",
                    name: "Pupitre 7",
                    host: "192.168.1.47",
                    port: 10001,
                    enabled: true,
                    description: "Pupitre de backup - Stockage",
                    assignedSirenes: [],
                    vstEnabled: false,
                    udpEnabled: true,
                    rtpMidiEnabled: false,
                    controllerMapping: {
                        joystickX: { cc: 1, curve: "linear" },
                        joystickY: { cc: 2, curve: "parabolic" },
                        fader: { cc: 3, curve: "hyperbolic" },
                        selector: { cc: 4, curve: "s" },
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
        console.log("✅ Configuration chargée avec succès")
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
        console.log("⚙️ Configuration mise à jour:", path.join('.'), "=", value)
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

    // Ajouter des fonctions pour les nouveaux champs si nécessaire
    function getAssignedSirenes(pupitreId) {
        var pupitre = getPupitreData(pupitreId)
        return pupitre ? pupitre.assignedSirenes : []
    }

    function setAssignedSirenes(pupitreId, sirenes) {
        var pupitre = getPupitreData(pupitreId)
        if (pupitre) {
            pupitre.assignedSirenes = sirenes
            return true
        }
        return false
    }

    // Pareil pour vstEnabled, etc.
    
    // Sauvegarder la configuration
    function saveConfig() {
        console.log("💾 Sauvegarde de la configuration...")
        // TODO: Implémenter la sauvegarde vers un fichier
        return true
    }
    
    // Charger la configuration depuis un fichier
    function loadConfigFromFile(filePath) {
        console.log("📂 Chargement de la configuration depuis:", filePath)
        // TODO: Implémenter le chargement depuis un fichier
        return false
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
            return true
        } catch (e) {
            console.error("❌ Erreur lors de l'import de la configuration:", e)
            return false
        }
    }
}
