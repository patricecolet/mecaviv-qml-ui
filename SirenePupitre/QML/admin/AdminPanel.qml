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

    // Exposer le TabBar pour NavigationManager
    property alias tabBar: tabBar

    // Exposer visibilitySection pour NavigationManager (quand l'onglet Visibilité est actif)
    readonly property var visibilitySection: (tabBar.currentIndex === 1 && tabContentLoader.item) ? tabContentLoader.item : null
    // Exposer advancedSection pour NavigationManager (quand l'onglet Avancé est actif)
    readonly property var advancedSection: (tabBar.currentIndex === 2 && tabContentLoader.item) ? tabContentLoader.item : null
    // Exposer outputSection pour NavigationManager (quand l'onglet Sorties est actif)
    readonly property var outputSection: (tabBar.currentIndex === 3 && tabContentLoader.item) ? tabContentLoader.item : null

    // Focus encodeur dans le panneau Admin (géré par NavigationManager)
    // Structure uniforme : 0 = TabBar, 1 = switch admin/restricted (toujours)
    // Onglet "Sirènes" : 2 = siren select, 3 = note max, 4 = transposition
    // Onglet "Visibilité" : 2 = menu latéral, 3+ = éléments dans la section
    property int adminFocusIndex: -1

    // Couleur de focus encodeur
    readonly property color focusColor: "#00BFFF"
    
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
                
                // Switch Mode Admin/Restricted — entouré d'un indicateur de focus (adminFocusIndex === 1)
                Rectangle {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: modeSwitchRow.implicitWidth + 16
                    color: "transparent"
                    border.color: root.adminFocusIndex === 1 ? root.focusColor : "transparent"
                    border.width: root.adminFocusIndex === 1 ? 2 : 0
                    radius: 5

                    RowLayout {
                        id: modeSwitchRow
                        anchors.centerIn: parent
                        spacing: 10
                        
                        Text {
                            text: "Mode:"
                            color: root.adminFocusIndex === 1 ? root.focusColor : "#bbb"
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
            
            // Onglets qui prennent toute la largeur — indicateur de focus (adminFocusIndex === 0)
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#0a0a0a"
                    border.color: root.adminFocusIndex === 0 ? root.focusColor : "transparent"
                    border.width: root.adminFocusIndex === 0 ? 2 : 0
                    radius: 5
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

            // Boutons sirènes — indicateur de focus (adminFocusIndex === 2)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                color: "transparent"
                border.color: root.adminFocusIndex === 2 ? root.focusColor : "transparent"
                border.width: root.adminFocusIndex === 2 ? 2 : 0
                radius: 5
                visible: tabBar.currentIndex === 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 8

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
                                                 Number(configController.primarySiren.id) === Number(modelData.id)

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
            }  // fin Rectangle focus siren select
            
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
                        // Passer le focus encodeur pour note max et transposition
                        if (item.hasOwnProperty("adminFocusIndex")) {
                            item.adminFocusIndex = Qt.binding(function() { return root.adminFocusIndex })
                        }
                        if (item.hasOwnProperty("focusColor")) {
                            item.focusColor = Qt.binding(function() { return root.focusColor })
                        }
                    }
                }
            }
        }
    }
}
