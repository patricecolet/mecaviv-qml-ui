import QtQuick 2.15

QtObject {
    id: configController
    
    // Propriétés
    property var config: null
    property bool isLoaded: false
    
    // Référence au ConfigManager principal
    property var configManager: null
    
    // Initialisation
    Component.onCompleted: {
        // ConfigController initialisé
        // Ne plus charger de configuration par défaut
        // La configuration sera chargée par ConfigManager
    }
    
    // Charger la configuration depuis ConfigManager
    function loadConfig() {
        // Chargement de la configuration via ConfigManager
        
        if (configManager && configManager.config) {
            config = configManager.config
            isLoaded = true
            // Configuration chargée depuis ConfigManager
        } else {
            // ConfigManager non disponible
            isLoaded = false
        }
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
        if (!config || !config.pupitres) {
            return []
        }
        return config.pupitres
    }
    
    // Sauvegarder la configuration
    function saveConfig() {
        // Sauvegarde de la configuration
        // TODO: Implémenter la sauvegarde vers un fichier
        return true
    }
    
    // Charger la configuration depuis un fichier
    function loadConfigFromFile(filePath) {
        // Chargement de la configuration depuis fichier
        // Déléguer au ConfigManager
        if (configManager) {
            return configManager.loadConfigFromFile(filePath)
        }
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
            // Configuration importée avec succès
            return true
        } catch (e) {
            // Erreur lors de l'import de la configuration
            return false
        }
    }
}