import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id: root
    // Rendre l'Item transparent et non-interactif quand invisible

    property var configController: null
    
    onConfigControllerChanged: {
    }
    property var webSocketController: null
    
    Component.onCompleted: {
    }
    
    onWebSocketControllerChanged: {
    }
        // Test temporaire
        
    signal close()
    
    // Panneau principal (sans fond noir transparent)
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 900)
        height: Math.min(parent.height * 0.9, 700)
        color: "#1a1a1a"
        border.color: "#FFD700"
        border.width: 2
        radius: 10
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // En-tête avec switch mode et bouton fermer
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                
                // Switch Mode Admin/Restricted
                RowLayout {
                    spacing: 10
                    
                    Text {
                        text: "Mode:"
                        color: "#bbb"
                        font.pixelSize: 14
                    }
                    
                    Switch {
                        id: modeSwitch
                        checked: configController ? configController.mode === "admin" : false
                        
                        onCheckedChanged: {
                            if (configController) {
                                var newMode = checked ? "admin" : "restricted"
                                configController.setMode(newMode)
                            }
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 50
                            implicitHeight: 25
                            x: modeSwitch.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 12.5
                            color: modeSwitch.checked ? "#FFD700" : "#444"
                            border.color: modeSwitch.checked ? "#FFD700" : "#666"
                            
                            Rectangle {
                                x: modeSwitch.checked ? parent.width - width - 2 : 2
                                width: 21
                                height: 21
                                radius: 10.5
                                color: "white"
                                border.color: "#ccc"
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Behavior on x {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }
                    }
                    
                    Text {
                        text: modeSwitch.checked ? "ADMIN" : "RESTRICTED"
                        color: modeSwitch.checked ? "#FFD700" : "#888"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Bouton Fermer
                Button {
                    text: "✕"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: parent.hovered ? "#ff3333" : "#2a2a2a"
                        radius: 5
                    }
                    
                    onClicked: root.close()
                }
            }
            
            // Onglets qui prennent toute la largeur
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#0a0a0a"
                }
                
                TabButton {
                    text: "Sirènes"
                    // Ne pas définir width ici
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#FFD700" : "#888"
                        font.pixelSize: 14
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: parent.checked ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                        border.color: parent.checked ? "#FFD700" : "transparent"
                        border.width: parent.checked ? 2 : 0
                        radius: 5
                    }
                }
                
                TabButton {
                    text: "Visibilité"
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#FFD700" : "#888"
                        font.pixelSize: 14
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: parent.checked ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                        border.color: parent.checked ? "#FFD700" : "transparent"
                        border.width: parent.checked ? 2 : 0
                        radius: 5
                    }
                }
                
                TabButton {
                    text: "Avancé"
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#FFD700" : "#888"
                        font.pixelSize: 14
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: parent.checked ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                        border.color: parent.checked ? "#FFD700" : "transparent"
                        border.width: parent.checked ? 2 : 0
                        radius: 5
                    }
                }
                
                TabButton {
                    text: "Sorties"
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#FFD700" : "#888"
                        font.pixelSize: 14
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: parent.checked ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                        border.color: parent.checked ? "#FFD700" : "transparent"
                        border.width: parent.checked ? 2 : 0
                        radius: 5
                    }
                }
            }
            
            // Contenu des onglets
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: {
                    switch(tabBar.currentIndex) {
                        case 0: return "SirenSelectionSection.qml"
                        case 1: return "VisibilitySection.qml"
                        case 2: return "AdvancedSection.qml"
                        case 3: return "OutputSection.qml"
                        default: return ""
                    }
                }
                
                onLoaded: {
                    
                    if (item) {
                        // Assigner configController en premier
                        item.configController = root.configController
                        
                        if (item.hasOwnProperty("webSocketController")) {
                            item.webSocketController = root.webSocketController
                        }
                    }
                }
            }
        }
    }
}
