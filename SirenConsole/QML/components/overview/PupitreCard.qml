import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: pupitreCard
    
    // Propriétés
    property var pupitreData: null
    property var consoleController: null
    
    // Dimensions
    width: 300
    height: 200
    
    // Style
    color: "#2a2a2a"
    radius: 10
    border.color: getBorderColor()
    border.width: 2
    
    // Couleur de bordure selon le statut
    function getBorderColor() {
        if (!pupitreData) return "#444444"
        
        switch (pupitreData.status) {
            case "connected": return "#F18F01"
            case "connecting": return "#2E86AB"
            case "error": return "#C73E1D"
            case "disconnected": return "#444444"
            default: return "#444444"
        }
    }
    
    // Layout principal
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // En-tête avec nom et statut
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text {
                text: pupitreData ? pupitreData.name : "Pupitre"
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
            }
            
            Item { Layout.fillWidth: true }
            
            StatusIndicator {
                status: pupitreData ? pupitreData.status : "disconnected"
                size: 12
            }
        }
        
        // Informations de connexion
        Text {
            text: pupitreData ? `${pupitreData.host}:${pupitreData.port}` : "N/A"
            font.pixelSize: 12
            color: "#cccccc"
        }
        
        // Statut détaillé
        Text {
            text: pupitreData ? `Sirène: ${pupitreData.currentSiren} | Note: ${pupitreData.currentNote}` : "N/A"
            font.pixelSize: 11
            color: "#aaaaaa"
        }
        
        // Mode fretté
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            
            Text {
                text: "Fretté:"
                font.pixelSize: 11
                color: "#aaaaaa"
            }
            
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: pupitreData && pupitreData.frettedMode ? "#F18F01" : "#666666"
                border.color: "#ffffff"
                border.width: 1
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pupitreData && consoleController && pupitreData.status === "connected") {
                            console.log("🎯 Basculement mode fretté pupitre", pupitreData.id)
                            consoleController.toggleFrettedMode(pupitreData.id)
                        }
                    }
                }
            }
        }
        
        // Dernière mise à jour
        Text {
            text: pupitreData ? `Dernière MAJ: ${pupitreData.lastSeen}` : "N/A"
            font.pixelSize: 10
            color: "#888888"
        }
        
        Item { Layout.fillHeight: true }
        
        // Boutons de contrôle
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            // Bouton de connexion/reconnexion
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                text: pupitreData && pupitreData.status === "connected" ? "Déconnecter" : "Connecter"
                background: Rectangle {
                    color: parent.pressed ? "#1a1a1a" : (pupitreData && pupitreData.status === "connected" ? "#C73E1D" : "#2E86AB")
                    radius: 5
                    border.color: "#ffffff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (pupitreData && consoleController) {
                        if (pupitreData.status === "connected") {
                            console.log("🔌 Déconnexion pupitre", pupitreData.id)
                            consoleController.disconnectPupitre(pupitreData.id)
                        } else {
                            console.log("🔌 Connexion pupitre", pupitreData.id)
                            consoleController.connectPupitre(pupitreData.id, pupitreData.host, pupitreData.port)
                        }
                    }
                }
            }
            
            // Bouton de configuration
            Button {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                text: "⚙️"
                background: Rectangle {
                    color: parent.pressed ? "#1a1a1a" : "#A23B72"
                    radius: 5
                    border.color: "#ffffff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (pupitreData) {
                        console.log("⚙️ Configuration pupitre", pupitreData.id)
                        // TODO: Ouvrir panneau de configuration du pupitre
                    }
                }
            }
        }
    }
    
    // Effet de survol
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            parent.color = "#333333"
        }
        
        onExited: {
            parent.color = "#2a2a2a"
        }
        
        onClicked: {
            if (pupitreData) {
                console.log("🖱️ Clic sur pupitre", pupitreData.id)
                // TODO: Ouvrir vue détaillée du pupitre
            }
        }
    }
}
