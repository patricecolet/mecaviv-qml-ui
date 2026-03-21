import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "advanced"

Item {
    id: root
    
    property var configController: null
    property var webSocketController: null
    // Focus encodeur dans le panneau Admin (reçu depuis AdminPanel)
    property int adminFocusIndex: -1
    property color focusColor: "#00BFFF"

    // Index de la section sélectionnée dans le menu latéral (0, 1, 2, 3)
    property int selectedMenuIndex: 0

    // Index relatif pour les sous-composants (adminFocusIndex - 2, car 0=TabBar, 1=modeSwitch, 2=menu, 3+=contenu)
    readonly property int contentFocusIndex: (root.adminFocusIndex >= 3) ? (root.adminFocusIndex - 2) : -1

    // Exposer pour NavigationManager
    property alias stackLayout: stackLayout
    
    // Mettre à jour le focus quand adminFocusIndex change
    onAdminFocusIndexChanged: {
        if (stackLayout.itemAt(stackLayout.currentIndex)) {
            stackLayout._updateFocusOnCurrentTab()
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Menu latéral — entouré en bleu quand l'encodeur est sur le focus 2
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "#1a1a1a"
            border.color: root.adminFocusIndex === 2 ? root.focusColor : "#333"
            border.width: root.adminFocusIndex === 2 ? 2 : 0
            radius: 5
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                // Boutons du menu
                Repeater {
                    model: [
                        { text: "WebSocket", icon: "🌐" },
                        { text: "Couleurs", icon: "🎨" },
                        { text: "Tailles", icon: "📏" },
                        { text: "Animations", icon: "✨" }
                    ]
                    
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        property bool isSelected: root.selectedMenuIndex === index
                        color: menuButtonArea.containsMouse ? "#333" : 
                               (isSelected ? "#2a2a2a" : "transparent")
                        border.color: isSelected ? "#FFD700" : "transparent"
                        border.width: isSelected ? 2 : 0
                        radius: 3
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            Text {
                                text: modelData.icon
                                font.family: mainWindow.globalEmojiFont
                                color: parent.parent.isSelected ? "#FFD700" : root.focusColor
                                font.pixelSize: 16
                            }
                            
                            Text {
                                text: modelData.text
                                color: parent.parent.isSelected ? "#FFD700" : "#CCC"
                                font.pixelSize: 14
                                font.bold: parent.parent.isSelected
                                Layout.fillWidth: true
                            }
                        }
                        
                        MouseArea {
                            id: menuButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedMenuIndex = index
                                stackLayout.currentIndex = index
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }
        
        // Séparateur vertical
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: "#333"
        }
        
        // Zone de contenu
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0a"
            border.color: "#333"
            radius: 5
            
            StackLayout {
                id: stackLayout
                anchors.fill: parent
                anchors.margins: 10
                currentIndex: root.selectedMenuIndex
                
                onCurrentIndexChanged: {
                    root.selectedMenuIndex = currentIndex
                    // Mettre à jour le focus sur le nouvel onglet actif
                    _updateFocusOnCurrentTab()
                }
                
                function _updateFocusOnCurrentTab() {
                    var currentTab = itemAt(currentIndex)
                    if (currentTab) {
                        if (currentTab.hasOwnProperty("adminFocusIndex"))
                            currentTab.adminFocusIndex = Qt.binding(function() { return root.contentFocusIndex })
                        if (currentTab.hasOwnProperty("focusColor"))
                            currentTab.focusColor = Qt.binding(function() { return root.focusColor })
                    }
                }
                
                // Onglet WebSocket
                AdvancedWebSocket {
                    id: websocketTab
                    configController: root.configController
                    webSocketController: root.webSocketController
                    Component.onCompleted: stackLayout._updateFocusOnCurrentTab()
                }
                
                // Onglet Couleurs
                AdvancedColors {
                    id: colorsTab
                    configController: root.configController
                    webSocketController: root.webSocketController
                    Component.onCompleted: stackLayout._updateFocusOnCurrentTab()
                }
                
                // Onglet Tailles
                AdvancedSizes {
                    id: sizesTab
                    configController: root.configController
                    webSocketController: root.webSocketController
                    Component.onCompleted: stackLayout._updateFocusOnCurrentTab()
                }
                
                // Onglet Animations
                AdvancedAnimations {
                    id: animationsTab
                    configController: root.configController
                    webSocketController: root.webSocketController
                    Component.onCompleted: stackLayout._updateFocusOnCurrentTab()
                }
            }
        }
    }
}