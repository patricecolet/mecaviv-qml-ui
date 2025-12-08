import QtQuick 2.15
import "../utils" as Utils

QtObject {
    id: presetManager
    
    // Instance de NetworkUtils créée dynamiquement
    property var networkUtils: null
    
    // Fonction helper pour obtenir l'URL de base
    function getApiBaseUrl() {
        if (!networkUtils) {
            networkUtils = Qt.createQmlObject('import "../utils" as Utils; Utils.NetworkUtils {}', presetManager)
        }
        return networkUtils.getApiBaseUrl()
    }
    
    // Propriétés
    property var presets: []
    property string currentPreset: ""
    property var configManager: null
    
    // Signaux
    signal presetsListChanged(var presetsList)
    signal presetLoaded(string presetName)
    signal presetSaved(string presetName)
    signal presetDeleted(string presetName)
    signal presetError(string error)
    
    // Initialisation
    Component.onCompleted: {
        // PresetManager initialisé
        loadPresetsFromStorage()
    }
    
    // Charger les presets depuis l'API
    function loadPresetsFromStorage() {
        // Chargement des presets depuis l'API
        
        var xhr = new XMLHttpRequest()
        var apiUrl = getApiBaseUrl()
        xhr.open("GET", apiUrl + "/api/presets")
        xhr.setRequestHeader("Content-Type", "application/json")
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        presets = response.presets || []
                        presetsListChanged(presets)
                    } catch (e) {
                        // Erreur parsing presets
                        presetError("Erreur parsing presets: " + e.message)
                    }
                } else {
                    // Erreur chargement presets
                    presetError("Erreur chargement presets: " + xhr.status)
                }
            }
        }
        
        xhr.send()
    }
    
    // Sauvegarder un preset vers l'API
    function savePresetToAPI(presetData) {
        // Sauvegarde preset vers API
        
        var xhr = new XMLHttpRequest()
        var apiUrl = getApiBaseUrl()
        var url = apiUrl + "/api/presets"
        var method = presetData.id ? "PUT" : "POST"
        
        if (presetData.id) {
            url += "/" + presetData.id
        }
        
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 201) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (response.preset && response.preset.id) {
                            presetData.id = response.preset.id
                        }
                        // Preset sauvegardé
                        presetSaved(presetData.name)
                        
                        // Recharger la liste des presets
                        loadPresetsFromStorage()
                    } catch (e) {
                        // Erreur parsing réponse sauvegarde
                        presetError("Erreur sauvegarde preset: " + e.message)
                    }
                } else {
                    // Erreur sauvegarde preset
                    presetError("Erreur sauvegarde preset: " + xhr.status)
                }
            }
        }
        
        xhr.send(JSON.stringify(presetData))
    }
    
    // Créer un preset à partir de la configuration actuelle
    function createPresetFromCurrent(presetName, presetDescription) {
        if (!configManager || !configManager.config) {
            // ConfigManager non disponible
            presetError("ConfigManager non disponible")
            return false
        }
        
        // Création preset
        
        // Capturer la configuration actuelle de tous les pupitres
        var currentConfig = {
            pupitres: []
        }
        
        var allPupitres = configManager.getAllPupitres()
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            var pupitreConfig = {
                id: pupitre.id,
                ambitus: pupitre.ambitus || { min: 48, max: 72 },
                frettedMode: pupitre.frettedMode || false,
                assignedSirenes: pupitre.assignedSirenes || [],
                vstEnabled: pupitre.vstEnabled || false,
                udpEnabled: pupitre.udpEnabled || false,
                rtpMidiEnabled: pupitre.rtpMidiEnabled || false,
                controllerMapping: pupitre.controllerMapping || {}
            }
            currentConfig.pupitres.push(pupitreConfig)
        }
        
        var presetData = {
            name: presetName,
            description: presetDescription || "",
            config: currentConfig,
            created: new Date().toISOString(),
            modified: new Date().toISOString(),
            version: "1.0"
        }
        
        return createPreset(presetData)
    }
    
    // Créer un nouveau preset
    function createPreset(presetData) {
        // Création preset
        
        // Vérifier si le nom existe déjà
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetData.name) {
                // Preset existe déjà
                presetError("Preset existe déjà: " + presetData.name)
                return false
            }
        }
        
        // Ajouter les métadonnées (l'ID sera généré par l'API)
        presetData.created = presetData.created || new Date().toISOString()
        presetData.modified = new Date().toISOString()
        presetData.version = presetData.version || "1.0"
        
        // Sauvegarder vers l'API
        savePresetToAPI(presetData)
        
        return true
    }
    
    // Mettre à jour un preset existant
    function updatePreset(presetId, presetData) {
        // Mise à jour preset
        
        var existingPreset = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].id === presetId) {
                existingPreset = presets[i]
                break
            }
        }
        
        if (!existingPreset) {
            // Preset non trouvé
            presetError("Preset non trouvé: " + presetId)
            return false
        }
        
        // Fusionner les données
        presetData.id = presetId
        presetData.created = existingPreset.created
        presetData.modified = new Date().toISOString()
        presetData.version = existingPreset.version || "1.0"
        
        // Sauvegarder vers l'API
        savePresetToAPI(presetData)
        
        return true
    }
    
    // Supprimer un preset
    function deletePreset(presetName) {
        // Suppression preset
        
        var presetToDelete = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                presetToDelete = presets[i]
                break
            }
        }
        
        if (!presetToDelete) {
            // Preset non trouvé
            presetError("Preset non trouvé: " + presetName)
            return false
        }
        
        var xhr = new XMLHttpRequest()
        var apiUrl = getApiBaseUrl()
        xhr.open("DELETE", apiUrl + "/api/presets/" + presetToDelete.id)
        xhr.setRequestHeader("Content-Type", "application/json")
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 204) {
                    // Preset supprimé
                    presetDeleted(presetName)
                    
                    // Recharger la liste des presets
                    loadPresetsFromStorage()
                } else {
                    // Erreur suppression preset
                    presetError("Erreur suppression preset: " + xhr.status)
                }
            }
        }
        
        xhr.send()
        return true
    }
    
    // Charger un preset
    function loadPreset(presetName) {
        // Chargement preset
        
        var presetToLoad = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                presetToLoad = presets[i]
                break
            }
        }
        
        if (!presetToLoad) {
            // Preset non trouvé
            presetError("Preset non trouvé: " + presetName)
            return false
        }
        
        if (!configManager || !configManager.config) {
            // ConfigManager non disponible
            presetError("ConfigManager non disponible")
            return false
        }
        
        try {
            // Appliquer la configuration du preset
            if (presetToLoad.config && presetToLoad.config.pupitres) {
                var presetPupitres = presetToLoad.config.pupitres
                var allPupitres = configManager.getAllPupitres()
                
                for (var i = 0; i < allPupitres.length; i++) {
                    var pupitre = allPupitres[i]
                    var presetPupitre = null
                    
                    // Trouver la configuration correspondante dans le preset
                    for (var j = 0; j < presetPupitres.length; j++) {
                        if (presetPupitres[j].id === pupitre.id) {
                            presetPupitre = presetPupitres[j]
                            break
                        }
                    }
                    
                    if (presetPupitre) {
                        // Appliquer les paramètres du preset
                        if (presetPupitre.ambitus) pupitre.ambitus = presetPupitre.ambitus
                        if (presetPupitre.frettedMode !== undefined) pupitre.frettedMode = presetPupitre.frettedMode
                        if (presetPupitre.assignedSirenes) pupitre.assignedSirenes = presetPupitre.assignedSirenes
                        if (presetPupitre.vstEnabled !== undefined) pupitre.vstEnabled = presetPupitre.vstEnabled
                        if (presetPupitre.udpEnabled !== undefined) pupitre.udpEnabled = presetPupitre.udpEnabled
                        if (presetPupitre.rtpMidiEnabled !== undefined) pupitre.rtpMidiEnabled = presetPupitre.rtpMidiEnabled
                        if (presetPupitre.controllerMapping) pupitre.controllerMapping = presetPupitre.controllerMapping
                        
                        // Configuration appliquée au pupitre
                    }
                }
            }
            
            currentPreset = presetName
            // Preset chargé avec succès
            presetLoaded(presetName)
            return true
            
        } catch (e) {
            // Erreur chargement preset
            presetError("Erreur chargement preset: " + e.message)
            return false
        }
    }
    
    // Obtenir un preset par nom
    function getPresetByName(presetName) {
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                return presets[i]
            }
        }
        return null
    }
    
    // Obtenir un preset par ID
    function getPresetById(presetId) {
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].id === presetId) {
                return presets[i]
            }
        }
        return null
    }
    
    // Vérifier si un preset existe
    function presetExists(presetName) {
        return getPresetByName(presetName) !== null
    }
    
    // Obtenir la liste des noms de presets
    function getPresetNames() {
        var names = []
        for (var i = 0; i < presets.length; i++) {
            names.push(presets[i].name)
        }
        return names
    }
    
    // Exporter tous les presets
    function exportAllPresets() {
        return JSON.stringify(presets, null, 2)
    }
    
    // Importer des presets
    function importPresets(presetsJson) {
        try {
            var importedPresets = JSON.parse(presetsJson)
            if (!Array.isArray(importedPresets)) {
                importedPresets = [importedPresets]
            }
            
            var successCount = 0
            for (var i = 0; i < importedPresets.length; i++) {
                if (createPreset(importedPresets[i])) {
                    successCount++
                }
            }
            
            // Presets importés
            return { success: true, imported: successCount, total: importedPresets.length }
            
        } catch (e) {
            // Erreur import presets
            presetError("Erreur import presets: " + e.message)
            return { success: false, error: e.message }
        }
    }
}
