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

    // Fond semi-transparent + bloqueur d'événements : empêche le ScrollView/Flickable
    // en dessous d'intercepter les touch events (bug sur Raspberry tactile en WASM).
    Rectangle {
        anchors.fill: parent
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Panneau principal
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 900)
        height: Math.min(parent.height * 0.9, 700)
        color: "#1a1a1a"
        border.color: "#FFD700"
        border.width: 2
        radius: 10
        
        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // URL du contenu d'onglet (réévalué quand on change d'onglet)
            readonly property string tabSource: {
                var base = "qrc:/QML/admin/"
                switch(tabBar.currentIndex) {
                    case 0: return base + "SirenSelectionSection.qml"
                    case 1: return base + "VisibilitySection.qml"
                    case 2: return base + "AdvancedSection.qml"
                    case 3: return base + "OutputSection.qml"
                    default: return ""
                }
            }
            
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

            // Boutons sirènes : même niveau que le TabBar (pas dans le Loader) pour que le touch marche comme les onglets.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 8
                visible: tabBar.currentIndex === 0

                Repeater {
                    model: configController && configController.config && configController.config.sirenConfig
                        ? configController.config.sirenConfig.sirens
                        : []

                    delegate: Button {
                        id: sirenTabBtn
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 44
                        Layout.fillWidth: false

                        property bool isSelected: configController && configController.primarySiren &&
                                                 configController.primarySiren.id === modelData.id

                        contentItem: Text {
                            text: modelData.name
                            color: sirenTabBtn.isSelected ? "black" : "#fff"
                            font.pixelSize: 14
                            font.bold: sirenTabBtn.isSelected
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: sirenTabBtn.isSelected ? "#FFD700" :
                                   (sirenTabBtn.hovered ? "#3a3a3a" : "#2a2a2a")
                            border.color: sirenTabBtn.isSelected ? "#FFA500" : "#555"
                            border.width: sirenTabBtn.isSelected ? 2 : 1
                            radius: 5
                        }

                        onClicked: {
                            if (configController && configController.config) {
                                var sirens = configController.config.sirenConfig.sirens
                                if (sirens && sirens[index])
                                    configController.setValueAtPath(["sirenConfig", "currentSirens"], [sirens[index].id])
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
            
            // Contenu des onglets (chemins explicites pour fonctionner depuis Main ou Test2D).
            // Ne charger que quand le panneau est visible pour que le 1er onglet s'affiche tout de suite.
            Loader {
                id: tabContentLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: root.visible ? mainLayout.tabSource : ""
                
                onLoaded: {
                    if (item) {
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
