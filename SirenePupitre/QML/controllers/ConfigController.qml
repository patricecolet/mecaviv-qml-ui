import QtQuick 2.15

QtObject {
    id: root
    
    // Configuration chargée depuis config.json (initialisée par défaut)
    // Note: En WASM, la vraie config arrive via WebSocket depuis PureData
    property var config: ({
        "serverUrl": "ws://127.0.0.1:10002",
        "admin": { "enabled": true },
        "controllersPanel": { "visible": false },
        "ui": { "scale": 0.65 },
        "midiFiles": { "repositoryPath": "../mecaviv/compositions" },
        "sirenConfig": { 
            "mode": "restricted", 
            "currentSiren": "1",
            "sirens": [
                {
                    "id": "1",
                    "name": "S1",
                    "outputs": 12,
                    "ambitus": { "min": 43, "max": 86 },
                    "clef": "bass",
                    "restrictedMax": 72,
                    "transposition": 1,
                    "displayOctaveOffset": -1,
                    "frettedMode": { "enabled": false }
                }
            ]
        },
        "displayConfig": {
            "camera": {
                "position": [0, 0, 1500],
                "fieldOfView": 27
            },
            "components": {
                "musicalStaff": {
                    "visible": true,
                    "ambitus": {
                        "showNoteNames": true,
                        "noteNameSettings": {
                            "position": "below",
                            "offsetY": 30,
                            "letterHeight": 15,
                            "letterSpacing": 20,
                            "color": "#FFFF99",
                            "segmentWidth": 3,
                            "segmentDepth": 0.5
                        }
                    }
                }
            },
            "controllers": { "visible": true, "scale": 0.8 }
        },
        "reverbConfig": { "enabled": true },
        "outputConfig": {
            "sirenMode": "udp",
            "composeSirenEnabled": true,
            "composeSirenVolume": 100
        }
    })
    property var currentSiren: null
    property string mode: "restricted"
    property var webSocketController: null
    property int updateCounter: 0
    property int gearShiftPosition: 0
    // État de priorité console
    property bool consoleConnected: false
    
    // Propriété calculée qui se met à jour automatiquement
    property var currentSirenInfo: {
        updateCounter // Forcer la réévaluation
        
        if (!currentSiren) return null
        
        return {
            id: currentSiren.id,
            name: currentSiren.name,
            outputs: currentSiren.outputs,
            transposition: currentSiren.transposition,
            ambitus: currentSiren.ambitus,
            clef: currentSiren.clef,
            restrictedMax: currentSiren.restrictedMax,
            mode: mode,
            displayOctaveOffset: currentSiren.displayOctaveOffset
        }
    }
    
    property var displayConfig: config ? config.displayConfig : null
    
    signal ready()
    signal settingsUpdated()
    
    Component.onCompleted: {
        // En WASM, la vraie config arrive via WebSocket depuis PureData
        
        // Valeur par défaut
        mode = (config && config.mode) ? config.mode : "restricted"
        
        // Sélectionner la sirène par défaut
        if (config.sirenConfig && config.sirenConfig.sirens && config.sirenConfig.sirens.length > 0) {
            var selected = selectSiren(config.sirenConfig.currentSiren)
            if (selected) {
            }
        }
        
        ready()
    }
    
    // FONCTION GÉNÉRIQUE PRINCIPALE
    function setValueAtPath(path, value, source) {

        // Bloquer les écritures locales si la console est connectée
        if (consoleConnected && (source === undefined || source !== "console")) {
            console.warn("⚠️ Écriture bloquée: console en contrôle");
            return false;  // Important: refuser l'écriture
        }
        
        if (!config) {
            return false;  // Important: retourner false
        }
        
        if (!path || path.length === 0) return false;
        
        var current = config
        
        // Naviguer jusqu'à l'avant-dernière clé
        for (var i = 0; i < path.length - 1; i++) {
            if (!current[path[i]]) {
                current[path[i]] = {}
            }
            current = current[path[i]]
        }
        
        var key = path[path.length - 1]
        var oldValue = current[key]
        var finalValue = value
        
        // Conversion automatique des types
        if (typeof oldValue === "boolean" && typeof value === "number") {
            finalValue = value !== 0
        } else if (typeof oldValue === "number" && typeof value === "string") {
            finalValue = parseFloat(value) || parseInt(value) || 0
        }
        
        // Conversion spéciale pour currentSiren
        if (path.join(".") === "sirenConfig.currentSiren" && typeof value === "number") {
            finalValue = value.toString();
        }
        // Définir la valeur
        current[key] = finalValue
        
        // Si on modifie un élément d'un tableau (sirens), forcer une copie pour déclencher les bindings
        if (path[0] === "sirenConfig" && path[1] === "sirens" && typeof path[2] === "number") {
            var sirensCopy = JSON.parse(JSON.stringify(config.sirenConfig.sirens))
            config.sirenConfig.sirens = sirensCopy
        }
        
        // Mise à jour des propriétés locales si nécessaire
        updateLocalState(path, finalValue)
        
        // Envoyer à PureData seulement si ce n'est pas la console qui a initié
        if (webSocketController && webSocketController.connected && (source === undefined || source !== "console")) {
            webSocketController.sendMessage({
                type: "PARAM_CHANGED",
                source: "pupitre",
                path: path,
                value: finalValue
            })
            
            // Message spécifique pour les changements de configuration de sortie
            if (path.join(".") === "outputConfig.sirenMode" || 
                path.join(".") === "outputConfig.composeSirenEnabled" ||
                path.join(".") === "outputConfig.composeSirenVolume") {
                
                var sirenMode = getValueAtPath(["outputConfig", "sirenMode"], "udp")
                var composeSirenEnabled = getValueAtPath(["outputConfig", "composeSirenEnabled"], true)
                var composeSirenVolume = getValueAtPath(["outputConfig", "composeSirenVolume"], 100)
                
                webSocketController.sendMessage({
                    type: "OUTPUT_CONFIG_CHANGED",
                    sirenMode: sirenMode,
                    composeSirenEnabled: composeSirenEnabled,
                    composeSirenVolume: composeSirenVolume
                })
            }
        }
        
        // Forcer la mise à jour
        updateCounter++
        settingsUpdated()
        
        return true;  // IMPORTANT: Ajouter cette ligne
    }
    
    // FONCTION GÉNÉRIQUE DE LECTURE
    function getValueAtPath(path, defaultValue) {
        if (!config || !path || path.length === 0) return defaultValue
        
        var current = config
        for (var i = 0; i < path.length; i++) {
            if (current && current[path[i]] !== undefined) {
                current = current[path[i]]
            } else {
                return defaultValue
            }
        }
        return current
    }
    
    // Mise à jour de l'état local
    function updateLocalState(path, value) {
        var pathStr = path.join(".")
        
        switch(pathStr) {
            case "mode":
                mode = value
                break
            case "sirenConfig.currentSiren":
                selectSiren(value)
                break
        }
        
        // Mise à jour de currentSiren si c'est une propriété de la sirène active
        if (path[0] === "sirenConfig" && path[1] === "sirens" && path.length >= 4) {
            var sirenIndex = parseInt(path[2])
            if (config.sirenConfig.sirens[sirenIndex] && currentSiren) {
                var sirenId = config.sirenConfig.sirens[sirenIndex].id
                if (currentSiren.id === sirenId) {
                    // Mettre à jour la propriété dans currentSiren
                    var propertyName = path[3]
                    currentSiren[propertyName] = value
                    
                    // Forcer la mise à jour
                    currentSirenInfoChanged()
                }
            }
        }
    }
    
    // FONCTIONS SIMPLIFIÉES qui utilisent les génériques
    
    function setMode(newMode) {
        setValueAtPath(["mode"], newMode)
    }
    
    function setRestrictedMax(value) {
        if (!currentSiren) return
        // Trouver l'index de la sirène courante
        var sirens = config.sirenConfig.sirens
        for (var i = 0; i < sirens.length; i++) {
            if (sirens[i].id === currentSiren.id) {
                setValueAtPath(["sirenConfig", "sirens", i, "restrictedMax"], value)
                break
            }
        }
    }
    
    function setComponentVisibility(componentName, visible) {
        if (componentName === "controllers") {
            setValueAtPath(["displayConfig", "controllers", "visible"], visible)
        } else {
            setValueAtPath(["displayConfig", "components", componentName, "visible"], visible)
        }
    }
    
    function setSubComponentVisibility(componentName, subComponentName, visible) {
        setValueAtPath(["displayConfig", "components", componentName, subComponentName, "visible"], visible)
    }
    
    function isComponentVisible(componentName) {
        // Forcer la réévaluation en utilisant vraiment updateCounter
        var dummy = updateCounter
        
        if (componentName === "controllers") {
            return getValueAtPath(["displayConfig", "controllers", "visible"], true)
        } else {
            return getValueAtPath(["displayConfig", "components", componentName, "visible"], true)
        }
    }
    
    function isSubComponentVisible(componentName, subComponentName) {
        // Forcer la réévaluation en utilisant vraiment updateCounter
        var dummy = updateCounter
        
        return getValueAtPath(["displayConfig", "components", componentName, subComponentName, "visible"], true)
    }
    
    // Fonctions utilitaires existantes
    
    function selectSiren(id) {
        if (!config) return false
        
        // Normaliser l'ID pour accepter différents formats
        var normalizedId = id
        if (typeof id === "number") {
            normalizedId = id.toString()
        } else if (typeof id === "string") {
            // Si c'est "S2", extraire "2"
            if (id.startsWith("S") && id.length > 1) {
                normalizedId = id.substring(1)
            }
        }
        
        
        var sirens = config.sirenConfig.sirens
        for (var i = 0; i < sirens.length; i++) {
            if (sirens[i].id === normalizedId) {
                currentSiren = sirens[i]
                config.sirenConfig.currentSiren = normalizedId
                
                // AJOUTER CES LIGNES
                updateCounter++
                currentSirenInfoChanged()
                
                settingsUpdated()
                
                // 🔧 ENVOYER LE NUMÉRO DE SIRÈNE PAR WEBSOCKET
                if (webSocketController && webSocketController.connected) {
                    webSocketController.sendBinaryMessage({
                        type: "SIREN_SELECTED",
                        sirenId: normalizedId,
                        sirenNumber: parseInt(normalizedId)  // Convertir en nombre
                    })
                }
                
                return true
            }
        }
        return false
    }
    
    function getMaxNote() {
        if (!currentSiren) return 127
        return mode === "restricted" ? currentSiren.restrictedMax : currentSiren.ambitus.max
    }
    
    function getMinNote() {
        if (!currentSiren) return 0
        return currentSiren.ambitus.min
    }
    
    // Fonctions de compatibilité (utilisant les nouvelles génériques)
    function getConfigValue(path, defaultValue) {
        return getValueAtPath(path.split('.'), defaultValue)
    }
    
    function setConfigValue(path, value) {
        setValueAtPath(path.split('.'), value)
    }
    
    function getCurrentSirenInfo() {
        return currentSirenInfo
    }
    function updateFullConfig(newConfig) {
        
        // Remplacer toute la configuration
        config = newConfig;
        
        // Réinitialiser l'état local depuis la nouvelle config
        mode = newConfig.mode || "restricted";
        if (newConfig.sirenConfig) {
            selectSiren(newConfig.sirenConfig.currentSiren || "1");
        }
        
        // Forcer la mise à jour de tous les bindings
        updateCounter++;
        settingsUpdated();
        
    }   
}
