import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    id: root
    
    property var configController: null
    property var webSocketController: null
    
    // Ajoutons un debug pour vérifier
    Component.onCompleted: {
    }
    
    onWebSocketControllerChanged: {
        if (webSocketController) {
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        // État de connexion
        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: "État:"
                color: "#888"
            }
            
            Label {
                id: statusLabel
                color: "#ff4444"
                font.bold: true
                
                Connections {
                    target: root.webSocketController
                    enabled: root.webSocketController !== null
                    
                    function onConnectedChanged() {
                        statusLabel.updateStatus()
                    }
                }
                
                Component.onCompleted: updateStatus()
                
                function updateStatus() {
                    if (!root.webSocketController) {
                        text = "Non configuré"
                        color = "#888888"
                    } else if (root.webSocketController.connected) {
                        text = "Connecté"
                        color = "#00ff00"
                    } else {
                        text = "Déconnecté"
                        color = "#ff4444"
                    }
                }
            }
        }
        
        Item { height: 20 }

        
        // État de connexion
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.preferredHeight: 80
            color: "#2a2a2a"
            border.color: webSocketController && webSocketController.connected ? "#00ff00" : "#ff3333"
            radius: 5
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: webSocketController && webSocketController.connected ? "✓ Connecté" : "✗ Déconnecté"
                    color: webSocketController && webSocketController.connected ? "#00ff00" : "#ff3333"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "URL: " + (webSocketController ? webSocketController.serverUrl : "Non configuré")
                    color: "#bbb"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Statistiques
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Statistiques"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: 20
                rowSpacing: 10
                
                Text {
                    text: "Messages reçus:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: webSocketController && webSocketController.messageCount !== undefined ? webSocketController.messageCount.toString() : "0"
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Dernier message:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: webSocketController && webSocketController.lastMessageTime ? webSocketController.lastMessageTime : "N/A"
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Latence moyenne:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: "N/A"
                    color: "#bbb"
                    font.pixelSize: 13
                }
            }
        }
        
        // Boutons de contrôle
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 10
            
            Button {
                text: webSocketController && webSocketController.connected ? "Déconnecter" : "Reconnecter"
                Layout.preferredWidth: 150
                enabled: webSocketController !== null
                
                onClicked: {
                    if (webSocketController) {
                        if (webSocketController.connected) {
                            webSocketController.disconnect()
                        } else {
                            webSocketController.reconnect()
                        }
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        // Debug
        Text {
            Layout.leftMargin: 20
            text: "Debug: webSocketController = " + (webSocketController ? "défini" : "null") + 
                  ", connected = " + (webSocketController ? webSocketController.connected : "N/A")
            color: "#666"
            font.pixelSize: 11
            visible: true // Mettre à false en production
        }
        
        Item { Layout.fillHeight: true }
    }
}