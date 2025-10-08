import QtQuick 2.15
import QtQml.Models 2.15

QtObject {
    id: dataModels
    
    // Modèle pour les pupitres
    function createPupitreModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                // Modèle vide, sera rempli dynamiquement
            }
        ', dataModels)
    }
    
    // Modèle pour les logs
    function createLogModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                // Modèle vide, sera rempli dynamiquement
            }
        ', dataModels)
    }
    
    // Modèle pour les sirènes
    function createSirenModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                ListElement { id: "1"; name: "S1"; description: "Sirène 1" }
                ListElement { id: "2"; name: "S2"; description: "Sirène 2" }
                ListElement { id: "3"; name: "S3"; description: "Sirène 3" }
                ListElement { id: "4"; name: "S4"; description: "Sirène 4" }
                ListElement { id: "5"; name: "S5"; description: "Sirène 5" }
                ListElement { id: "6"; name: "S6"; description: "Sirène 6" }
                ListElement { id: "7"; name: "S7"; description: "Sirène 7" }
            }
        ', dataModels)
    }
    
    // Modèle pour les statuts de connexion
    function createConnectionStatusModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                ListElement { status: "connected"; text: "Connecté"; color: "#F18F01" }
                ListElement { status: "connecting"; text: "Connexion..."; color: "#2E86AB" }
                ListElement { status: "disconnected"; text: "Déconnecté"; color: "#666666" }
                ListElement { status: "error"; text: "Erreur"; color: "#C73E1D" }
            }
        ', dataModels)
    }
    
    // Modèle pour les niveaux de log
    function createLogLevelModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                ListElement { level: "debug"; text: "Debug"; color: "#1a1a1a" }
                ListElement { level: "info"; text: "Info"; color: "#1a2a4a" }
                ListElement { level: "warning"; text: "Warning"; color: "#4a3a1a" }
                ListElement { level: "error"; text: "Error"; color: "#4a1a1a" }
            }
        ', dataModels)
    }
    
    // Modèle pour les thèmes
    function createThemeModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                ListElement { id: "dark"; name: "Sombre"; description: "Thème sombre" }
                ListElement { id: "light"; name: "Clair"; description: "Thème clair" }
                ListElement { id: "auto"; name: "Automatique"; description: "Thème automatique" }
            }
        ', dataModels)
    }
    
    // Modèle pour les layouts
    function createLayoutModel() {
        return Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                ListElement { id: "grid"; name: "Grille"; description: "Affichage en grille" }
                ListElement { id: "list"; name: "Liste"; description: "Affichage en liste" }
                ListElement { id: "compact"; name: "Compact"; description: "Affichage compact" }
            }
        ', dataModels)
    }
    
    // Fonction utilitaire pour créer un modèle personnalisé
    function createCustomModel(data) {
        var model = Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                // Modèle vide
            }
        ', dataModels)
        
        // Ajouter les données
        if (Array.isArray(data)) {
            for (var i = 0; i < data.length; i++) {
                model.append(data[i])
            }
        }
        
        return model
    }
    
    // Fonction pour filtrer un modèle
    function filterModel(sourceModel, filterFunction) {
        var filteredModel = Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                // Modèle filtré
            }
        ', dataModels)
        
        for (var i = 0; i < sourceModel.count; i++) {
            var item = sourceModel.get(i)
            if (filterFunction(item)) {
                filteredModel.append(item)
            }
        }
        
        return filteredModel
    }
    
    // Fonction pour trier un modèle
    function sortModel(sourceModel, sortFunction) {
        var sortedModel = Qt.createQmlObject('
            import QtQml.Models 2.15
            ListModel {
                // Modèle trié
            }
        ', dataModels)
        
        var items = []
        for (var i = 0; i < sourceModel.count; i++) {
            items.push(sourceModel.get(i))
        }
        
        items.sort(sortFunction)
        
        for (var j = 0; j < items.length; j++) {
            sortedModel.append(items[j])
        }
        
        return sortedModel
    }
}
