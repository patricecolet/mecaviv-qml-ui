import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: statusIndicator
    
    // Propriétés
    property string status: "disconnected"
    property int size: 12
    
    // Dimensions
    width: size
    height: size
    radius: size / 2
    
    // Couleur selon le statut
    color: getStatusColor()
    border.color: "#ffffff"
    border.width: 1
    
    // Animation de pulsation pour les statuts actifs
    SequentialAnimation on opacity {
        running: status === "connecting" || status === "connected"
        loops: Animation.Infinite
        NumberAnimation { to: 0.5; duration: 1000 }
        NumberAnimation { to: 1.0; duration: 1000 }
    }
    
    // Couleur selon le statut
    function getStatusColor() {
        switch (status) {
            case "connected": return "#F18F01"    // Orange - Connecté
            case "connecting": return "#2E86AB"   // Bleu - Connexion en cours
            case "error": return "#C73E1D"        // Rouge - Erreur
            case "disconnected": return "#666666" // Gris - Déconnecté
            default: return "#666666"
        }
    }
    
    // Tooltip avec informations détaillées
    ToolTip {
        id: tooltip
        visible: statusIndicatorMouseArea.containsMouse
        text: getStatusText()
        delay: 500
    }
    
    function getStatusText() {
        switch (status) {
            case "connected": return "Connecté - Communication active"
            case "connecting": return "Connexion en cours..."
            case "error": return "Erreur de connexion"
            case "disconnected": return "Déconnecté"
            default: return "Statut inconnu"
        }
    }
    
    MouseArea {
        id: statusIndicatorMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
