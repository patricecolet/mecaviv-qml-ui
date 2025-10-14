import QtQuick
import QtQuick.Controls

/**
 * Barre de comparaison contrôleur actuel vs cible
 * Affiche visuellement l'écart entre la position jouée et la position attendue
 */
Rectangle {
    id: root
    
    property string controllerName: "Contrôleur"
    property real currentValue: 0
    property real targetValue: 0
    property real maxValue: 127
    
    height: 50
    color: "#20FFFFFF"
    radius: 5
    border.color: "#40FFFFFF"
    border.width: 1
    
    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        // Nom du contrôleur
        Text {
            width: 100
            text: root.controllerName
            font.pixelSize: 16
            font.bold: true
            color: "#FFFFFF"
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Barre de progression
        Rectangle {
            width: parent.width - 250
            height: 30
            color: "#333333"
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            
            // Fond gradué (repères visuels)
            Row {
                anchors.fill: parent
                spacing: 0
                
                Repeater {
                    model: 10
                    
                    Rectangle {
                        width: parent.width / 10
                        height: parent.height
                        color: index % 2 === 0 ? "#2a2a2a" : "#333333"
                    }
                }
            }
            
            // Valeur actuelle (barre bleue)
            Rectangle {
                id: currentBar
                width: parent.width * (root.currentValue / root.maxValue)
                height: parent.height
                color: "#00CED1"
                radius: 4
                opacity: 0.7
                
                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
            }
            
            // Valeur cible (indicateur rouge)
            Rectangle {
                id: targetIndicator
                x: (parent.width * (root.targetValue / root.maxValue)) - (width / 2)
                width: 4
                height: parent.height + 10
                y: -5
                color: "#FF0000"
                radius: 2
                
                // Glow
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: parent.height
                    color: "transparent"
                    border.color: "#FF0000"
                    border.width: 2
                    radius: 3
                    opacity: 0.5
                }
                
                Behavior on x {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
            
            // Zone de tolérance (autour de la cible)
            Rectangle {
                x: Math.max(0, (parent.width * (root.targetValue / root.maxValue)) - 15)
                width: 30
                height: parent.height
                color: "#00FF00"
                radius: 4
                opacity: 0.2
                
                Behavior on x {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
            
            // Indicateur de précision (affiche si on est dans la zone)
            Rectangle {
                anchors.top: parent.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: targetIndicator.horizontalCenter
                width: 60
                height: 20
                color: isInRange ? "#00FF00" : "#FF0000"
                radius: 3
                opacity: 0.8
                visible: root.targetValue > 0
                
                property bool isInRange: Math.abs(root.currentValue - root.targetValue) <= (root.maxValue * 0.1)
                
                Text {
                    anchors.centerIn: parent
                    text: parent.isInRange ? "✓ OK" : "✗"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#FFFFFF"
                }
            }
        }
        
        // Valeurs numériques
        Column {
            width: 100
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            
            // Valeur actuelle
            Row {
                spacing: 5
                
                Text {
                    text: "Actuel:"
                    font.pixelSize: 11
                    color: "#888888"
                }
                
                Text {
                    text: Math.round(root.currentValue)
                    font.pixelSize: 13
                    font.bold: true
                    color: "#00CED1"
                }
            }
            
            // Valeur cible
            Row {
                spacing: 5
                visible: root.targetValue > 0
                
                Text {
                    text: "Cible:"
                    font.pixelSize: 11
                    color: "#888888"
                }
                
                Text {
                    text: Math.round(root.targetValue)
                    font.pixelSize: 13
                    font.bold: true
                    color: "#FF6600"
                }
            }
            
            // Écart
            Row {
                spacing: 5
                visible: root.targetValue > 0
                
                Text {
                    text: "Écart:"
                    font.pixelSize: 10
                    color: "#666666"
                }
                
                Text {
                    text: {
                        var diff = Math.round(root.currentValue - root.targetValue)
                        return (diff >= 0 ? "+" : "") + diff
                    }
                    font.pixelSize: 11
                    color: Math.abs(root.currentValue - root.targetValue) <= (root.maxValue * 0.1) ? "#00FF00" : "#FF6600"
                }
            }
        }
    }
}

