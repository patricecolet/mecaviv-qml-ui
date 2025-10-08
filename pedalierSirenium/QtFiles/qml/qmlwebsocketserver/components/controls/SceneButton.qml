import QtQuick
import QtQuick.Controls

Rectangle {
    id: sceneButton
    width: 120
    height: 80
    radius: 8
    border.width: 2
    
    property int pedalPosition: 1
    property int globalSceneId: 1
    property string sceneName: "Vide"
    property int currentScene: -1
    property bool isEmpty: true
    // Nouveau: état actif pilotable
    property bool isActive: currentScene === globalSceneId
    
    signal sceneClicked(int sceneId)
    signal saveRequested(int sceneId)
    
    // Couleurs dynamiques
    color: {
        if (isActive) return "#2a4a2a"
        if (isEmpty) return "#333"
        return "#444"
    }
    
    border.color: {
        if (isActive) return "lime"
        if (isEmpty) return "#555"
        return "#777"
    }
    
    // Animation de survol
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    
    Column {
        anchors.centerIn: parent
        spacing: 4
        
        // Numéro de position pédale
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: isActive ? "lime" : (sceneButton.isEmpty ? "#666" : "#888")
            anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: sceneButton.pedalPosition
                color: isActive ? "black" : "white"
                font.bold: true
                font.pixelSize: 14
                anchors.centerIn: parent
            }
        }
        
        // Nom de la scène ou statut
        Row {
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
            
            Image {
                source: sceneButton.isEmpty ? "qrc:/qml/icons/circle.png" : "qrc:/qml/icons/music.png"
                width: sceneButton.isEmpty ? 11 : 12
                height: sceneButton.isEmpty ? 11 : 12
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                opacity: isActive ? 1.0 : (sceneButton.isEmpty ? 0.5 : 0.8)
            }
            
            Text {
                text: sceneButton.isEmpty ? "Vide" : sceneButton.sceneName
                color: isActive ? "lime" : (sceneButton.isEmpty ? "#888" : "white")
                font.pixelSize: sceneButton.isEmpty ? 11 : 12
                font.bold: !sceneButton.isEmpty
                anchors.verticalCenter: parent.verticalCenter
                width: sceneButton.width - 32
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }
    }
    
    // ID global (petit) - en bas à droite du bouton principal
    Text {
        text: "ID: " + sceneButton.globalSceneId
        color: "#999"
        font.pixelSize: 9
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
    }
    
    // Indicateur d'état en haut à droite
    Rectangle {
        width: 12
        height: 12
        radius: 6
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        
        color: {
            if (isActive) return "lime"
            if (sceneButton.isEmpty) return "transparent"
            return "orange"
        }
        
        border.color: sceneButton.isEmpty ? "#666" : "white"
        border.width: sceneButton.isEmpty ? 1 : 0
        
        // Animation pulse si active
        SequentialAnimation on opacity {
            running: isActive
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 1000 }
            NumberAnimation { to: 1.0; duration: 1000 }
        }
    }
    
    // Zone de clic principal
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            if (!sceneButton.isEmpty) {
                sceneButton.sceneClicked(sceneButton.globalSceneId)
            }
        }
        
        onPressAndHold: {
            // Clic long = sauvegarder dans cette position
            sceneButton.saveRequested(sceneButton.globalSceneId)
        }
        
        onEntered: {
            sceneButton.opacity = 0.8
        }
        
        onExited: {
            sceneButton.opacity = 1.0
        }
    }
    
    // Interface tactile - pas de menu contextuel (remplacé par clic/clic long)
    
    // Effet de press
    scale: mouseArea.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }
    Behavior on opacity { NumberAnimation { duration: 200 } }
    
    // Raccourci clavier
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            if (!sceneButton.isEmpty) {
                sceneButton.sceneClicked(sceneButton.globalSceneId)
            }
            event.accepted = true
        }
    }
} 