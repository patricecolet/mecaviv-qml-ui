import QtQuick

QtObject {
    // Debug
    property bool debugWebSocket: false
    property bool debugAnimations: false
    property bool debugControllers: false
    
    // Affichage
    property bool showMessageLogger: false
    property bool showPerformanceStats: false
    property bool showAdvancedControls: false
    
    // Comportement
    property bool autoReconnect: true
    property int reconnectDelay: 5000
    
    // Sauvegarde des préférences
    function save() {
        // Sauvegarder dans localStorage si nécessaire
    }
    
    function load() {
        // Charger depuis localStorage
    }
}
