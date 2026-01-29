import QtQuick
import QtQuick.Controls
import "../components"
import "../components/ambitus"

Page {
    id: root
    title: "Test Composants 2D"
    
    property color accentColor: "#00CED1"
    property color backgroundColor: "#1a1a1a"
    property bool uiControlsEnabled: true
    property bool isGamePlaying: false
    property bool gameMode: false
    
    // Propriétés de test (simuler sirenController et configController)
    property var sirenInfo: {
        return {
            name: "S1",
            ambitus: { min: 48, max: 84 },
            clef: "treble",
            mode: "restricted",
            restrictedMax: 72,
            displayOctaveOffset: 0
        }
    }
    property var configController: null  // Peut être null pour les tests
    property real midiNote: 69.0
    property real clampedNote: 69.0
    property string noteName: "La4"
    property real rpm: 1200
    property int frequency: 440
    
    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        
        // Conteneur pour les éléments 2D (comme dans SirenDisplay)
        Item {
            id: infoContainer
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            
            // Mode ADMIN - Menu déroulant pour sélectionner une sirène
            ComboBox {
                id: sirenSelector
                width: 80
                height: 40
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                visible: configController && configController.mode === "admin"
                
                // Modèle des sirènes (pour test)
                model: configController && configController.config ? configController.config.sirenConfig.sirens : [
                    { id: "1", name: "S1" },
                    { id: "2", name: "S2" }
                ]
                textRole: "name"
                valueRole: "id"
                
                // Style personnalisé (identique à SirenDisplay)
                delegate: ItemDelegate {
                    width: sirenSelector.width
                    contentItem: Text {
                        text: modelData.name
                        color: "#ffffff"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3a3a3a" : "#2a2a2a"
                        border.color: root.accentColor
                        border.width: parent.hovered ? 1 : 0
                    }
                }
                
                contentItem: Text {
                    leftPadding: 10
                    rightPadding: sirenSelector.indicator.width + sirenSelector.spacing
                    text: sirenSelector.displayText
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: "#2a2a2a"
                    border.color: root.accentColor
                    border.width: 2
                    radius: 6
                }
                
                popup: Popup {
                    y: sirenSelector.height - 1
                    width: sirenSelector.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 1
                    
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: sirenSelector.popup.visible ? sirenSelector.delegateModel : null
                        currentIndex: sirenSelector.highlightedIndex
                        
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }
                    
                    background: Rectangle {
                        color: "#2a2a2a"
                        border.color: root.accentColor
                        border.width: 1
                        radius: 6
                    }
                }
            }
            
            // Mode RESTRICTED - Beau label circulaire (non cliquable)
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#2a2a2a"
                border.color: root.accentColor
                border.width: 2
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                visible: !configController || configController.mode === "restricted"
                
                Text {
                    anchors.centerIn: parent
                    text: root.sirenInfo ? root.sirenInfo.name : "S1"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffffff"
                }
            }
            
            // Indicateur des positions GearShift (overlay 2D)
            GearShiftPositionIndicator {
                anchors.fill: parent
                visible: true
                currentPosition: configController ? (configController.gearShiftPosition || 0) : 0
                configController: root.configController
            }
        }
        
        // Zone inférieure - Contrôleurs (peut être affiché/masqué)
        ControllersPanel {
            id: controllersPanel
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.35
            configController: root.configController
            webSocketController: null  // Pas nécessaire pour les tests
            visible: configController ? configController.getValueAtPath(["controllersPanel", "visible"], false) : false
        }
        
        // Bouton pour basculer le panneau des contrôleurs (en haut à droite)
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.rightMargin: 20
            width: 100
            height: 35
            color: "#2a2a2a"
            border.color: configController && configController.getValueAtPath(["controllersPanel", "visible"], false) ? "#00ff00" : "#FFD700"
            radius: 5
            visible: root.uiControlsEnabled
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (configController) {
                        var currentValue = configController.getValueAtPath(["controllersPanel", "visible"], false)
                        configController.setValueAtPath(["controllersPanel", "visible"], !currentValue)
                    } else {
                        controllersPanel.visible = !controllersPanel.visible
                    }
                }
            }
            
            Text {
                text: controllersPanel.visible ? "Masquer" : "Contrôleurs"
                color: "white"
                font.pixelSize: 12
                anchors.centerIn: parent
            }
        }
        
        // Bouton pour basculer le mode fretté (au 1/4 de l'écran en bas)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            x: parent.width * 0.25 - width / 2
            width: 140
            height: 60
            color: "#2a2a2a"
            border.color: "#FFD700"
            border.width: 2
            radius: 5
            visible: root.uiControlsEnabled && !root.gameMode && !controllersPanel.visible
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Action de test (peut être connectée plus tard)
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: "Fretté OFF"
                    color: "#FFD700"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "↓ Bouton physique"
                    color: "#888"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Bouton Play/Stop pour le mode jeu (au 1/4 de l'écran en bas, visible uniquement en mode jeu)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            x: parent.width * 0.25 - width / 2
            width: 140
            height: 60
            color: root.isGamePlaying ? "#1a5a3a" : "#2a2a2a"
            border.color: root.isGamePlaying ? "#4ade80" : "#6bb6ff"
            border.width: 2
            radius: 5
            visible: root.gameMode && root.uiControlsEnabled
            
            // Animation de pulsation quand en lecture
            SequentialAnimation on opacity {
                running: root.isGamePlaying && root.gameMode
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.7; duration: 800 }
                NumberAnimation { from: 0.7; to: 1.0; duration: 800 }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.isGamePlaying = !root.isGamePlaying
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: root.isGamePlaying ? "⏹ Stop" : "▶︎ Play"
                    color: root.isGamePlaying ? "#4ade80" : "#fff"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "↓ Bouton physique"
                    color: root.isGamePlaying ? "#4ade80" : "#888"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Bouton pour basculer en mode jeu (au 3/4 de l'écran en bas)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            x: parent.width * 0.75 - width / 2
            width: 140
            height: 60
            color: root.gameMode ? "#00CED1" : "#2a2a2a"
            border.color: "#00CED1"
            border.width: 2
            radius: 5
            visible: root.uiControlsEnabled && !controllersPanel.visible
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.gameMode = !root.gameMode
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    text: root.gameMode ? "Mode Normal" : "Mode Jeu"
                    color: root.gameMode ? "#000" : "#00CED1"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "↓ Bouton physique"
                    color: root.gameMode ? "#000" : "#888"
                    font.pixelSize: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Bouton Admin (en haut à gauche)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            width: 80
            height: 40
            color: mouseAreaAdmin.containsMouse ? "#3a3a3a" : "#2a2a2a"
            border.color: "#666"
            radius: 5
            visible: root.uiControlsEnabled
            
            MouseArea {
                id: mouseAreaAdmin
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    // Action de test (peut être connectée plus tard)
                }
            }
            
            Text {
                text: "ADMIN"
                color: "#888"
                font.pixelSize: 14
                font.bold: true
                anchors.centerIn: parent
            }
        }
        
        // Bandeau "Console connectée" (en haut à droite)
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.rightMargin: 20
            width: 180
            height: 35
            color: "#FFD700"
            border.color: "#FFA500"
            border.width: 2
            radius: 8
            visible: configController && configController.consoleConnected
            
            Text {
                text: "🎛️ CONSOLE CONNECTÉE"
                color: "#000"
                font.pixelSize: 14
                font.bold: true
                anchors.centerIn: parent
            }
        }
        
        // Zone de test pour les composants 2D migrés
        ScrollView {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 150  // Laisser de la place pour les éléments existants
            
            Column {
                width: parent.width
                spacing: 30
                padding: 20
                
                Text {
                    width: parent.width
                    text: "Composants 2D à tester"
                    font.pixelSize: 20
                    font.bold: true
                    color: root.accentColor
                    horizontalAlignment: Text.AlignHCenter
                }
                
                // Les composants 2D seront ajoutés ici au fur et à mesure
                // Exemple pour NumberDisplay2D :
                // NumberDisplay2D {
                //     value: root.rpm
                //     label: "RPM"
                // }
                
                // Exemple pour NoteDisplay2D :
                // NoteDisplay2D {
                //     noteName: root.noteName
                //     midiNote: root.midiNote
                //     velocity: 100
                //     pitchBend: 0
                // }
            }
        }
    }
}
