import QtQuick

Item {
    id: root
    
    // Propriétés requises
    property int currentPosition: 0
    property var configController: null
    
    // Debug logs
    onCurrentPositionChanged: {
    }
    
    // Propriétés configurables
    property var positions: [1, 2, 4, 12, 24]  // Valeurs par défaut (demi-tons)
    
    // Mise à jour des positions depuis la config
    onConfigControllerChanged: {
        if (configController) {
            updatePositions()
        }
    }
    
    function updatePositions() {
        if (!configController) return
        
        var gearShiftConfig = configController.getConfigValue("displayConfig.components.musicalStaff.gearShiftIndicator.positions", [1, 2, 4, 12, 24])
        if (Array.isArray(gearShiftConfig)) {
            positions = gearShiftConfig
        }
    }
    
    // Conteneur principal - overlay 2D
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        spacing: 10
        
        // Titre
        Text {
            text: "VITESSE"
            font.pixelSize: 12
            font.bold: true
            color: "#CCCCCC"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Croix des 5 positions
        Item {
            width: 120
            height: 120
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Position 0: Centre (1)
            Rectangle {
                id: centerPos
                width: 30
                height: 25
                radius: 3
                color: root.currentPosition === 0 ? "#4A90E2" : "#2A2A2A"
                border.color: root.currentPosition === 0 ? "#6BB6FF" : "#555555"
                border.width: 1
                anchors.centerIn: parent
                
                Text {
                    anchors.centerIn: parent
                    text: root.positions[0] ? root.positions[0].toString() : "1"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.currentPosition === 0 ? "#FFFFFF" : "#CCCCCC"
                }
            }
            
            // Position 1: Gauche (2)
            Rectangle {
                id: leftPos
                width: 30
                height: 25
                radius: 3
                color: root.currentPosition === 1 ? "#4A90E2" : "#2A2A2A"
                border.color: root.currentPosition === 1 ? "#6BB6FF" : "#555555"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: centerPos.left
                anchors.rightMargin: 10
                
                Text {
                    anchors.centerIn: parent
                    text: root.positions[1] ? root.positions[1].toString() : "2"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.currentPosition === 1 ? "#FFFFFF" : "#CCCCCC"
                }
            }
            
            // Position 2: Bas (4)
            Rectangle {
                id: bottomPos
                width: 30
                height: 25
                radius: 3
                color: root.currentPosition === 2 ? "#4A90E2" : "#2A2A2A"
                border.color: root.currentPosition === 2 ? "#6BB6FF" : "#555555"
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: centerPos.bottom
                anchors.topMargin: 10
                
                Text {
                    anchors.centerIn: parent
                    text: root.positions[2] ? root.positions[2].toString() : "4"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.currentPosition === 2 ? "#FFFFFF" : "#CCCCCC"
                }
            }
            
            // Position 3: Droite (12)
            Rectangle {
                id: rightPos
                width: 30
                height: 25
                radius: 3
                color: root.currentPosition === 3 ? "#4A90E2" : "#2A2A2A"
                border.color: root.currentPosition === 3 ? "#6BB6FF" : "#555555"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: centerPos.right
                anchors.leftMargin: 10
                
                Text {
                    anchors.centerIn: parent
                    text: root.positions[3] ? root.positions[3].toString() : "12"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.currentPosition === 3 ? "#FFFFFF" : "#CCCCCC"
                }
            }
            
            // Position 4: Haut (24)
            Rectangle {
                id: topPos
                width: 30
                height: 25
                radius: 3
                color: root.currentPosition === 4 ? "#4A90E2" : "#2A2A2A"
                border.color: root.currentPosition === 4 ? "#6BB6FF" : "#555555"
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: centerPos.top
                anchors.bottomMargin: 10
                
                Text {
                    anchors.centerIn: parent
                    text: root.positions[4] ? root.positions[4].toString() : "24"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.currentPosition === 4 ? "#FFFFFF" : "#CCCCCC"
                }
            }
        }
    }
}
