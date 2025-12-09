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
            "currentSirens": ["1"],
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
            "sirenMode": "udp"
        },
        "composeSiren": {
            "enabled": true,
            "controllers": {
                "masterVolume": { "cc": 7, "value": 100 }
            }
        }
    })
    property var currentSirens: []
    property var primarySiren: currentSirens && currentSirens.length > 0 ? currentSirens[0] : null
    property string mode: "restricted"
    property var webSocketController: null
    property int updateCounter: 0
    property int gearShiftPosition: 0
    // État de priorité console
    property bool consoleConnected: false
    // État d'attente de la configuration
    property bool waitingForConfig: false
    
    // Propriété calculée qui se met à jour automatiquement
    property var currentSirenInfo: {
        updateCounter // Forcer la réévaluation
        
        if (!primarySiren) return null
        
        return {
            id: primarySiren.id,
            name: primarySiren.name,
            outputs: primarySiren.outputs,
            transposition: primarySiren.transposition,
            ambitus: primarySiren.ambitus,
            clef: primarySiren.clef,
            restrictedMax: primarySiren.restrictedMax,
            mode: mode,
            displayOctaveOffset: primarySiren.displayOctaveOffset
        }
    }
    
    property var displayConfig: config ? config.displayConfig : null
    
    signal ready()
    signal settingsUpdated()
    
    Component.onCompleted: {
        // En WASM, la vraie config arrive via WebSocket depuis PureData
        
        // Valeur par défaut
        mode = (config && config.mode) ? config.mode : "restricted"
        
        // Sélectionner la/les sirènes par défaut
        if (config.sirenConfig && config.sirenConfig.sirens && config.sirenConfig.sirens.length > 0) {
            var ids0 = config.sirenConfig.currentSirens || ["1"]
            selectSirens(ids0)
        }
        
        ready()
    }
    
    // FONCTION GÉNÉRIQUE PRINCIPALE
    function setValueAtPath(path, value, source) {

        // Bloquer les écritures locales si la console est connectée
        if (consoleConnected && (source === undefined || source !== "console")) {
            return false;  // Important: refuser l'écriture
        }
        
        if (!config) {
            return false;  // Important: retourner false
        }
        
        if (!path || path.length === 0) return false;
        
        var current = config
        
        // Naviguer jusqu'à l'avant-dernière clé
        for (var i = 0; i < path.length - 1; i++) {
            var pathKey = path[i]
            
            // Conversion spéciale : si on accède au tableau "sirens", convertir l'id en index
            // Les ids commencent à "1" (S1, S2, S3...) mais les index du tableau commencent à 0
            if (i === 1 && path[0] === "sirenConfig" && pathKey === "sirens" && i + 1 < path.length) {
                var nextKey = path[i + 1]
                // Accéder à config directement pour avoir les sirens
                var sirens = config.sirenConfig ? config.sirenConfig.sirens : []
                
                // Si nextKey est un nombre, TOUJOURS essayer de le traiter comme un id d'abord
                // Les ids commencent à 1 (S1=1, S2=2, S3=3...), les index à 0
                if (typeof nextKey === "number") {
                    // TOUJOURS chercher d'abord comme un id (même si c'est un index valide)
                    var foundIndex = -1
                    var targetId = nextKey.toString()
                    for (var j = 0; j < sirens.length; j++) {
                        if (sirens[j].id === targetId) {
                            foundIndex = j
                            break
                        }
                    }
                    if (foundIndex >= 0) {
                        // C'est un id, convertir en index
                        console.log("🎯 [ConfigController] Conversion id→index:", "id", targetId, "→ index", foundIndex);
                        path[i + 1] = foundIndex
                    } else {
                        // Pas trouvé comme id, utiliser comme index (pour rétrocompatibilité)
                        if (nextKey >= 0 && nextKey < sirens.length) {
                            console.log("🎯 [ConfigController] Utilisation comme index:", nextKey, "(id non trouvé)");
                        } else {
                            console.log("🎯 [ConfigController] Avertissement: id", nextKey, "non trouvé et index invalide");
                        }
                    }
                } else if (typeof nextKey === "string" && !isNaN(parseInt(nextKey))) {
                    // Si c'est une string numérique, chercher l'index correspondant à cet id
                    var foundIndex = -1
                    for (var j = 0; j < sirens.length; j++) {
                        if (sirens[j].id === nextKey) {
                            foundIndex = j
                            break
                        }
                    }
                    if (foundIndex >= 0) {
                        // Remplacer l'id par l'index dans le path
                        console.log("🎯 [ConfigController] Conversion id→index:", "id", nextKey, "→ index", foundIndex);
                        path[i + 1] = foundIndex
                    }
                }
            }
            
            if (!current[pathKey]) {
                current[pathKey] = {}
            }
            current = current[pathKey]
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
        
        // Conversion spéciale pour currentSirens (forcer un tableau de strings)
        if (path.join(".") === "sirenConfig.currentSirens") {
            if (Array.isArray(value)) {
                finalValue = value.map(function(v) { return (typeof v === "number") ? v.toString() : v })
            } else {
                finalValue = [ (typeof value === "number") ? value.toString() : value ]
            }
        }
        
        // Log fin de chaîne pour frettedMode
        if (path.length >= 4 && path[0] === "sirenConfig" && path[1] === "sirens" && 
            path[3] === "frettedMode" && path[4] === "enabled") {
            var sirenIndex = path[2];
            var modifiedSiren = config.sirenConfig.sirens[sirenIndex];
            var currentSirenIds = config.sirenConfig.currentSirens || ["1"];
            var currentSirenId = currentSirenIds.length > 0 ? currentSirenIds[0] : "1";
            var isCurrentSiren = modifiedSiren && modifiedSiren.id === currentSirenId;
            console.log("🎯 [ConfigController] Fin chaîne - frettedMode modifié:", 
                "sirène index", sirenIndex, "id", modifiedSiren ? modifiedSiren.id : "?", 
                "ancienne valeur:", oldValue, "nouvelle valeur:", finalValue,
                "sirène actuelle:", currentSirenId, "est la même:", isCurrentSiren);
        }
        
        // Définir la valeur
        current[key] = finalValue
        
        // Si on modifie un élément d'un tableau (sirens), forcer une copie pour déclencher les bindings
        if (path[0] === "sirenConfig" && path[1] === "sirens" && typeof path[2] === "number") {
            // La copie doit être faite APRÈS la modification de current[key]
            // pour que la nouvelle valeur soit incluse dans la copie
            var sirensCopy = JSON.parse(JSON.stringify(config.sirenConfig.sirens))
            config.sirenConfig.sirens = sirensCopy
        }
        
        // Mise à jour des propriétés locales si nécessaire
        updateLocalState(path, finalValue)
        
        // Envoyer à PureData seulement si ce n'est pas la console qui a initié
        if (webSocketController && webSocketController.connected && (source === undefined || source !== "console")) {
            // Envoyer le changement de paramètre individuel
            webSocketController.sendMessage({
                type: "PARAM_CHANGED",
                source: "pupitre",
                path: path,
                value: finalValue
            })
            
            // Pour les contrôleurs composeSiren, envoyer aussi un message spécifique avec le CC
            if (path.join(".").startsWith("composeSiren.controllers.") && path.length === 4 && path[3] === "value") {
                var controllerName = path[2] // Ex: "masterVolume", "reverbEnable", etc.
                var controllerConfig = getValueAtPath(["composeSiren", "controllers", controllerName], null)
                
                if (controllerConfig && controllerConfig.cc !== undefined) {
                    webSocketController.sendMessage({
                        type: "COMPOSESIREN_CC_CHANGED",
                        controllerName: controllerName,
                        cc: controllerConfig.cc,
                        value: finalValue
                    })
                }
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
            case "sirenConfig.currentSirens":
                selectSirens(value)
                break
        }
        
        // Mise à jour de primarySiren si c'est une propriété de la sirène active
        if (path[0] === "sirenConfig" && path[1] === "sirens" && path.length >= 4) {
            var sirenIndex = parseInt(path[2])
            if (config.sirenConfig.sirens[sirenIndex] && primarySiren) {
                var sirenId = config.sirenConfig.sirens[sirenIndex].id
                if (primarySiren.id === sirenId) {
                    // Mettre à jour la propriété dans currentSiren
                    var propertyName = path[3]
                    primarySiren[propertyName] = value
                    
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
        if (!primarySiren) return
        // Trouver l'index de la sirène courante
        var sirens = config.sirenConfig.sirens
        for (var i = 0; i < sirens.length; i++) {
            if (sirens[i].id === primarySiren.id) {
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
    
    function selectSirens(ids) {
        if (!config) return false
        var list = Array.isArray(ids) ? ids : [ids]
        // normaliser en strings
        list = list.map(function(id) {
            if (typeof id === "number") return id.toString()
            if (typeof id === "string" && id.startsWith("S") && id.length > 1) return id.substring(1)
            return id
        })

        // Construire le tableau d'objets sirènes correspondants
        var sirens = config.sirenConfig.sirens
        var selectedObjs = []
        for (var j = 0; j < list.length; j++) {
            var id = list[j]
            for (var k = 0; k < sirens.length; k++) {
                if (sirens[k].id === id) {
                    selectedObjs.push(sirens[k])
                    break
                }
            }
        }

        currentSirens = selectedObjs
        config.sirenConfig.currentSirens = list

        updateCounter++
        currentSirenInfoChanged()
        settingsUpdated()

        // Envoi WS (liste)
        if (webSocketController && webSocketController.connected) {
            webSocketController.sendBinaryMessage({
                type: "SIRENS_SELECTED",
                sirenIds: list,
                sirenNumbers: list.map(function(x) { return parseInt(x) })
            })
        }
        return true
    }

    function selectSiren(id) {
        // compat mono-sélection
        return selectSirens([id])
    }
    
    function getMaxNote() {
        if (!primarySiren) return 127
        return mode === "restricted" ? primarySiren.restrictedMax : primarySiren.ambitus.max
    }
    
    function getMinNote() {
        if (!primarySiren) return 0
        return primarySiren.ambitus.min
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
            var ids = newConfig.sirenConfig.currentSirens || ["1"]
            selectSirens(ids);
        }

        // Forcer la mise à jour de tous les bindings
        updateCounter++;
        settingsUpdated();
        
        // La config est reçue, on n'attend plus
        waitingForConfig = false;
    }
}
