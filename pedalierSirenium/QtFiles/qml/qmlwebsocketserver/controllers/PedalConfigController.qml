import QtQuick
import "../config.js" as Config  // ← Import relatif disque

Item {
    id: root
    property var logger
    
    // Structure pour stocker toutes les configurations
    property var pedalConfigs: ({})
    property int updateCounter: 0
    property int getValuesCallCount: 0
    
    // Signal émis quand une valeur change
    signal configValueChanged(int pedalId, int sirenId, string controller, real value, string presetName)
    
    function initializeConfigsOnCreation() {
        if (logger) logger.info("PRESET", "🔧 Initialisation immédiate des configs...");
        let configs = {};
        
        for (let p = 1; p <= Config.pedals.count; p++) {
            configs[p] = {};
            for (let s = 1; s <= Config.sirens.count; s++) {
                configs[p][s] = {};
                
                // Utiliser la config
                for (let name of Config.controllers.order) {
                    configs[p][s][name] = Config.controllers.definitions[name].default;
                }
            }
        }
        return configs;
    }
    
    Component.onCompleted: {
        pedalConfigs = initializeConfigsOnCreation();
    }
    
    function getControllerName(index) {
        return Config.getControllerName(index);
    }
    
    // Convertir un tableau de valeurs en objet indexé par nom de contrôleur
    function arrayToControllerObject(controllersArray) {
        if (!Array.isArray(controllersArray)) return {};
        
        let obj = {};
        for (let i = 0; i < Math.min(controllersArray.length, Config.controllers.order.length); i++) {
            let controllerName = Config.controllers.order[i];
            obj[controllerName] = controllersArray[i];
        }
        return obj;
    }
    
    // Convertir un objet indexé par nom en tableau dans l'ordre défini
    function controllerObjectToArray(controllersObject) {
        if (!controllersObject) return [];
        
        return Config.controllers.order.map(controllerName => {
            return controllersObject[controllerName] || Config.controllers.definitions[controllerName].default;
        });
    }
    
    // Charger les configurations depuis le JSON reçu
    function loadConfigs(jsonData) {
        if (!jsonData.pedals) return;
        
        let configs = {};
        for (let pedalData of jsonData.pedals) {
            let pedalId = pedalData.pedalId;
            configs[pedalId] = {};
            
            for (let sirenData of pedalData.sirens) {
                let sirenId = sirenData.sirenId;
                // Convertir le tableau en objet indexé par nom de contrôleur
                configs[pedalId][sirenId] = arrayToControllerObject(sirenData.controllers);
            }
        }
        pedalConfigs = configs;
        if (logger) logger.info("PRESET", "✅ Configurations chargées pour", Object.keys(configs).length, "pédales");
    }
    
    // Obtenir une valeur spécifique
    function getValue(pedalId, sirenId, controller) {
        if (pedalConfigs[pedalId] && 
            pedalConfigs[pedalId][sirenId] && 
            pedalConfigs[pedalId][sirenId].hasOwnProperty(controller)) {
            return pedalConfigs[pedalId][sirenId][controller];
        }
        return 0;
    }
    
    property int refreshTrigger: 0
    property var clipboardConfig: null  // Stockage temporaire pour copier/coller
    property int clipboardPedalId: -1   // Pour savoir quelle pédale a été copiée
    property var availablePresets: []  // Liste des presets disponibles
    property string currentPresetName: "default"  // Nom du preset actuellement chargé

    // Préparer les données pour la sauvegarde
    function preparePresetData(presetName) {
        return {
            name: presetName,
            pedals: Object.keys(pedalConfigs).map(pedalId => ({
                pedalId: parseInt(pedalId),
                sirens: Object.keys(pedalConfigs[pedalId]).map(sirenId => ({
                    sirenId: parseInt(sirenId),
                    controllers: controllerObjectToArray(pedalConfigs[pedalId][sirenId])
                }))
            }))
        };
    }

    // Charger un preset reçu
    function loadPreset(message) {
        if (!message || !message.pedals) return false;
        
        // Tout est déjà au bon niveau
        currentPresetName = message.name || "custom";
        
        let configs = {};
        for (let pedalData of message.pedals) {
            let pedalId = pedalData.pedalId;
            configs[pedalId] = {};
            
            for (let sirenData of pedalData.sirens) {
                let sirenId = sirenData.sirenId;
                // Convertir le tableau en objet indexé par nom de contrôleur
                configs[pedalId][sirenId] = arrayToControllerObject(sirenData.controllers);
            }
        }
        
        pedalConfigs = configs;
        updateCounter++; // Forcer la mise à jour
        if (logger) logger.info("PRESET", "✅ Preset '", currentPresetName, "' chargé");
        
        // Force mise à jour après un délai pour s'assurer que l'interface est prête
        Qt.callLater(function() {
            updateCounter++;
            if (logger) logger.debug("PRESET", "🔄 Force seconde mise à jour des knobs");
        });
        return true;
    }

    // Mettre à jour la liste des presets disponibles
    function updatePresetList(presets) {
        availablePresets = presets || [];
        if (logger) logger.info("PRESET", "📋", availablePresets.length, "presets disponibles");
    }    
    // Copier la configuration d'une pédale
    function copyPedalConfig(pedalId) {
        if (pedalConfigs[pedalId]) {
            clipboardConfig = JSON.parse(JSON.stringify(pedalConfigs[pedalId])); // Deep copy
            clipboardPedalId = pedalId;
            if (logger) logger.info("KNOB", "📋 Configuration de la pédale", pedalId, "copiée");
            return true;
        }
        return false;
    }
    
    // Coller la configuration sur une pédale
    function pastePedalConfig(pedalId) {
        if (clipboardConfig && clipboardPedalId !== -1) {
            pedalConfigs[pedalId] = JSON.parse(JSON.stringify(clipboardConfig)); // Deep copy
            updateCounter++; // Forcer la mise à jour
            if (logger) logger.info("KNOB", "📋 Configuration collée sur la pédale", pedalId);
            return true;
        }
        return false;
    }
    
    // Vérifier si on a quelque chose dans le presse-papier
    function hasClipboard() {
        return clipboardConfig !== null;
    }
    
    // Définir une valeur et émettre le signal
    function setValue(pedalId, sirenId, controller, value) {
        if (logger) logger.debug("KNOB", "🔵 PedalConfigController.setValue:", pedalId, sirenId, controller, value);
        
        if (!pedalConfigs[pedalId]) {
            pedalConfigs[pedalId] = {};
        }
        if (!pedalConfigs[pedalId][sirenId]) {
            pedalConfigs[pedalId][sirenId] = {};
            // Initialiser avec les valeurs par défaut depuis ControllerMetadata
            for (let name of Config.controllers.order) {
                pedalConfigs[pedalId][sirenId][name] = Config.controllers.definitions[name].default;
            }
        }
        
        pedalConfigs[pedalId][sirenId][controller] = value;
        updateCounter++;
        
        configValueChanged(pedalId, sirenId, controller, value, currentPresetName);
    }
    
    // Fonction pour changer de preset
    function setCurrentPreset(presetName) {
        currentPresetName = presetName;
        if (logger) logger.info("PRESET", "🎯 Preset actuel:", presetName);
    }
    
    // Obtenir toutes les valeurs pour une sirène (dans l'ordre des contrôleurs)
    function getValuesForSiren(pedalId, sirenId) {
        if (!pedalConfigs[pedalId] || !pedalConfigs[pedalId][sirenId]) {
            // Retourner les valeurs par défaut depuis ControllerMetadata
            return Config.controllers.order.map(name => 
                Config.controllers.definitions[name].default
            );
        }
        
        let config = pedalConfigs[pedalId][sirenId];
        // Utiliser l'ordre défini dans ControllerMetadata
        return Config.controllers.order.map(name => 
            config[name] || Config.controllers.definitions[name].default
        );
    }
}