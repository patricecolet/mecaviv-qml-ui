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
        
        // Section Debug Protocol 0x02
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Debug - Protocole 0x02"
            
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
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                Text {
                    text: "Le protocole binaire 0x02 permet de recevoir l'état des contrôleurs physiques\n" +
                          "(volant, pads, joystick, fader, pédale, etc.) en temps réel pour debug."
                    color: "#888"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                
                CheckBox {
                    id: enable0x02Checkbox
                    text: "Activer la réception du protocole 0x02"
                    checked: configController ? configController.enable0x02Protocol : false
                    
                    onCheckedChanged: {
                        if (configController && checked !== configController.enable0x02Protocol) {
                            configController.set0x02Protocol(checked)
                            console.log("Protocole 0x02:", checked ? "ACTIVÉ" : "DÉSACTIVÉ")
                        }
                    }
                    
                    Connections {
                        target: configController
                        function onEnable0x02ProtocolChanged() {
                            if (enable0x02Checkbox.checked !== configController.enable0x02Protocol) {
                                enable0x02Checkbox.checked = configController.enable0x02Protocol
                            }
                        }
                    }
                }
                
                Text {
                    text: "⚠️ Activer uniquement pour debug - Peut réduire les performances"
                    color: "#ff8800"
                    font.pixelSize: 11
                    font.italic: true
                    visible: enable0x02Checkbox.checked
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