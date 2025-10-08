import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../utils"
import "../controls"
import "./"

Row {
    id: root
    property var overlayContainer
    signal debugPanelToggle()
    
    // Propriétés exposées
    required property var wsController
    required property var tempoControl
    required property var sirenView
    required property var pedalConfigController
    required property var sceneManager
    property var logger
    
    spacing: 20
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.bottomMargin: 20
    anchors.leftMargin: 20
    z: 10000
    
    // Indicateur de statut
    ConnectionStatus {
        wsController: root.wsController
    }
    
    // Contrôle de tempo (référence externe)
    Item {
        width: root.tempoControl.width
        height: root.tempoControl.height
        // Le TempoControl est ajouté dynamiquement
    }
    
    // Bouton config
    ConfigModeButton {
        id: configButton
        sirenView: root.sirenView
        height: root.tempoControl.height
    }
    
    // Bouton Scènes
    Rectangle {
        id: scenesButton
        width: 120
        height: root.tempoControl.height
        color: scenesMouseArea.pressed ? "#505050" : (root.sirenView.scenesMode ? "#606060" : "#404040")
        border.color: root.sirenView.scenesMode ? "lime" : "#808080"
        border.width: 2
        radius: 6
        visible: !root.sirenView.configMode // Masquer pendant config pédale
        
        Row {
            anchors.centerIn: parent
            spacing: 4
            
            Image {
                source: "qrc:/qml/icons/theater.png"
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }
            
            Text {
                text: "Scènes"
                color: "white"
                font.pixelSize: 18
                font.bold: root.sirenView.scenesMode
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: scenesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: false
            enabled: true
            onClicked: {
                root.sirenView.toggleScenesMode()
            }
        }
        
        // Tooltip
        ToolTip.text: root.sirenView.scenesMode ? "Fermer gestionnaire de scènes" : "Ouvrir gestionnaire de scènes"
        ToolTip.visible: scenesMouseArea.containsMouse
        ToolTip.delay: 500
    }
    
    // Indicateur de pages de scènes
    ScenePageIndicator {
        id: scenePageIndicator
        height: root.tempoControl.height
        visible: !root.sirenView.configMode  // Masquer en mode config pédale
        currentPage: root.sceneManager ? root.sceneManager.currentPage : 1
        pageCount: 8
        activeSceneId: root.sceneManager ? root.sceneManager.currentScene : 0
        sceneManager: root.sceneManager
        hasScene: function(globalSceneId) { 
            return root.sceneManager ? root.sceneManager.hasScene(globalSceneId) : false;
        }
    }
    
    // Contrôles pédale - DIRECTEMENT ICI au lieu de PedalControlsRow
    Row {
        visible: root.sirenView.configMode
        spacing: 5
        
        // Bouton Copier
        Rectangle {
            width: 60
            height: 40
            color: copyMouseArea.pressed ? "#505050" : "#404040"
            border.color: "#808080"
            border.width: 2
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "Copier"
                color: "white"
                font.pixelSize: 12
            }
            
            MouseArea {
                id: copyMouseArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: false
                enabled: true
                onClicked: {
                    root.pedalConfigController.copyPedalConfig(root.sirenView.selectedPedalId);
                }
            }
        }
        
        // Sélecteur de pédale
        Row {
            spacing: 5
            
            Repeater {
                model: 8
                Rectangle {
                    width: 35
                    height: 40
                    color: (index + 1) === root.sirenView.selectedPedalId ? "#606060" : "#404040"
                    border.color: "#808080"
                    border.width: 2
                    radius: 3
                    
                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: "white"
                        font.pixelSize: 16
                        font.bold: (index + 1) === root.sirenView.selectedPedalId
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: false
                        enabled: true
                        onClicked: {
                            root.sirenView.selectedPedalId = index + 1;
                        }
                    }
                }
            }
        }
        
        // Bouton Coller
        Rectangle {
            width: 60
            height: 40
            color: pasteMouseArea.pressed ? "#505050" : "#404040"
            border.color: root.pedalConfigController.hasClipboard ? "#808080" : "#404040"
            border.width: 2
            radius: 3
            opacity: root.pedalConfigController.hasClipboard ? 1.0 : 0.5
            
            Text {
                anchors.centerIn: parent
                text: "Coller"
                color: "white"
                font.pixelSize: 12
            }
            
            MouseArea {
                id: pasteMouseArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: false
                enabled: true
                onClicked: {
                    root.pedalConfigController.pastePedalConfig(root.sirenView.selectedPedalId);
                }
            }
        }
        
        // Gestionnaire de presets
        PedalPresetManager {
            pedalConfigController: root.pedalConfigController
            webSocketController: root.wsController
            overlayContainer: root.overlayContainer
            logger: root.logger
        }
    }
}