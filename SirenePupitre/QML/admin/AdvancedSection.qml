import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "advanced"

Item {
    id: root
    
    property var configController: null
    property var webSocketController: null
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Menu latéral
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "#1a1a1a"
            border.color: "#333"
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
                        color: menuButtonArea.containsMouse ? "#333" : 
                               stackLayout.currentIndex === index ? "#2a2a2a" : "transparent"
                        radius: 3
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            Text {
                                text: modelData.icon
                                color: "#FFD700"
                                font.pixelSize: 16
                            }
                            
                            Text {
                                text: modelData.text
                                color: stackLayout.currentIndex === index ? "#FFD700" : "#CCC"
                                font.pixelSize: 14
                                font.bold: stackLayout.currentIndex === index
                                Layout.fillWidth: true
                            }
                        }
                        
                        MouseArea {
                            id: menuButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stackLayout.currentIndex = index
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
                currentIndex: 0
                
                // Onglet WebSocket
                AdvancedWebSocket {
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                
                // Onglet Couleurs
                AdvancedColors {
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                
                // Onglet Tailles
                AdvancedSizes {
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
                
                // Onglet Animations
                AdvancedAnimations {
                    configController: root.configController
                    webSocketController: root.webSocketController
                }
            }
        }
    }
}