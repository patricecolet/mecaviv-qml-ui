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
            "currentSirens": [1],
            "sirens": [
                {
                    "id": 1,
                    "name": "S1",
                    "midiChannel": 1,
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
                    "viewMode": "staff",
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
            "controllers": { "visible": true, "scale": 0.8 },
                "velocityGauge": { "visible": true }
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
    // Pad connecté (PureData envoie PAD_CONNECTED) — si false, la jauge vélocité manuelle est utilisée
    property bool padConnected: false
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
            displayOctaveOffset: primarySiren.displayOctaveOffset,
            /** Canal MIDI 1–16 pour cette sirène (consignes / séquenceur) ; optionnel */
            midiChannel: primarySiren.midiChannel
        }
    }
    
    property var displayConfig: config ? config.displayConfig : null
    
    signal ready()
    signal settingsUpdated()
    
    /**
     * Normalise id sirène et currentSirens en nombres (JSON / anciennes configs peuvent encore envoyer des strings).
     */
    function normalizeSirenNumericIds(cfg) {
        if (!cfg || !cfg.sirenConfig)
            return
        var sc = cfg.sirenConfig
        var sirens = sc.sirens
        if (sirens) {
            for (var i = 0; i < sirens.length; i++) {
                if (sirens[i].id !== undefined && typeof sirens[i].id !== "number") {
                    var nid = parseInt(String(sirens[i].id), 10)
                    if (!isNaN(nid))
                        sirens[i].id = nid
                }
            }
        }
        var cs = sc.currentSirens
        if (cs && Array.isArray(cs)) {
            for (var j = 0; j < cs.length; j++) {
                if (typeof cs[j] !== "number") {
                    var cid = parseInt(String(cs[j]), 10)
                    if (!isNaN(cid))
                        sc.currentSirens[j] = cid
                }
            }
        }
    }

    Component.onCompleted: {
        // En WASM, la vraie config arrive via WebSocket depuis PureData
        
        // Valeur par défaut
        mode = (config && config.mode) ? config.mode : "restricted"
        
        normalizeSirenNumericIds(config)
        
        // Sélectionner la/les sirènes par défaut
        if (config.sirenConfig && config.sirenConfig.sirens && config.sirenConfig.sirens.length > 0) {
            var ids0 = config.sirenConfig.currentSirens || [1]
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
            
            // sirens[pathSegment] : README + server.js (PARAM_UPDATE)
            // - nombre = index tableau 0-based
            // - chaîne = id sirène (legacy) → index ; id numériques en JSON utilisent des nombres
            if (i === 1 && path[0] === "sirenConfig" && pathKey === "sirens" && i + 1 < path.length) {
                var nextKey = path[i + 1]
                var sirens = config.sirenConfig ? config.sirenConfig.sirens : []
                
                if (typeof nextKey === "number") {
                    if (nextKey < 0 || nextKey >= sirens.length) {
                        console.warn("[ConfigController] Index sirens hors limites:", nextKey, "longueur:", sirens.length)
                    }
                } else if (typeof nextKey === "string") {
                    var foundIndex = -1
                    var want = parseInt(String(nextKey), 10)
                    for (var j = 0; j < sirens.length; j++) {
                        if (Number(sirens[j].id) === want) {
                            foundIndex = j
                            break
                        }
                    }
                    if (foundIndex >= 0) {
                        path[i + 1] = foundIndex
                    } else {
                        console.warn("[ConfigController] Id sirène introuvable dans sirens:", nextKey)
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
        
        // currentSirens : tableau d'ids sirène numériques
        if (path.join(".") === "sirenConfig.currentSirens") {
            if (Array.isArray(value)) {
                finalValue = value.map(function(v) {
                    if (typeof v === "number" && isFinite(v))
                        return v
                    var n = parseInt(String(v), 10)
                    return isNaN(n) ? v : n
                })
            } else {
                if (typeof value === "number" && isFinite(value))
                    finalValue = [value]
                else {
                    var n2 = parseInt(String(value), 10)
                    finalValue = isNaN(n2) ? [value] : [n2]
                }
            }
        }
        
        // Log fin de chaîne pour frettedMode (path[2] = index tableau après résolution id éventuelle)
        if (path.length >= 4 && path[0] === "sirenConfig" && path[1] === "sirens" && 
            path[3] === "frettedMode" && path[4] === "enabled") {
            var sirenIndex = path[2];
            var modifiedSiren = config.sirenConfig.sirens[sirenIndex];
            var currentSirenIds = config.sirenConfig.currentSirens || [1];
            var currentSirenId = currentSirenIds.length > 0 ? currentSirenIds[0] : 1;
            var isCurrentSiren = modifiedSiren && Number(modifiedSiren.id) === Number(currentSirenId);
            console.log("[ConfigController] frettedMode sirens[" + sirenIndex + "] id=" + (modifiedSiren ? modifiedSiren.id : "?")
                + ":", oldValue, "->", finalValue, isCurrentSiren ? "(sirène active)" : "");
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
        
        var isCurrentSirensChange = (path.join(".") === "sirenConfig.currentSirens")
        // Pour currentSirens, selectSirens (dans updateLocalState) a déjà fait updateCounter++, settingsUpdated() et envoyé SIRENS_SELECTED → pas de doublon
        if (!isCurrentSirensChange) {
            // Envoyer à PureData seulement si ce n'est pas la console qui a initié
            if (webSocketController && webSocketController.connected && (source === undefined || source !== "console")) {
                webSocketController.sendMessage({
                    type: "PARAM_CHANGED",
                    source: "pupitre",
                    path: path,
                    value: finalValue
                })
            if (path.length === 2 && path[0] === "controllersPanel" && path[1] === "visible") {
                webSocketController.sendMessage({
                    type: "ENABLE_0x02_PROTOCOL",
                    value: !!finalValue
                });
            }
                
                if (path.join(".").startsWith("composeSiren.controllers.") && path.length === 4 && path[3] === "value") {
                    var controllerName = path[2]
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
            updateCounter++
            settingsUpdated()
        }
        
        return true
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
                if (Number(primarySiren.id) === Number(sirenId)) {
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
            if (Number(sirens[i].id) === Number(primarySiren.id)) {
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
        }
        // Valeurs numériques sous le bandeau contrôleurs physiques (pas displayConfig.components.*)
        if (componentName === "controllerValues") {
            return getValueAtPath(["displayConfig", "controllers", "controllerValues", "visible"], true)
        }
        return getValueAtPath(["displayConfig", "components", componentName, "visible"], true)
    }
    
    function isSubComponentVisible(componentName, subComponentName) {
        // Forcer la réévaluation en utilisant vraiment updateCounter
        var dummy = updateCounter
        // Volant, joystick, pads, etc. : displayConfig.controllers.<sous>.visible
        if (componentName === "controllers") {
            return getValueAtPath(["displayConfig", "controllers", subComponentName, "visible"], true)
        }
        return getValueAtPath(["displayConfig", "components", componentName, subComponentName, "visible"], true)
    }
    
    // Fonctions utilitaires existantes
    
    function selectSirens(ids) {
        if (!config) return false
        normalizeSirenNumericIds(config)
        var list = Array.isArray(ids) ? ids : [ids]
        list = list.map(function(id) {
            if (typeof id === "number" && isFinite(id))
                return id
            if (typeof id === "string") {
                if (id.startsWith("S") && id.length > 1) {
                    var sn = parseInt(id.substring(1), 10)
                    return isNaN(sn) ? id : sn
                }
                var pn = parseInt(id, 10)
                return isNaN(pn) ? id : pn
            }
            return id
        })

        var sirens = config.sirenConfig.sirens
        var selectedObjs = []
        for (var j = 0; j < list.length; j++) {
            var id = list[j]
            for (var k = 0; k < sirens.length; k++) {
                if (Number(sirens[k].id) === Number(id)) {
                    selectedObjs.push(sirens[k])
                    break
                }
            }
        }

        currentSirens = selectedObjs
        config.sirenConfig.currentSirens = list

        // Pas de updateCounter++ ni settingsUpdated() : primarySiren change → les bindings qui en dépendent se mettent à jour sans cascade globale
        currentSirenInfoChanged()

        // Envoi WS (liste)
        if (webSocketController && webSocketController.connected) {
            webSocketController.sendBinaryMessage({
                type: "SIRENS_SELECTED",
                sirenIds: list,
                sirenNumbers: list.map(function(x) { return typeof x === "number" ? x : parseInt(String(x), 10) })
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
        
        normalizeSirenNumericIds(newConfig)
        // Remplacer toute la configuration
        config = newConfig;

        // Réinitialiser l'état local depuis la nouvelle config
        mode = newConfig.mode || "restricted";
        if (newConfig.sirenConfig) {
            var ids = newConfig.sirenConfig.currentSirens || [1]
            selectSirens(ids);
        }

        // Forcer la mise à jour de tous les bindings
        updateCounter++;
        settingsUpdated();
        
        // La config est reçue, on n'attend plus
        waitingForConfig = false;
    }
}
