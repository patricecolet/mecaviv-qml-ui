import QtQuick 2.15
import Qt.labs.platform 1.1 as Platform

/**
 * ConfigLoader - Charge config.json depuis le filesystem
 * Remplace l'ancien config.js embarqué dans les ressources
 */
QtObject {
    id: root
    
    // Configuration chargée
    property var configData: null
    property bool loaded: false
    property string errorMessage: ""
    
    // Chemin vers config.json (relatif depuis l'exécutable)
    function getConfigPath() {
        // En natif : config.json est à la racine du projet
        // L'exécutable est dans build/ donc on remonte d'un niveau
        return Qt.resolvedUrl("../../config.json")
    }
    
    // Charger la configuration au démarrage
    Component.onCompleted: {
        loadConfig()
    }
    
    // Fonction de chargement
    function loadConfig() {
        console.log("📁 Chargement configuration...")
        
        var configPath = getConfigPath()
        console.log("📂 Chemin config:", configPath)
        
        try {
            // Lire le fichier
            var xhr = new XMLHttpRequest()
            xhr.open("GET", configPath, false) // Synchrone pour simplifier
            xhr.send()
            
            if (xhr.status === 200 || xhr.status === 0) {
                // Parser le JSON
                var jsonData = JSON.parse(xhr.responseText)
                
                // Adapter la structure pour compatibilité avec l'ancien config.js
                configData = {
                    "serverUrl": "ws://" + jsonData.servers.websocket.host + ":" + jsonData.servers.websocket.port,
                    "admin": {
                        "enabled": true
                    },
                    "controllersPanel": {
                        "visible": false
                    },
                    "ui": {
                        "scale": 0.65
                    },
                    "midiFiles": {
                        "repositoryPath": jsonData.paths.midiRepository || "../mecaviv/compositions"
                    },
                    "sirenConfig": jsonData.sirenConfig || {},
                    "displayConfig": jsonData.displayConfig || {},
                    "reverbConfig": jsonData.reverbConfig || {}
                }
                
                loaded = true
                console.log("✅ Configuration chargée")
                console.log("🔌 WebSocket:", configData.serverUrl)
                console.log("📂 MIDI Repository:", configData.midiFiles.repositoryPath)
                
            } else {
                errorMessage = "Erreur HTTP: " + xhr.status
                console.error("❌", errorMessage)
                loadDefaultConfig()
            }
            
        } catch (e) {
            errorMessage = "Erreur chargement config: " + e.toString()
            console.error("❌", errorMessage)
            loadDefaultConfig()
        }
    }
    
    // Configuration par défaut en cas d'erreur
    function loadDefaultConfig() {
        console.warn("⚠️  Chargement configuration par défaut")
        
        configData = {
            "serverUrl": "ws://127.0.0.1:10002",
            "admin": {
                "enabled": true
            },
            "controllersPanel": {
                "visible": false
            },
            "ui": {
                "scale": 0.65
            },
            "midiFiles": {
                "repositoryPath": "../mecaviv/compositions"
            },
            "sirenConfig": {
                "mode": "restricted",
                "currentSiren": "1",
                "sirens": []
            },
            "displayConfig": {
                "components": {}
            },
            "reverbConfig": {
                "enabled": true
            }
        }
        
        loaded = true
    }
    
    // Helper pour récupérer une valeur dans la config
    function getValue(path, defaultValue) {
        if (!loaded || !configData) return defaultValue
        
        var parts = path.split('.')
        var current = configData
        
        for (var i = 0; i < parts.length; i++) {
            if (current[parts[i]] === undefined) {
                return defaultValue
            }
            current = current[parts[i]]
        }
        
        return current
    }
}

