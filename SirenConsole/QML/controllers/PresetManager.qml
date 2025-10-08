import QtQuick 2.15

QtObject {
    id: presetManager
    
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
        console.log("💾 PresetManager initialisé")
        loadPresetsFromStorage()
    }
    
    // Charger les presets depuis l'API
    function loadPresetsFromStorage() {
        console.log("📂 Chargement des presets depuis l'API...")
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://localhost:8001/api/presets")
        xhr.setRequestHeader("Content-Type", "application/json")
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        presets = response.presets || []
                        presetsListChanged(presets)
                    } catch (e) {
                        console.error("❌ Erreur parsing presets:", e)
                        presetError("Erreur parsing presets: " + e.message)
                    }
                } else {
                    console.error("❌ Erreur chargement presets:", xhr.status, xhr.responseText)
                    presetError("Erreur chargement presets: " + xhr.status)
                }
            }
        }
        
        xhr.send()
    }
    
    // Sauvegarder un preset vers l'API
    function savePresetToAPI(presetData) {
        console.log("💾 Sauvegarde preset vers API:", presetData.name)
        
        var xhr = new XMLHttpRequest()
        var url = "http://localhost:8001/api/presets"
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
                        console.log("✅ Preset sauvegardé:", presetData.name)
                        presetSaved(presetData.name)
                        
                        // Recharger la liste des presets
                        loadPresetsFromStorage()
                    } catch (e) {
                        console.error("❌ Erreur parsing réponse sauvegarde:", e)
                        presetError("Erreur sauvegarde preset: " + e.message)
                    }
                } else {
                    console.error("❌ Erreur sauvegarde preset:", xhr.status, xhr.responseText)
                    presetError("Erreur sauvegarde preset: " + xhr.status)
                }
            }
        }
        
        xhr.send(JSON.stringify(presetData))
    }
    
    // Créer un preset à partir de la configuration actuelle
    function createPresetFromCurrent(presetName, presetDescription) {
        if (!configManager || !configManager.config) {
            console.error("❌ ConfigManager non disponible")
            presetError("ConfigManager non disponible")
            return false
        }
        
        console.log("🆕 Création preset:", presetName)
        
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
        console.log("🆕 Création preset:", presetData.name)
        
        // Vérifier si le nom existe déjà
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetData.name) {
                console.error("❌ Preset existe déjà:", presetData.name)
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
        console.log("📝 Mise à jour preset:", presetId)
        
        var existingPreset = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].id === presetId) {
                existingPreset = presets[i]
                break
            }
        }
        
        if (!existingPreset) {
            console.error("❌ Preset non trouvé:", presetId)
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
        console.log("🗑️ Suppression preset:", presetName)
        
        var presetToDelete = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                presetToDelete = presets[i]
                break
            }
        }
        
        if (!presetToDelete) {
            console.error("❌ Preset non trouvé:", presetName)
            presetError("Preset non trouvé: " + presetName)
            return false
        }
        
        var xhr = new XMLHttpRequest()
        xhr.open("DELETE", "http://localhost:8001/api/presets/" + presetToDelete.id)
        xhr.setRequestHeader("Content-Type", "application/json")
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 204) {
                    console.log("✅ Preset supprimé:", presetName)
                    presetDeleted(presetName)
                    
                    // Recharger la liste des presets
                    loadPresetsFromStorage()
                } else {
                    console.error("❌ Erreur suppression preset:", xhr.status, xhr.responseText)
                    presetError("Erreur suppression preset: " + xhr.status)
                }
            }
        }
        
        xhr.send()
        return true
    }
    
    // Charger un preset
    function loadPreset(presetName) {
        console.log("📂 Chargement preset:", presetName)
        
        var presetToLoad = null
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                presetToLoad = presets[i]
                break
            }
        }
        
        if (!presetToLoad) {
            console.error("❌ Preset non trouvé:", presetName)
            presetError("Preset non trouvé: " + presetName)
            return false
        }
        
        if (!configManager || !configManager.config) {
            console.error("❌ ConfigManager non disponible")
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
                        
                        console.log("✅ Configuration appliquée au pupitre:", pupitre.name)
                    }
                }
            }
            
            currentPreset = presetName
            console.log("✅ Preset chargé avec succès:", presetName)
            presetLoaded(presetName)
            return true
            
        } catch (e) {
            console.error("❌ Erreur chargement preset:", e)
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
            
            console.log("✅ Presets importés:", successCount + "/" + importedPresets.length)
            return { success: true, imported: successCount, total: importedPresets.length }
            
        } catch (e) {
            console.error("❌ Erreur import presets:", e)
            presetError("Erreur import presets: " + e.message)
            return { success: false, error: e.message }
        }
    }
}
