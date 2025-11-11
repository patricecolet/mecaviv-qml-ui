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
                    text: "Messages reçus (total):"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: webSocketController && webSocketController.messageCount !== undefined ? webSocketController.messageCount.toString() : "0"
                    color: "#bbb"
                    font.pixelSize: 13
                }
                
                Text {
                    text: "Messages/seconde:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    id: messagesPerSecText
                    text: webSocketController && webSocketController.messagesPerSecond !== undefined ? webSocketController.messagesPerSecond.toString() + " msg/sec" : "0 msg/sec"
                    color: {
                        if (!webSocketController || webSocketController.messagesPerSecond === undefined) return "#bbb"
                        var rate = webSocketController.messagesPerSecond
                        if (rate > 100) return "#ff4444"  // Rouge si > 100 msg/sec (trop élevé)
                        if (rate > 50) return "#ffaa00"   // Orange si > 50 msg/sec (attention)
                        return "#00ff00"                  // Vert si ≤ 50 msg/sec (OK)
                    }
                    font.pixelSize: 13
                    font.bold: true
                }
                
                Text {
                    text: "Contrôleurs/seconde:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: webSocketController && webSocketController.controllersMessagesPerSecond !== undefined ? webSocketController.controllersMessagesPerSecond.toString() + " ctrl/sec" : "0 ctrl/sec"
                    color: {
                        if (!webSocketController || webSocketController.controllersMessagesPerSecond === undefined) return "#bbb"
                        var rate = webSocketController.controllersMessagesPerSecond
                        if (rate > 50) return "#ff4444"   // Rouge si > 50 ctrl/sec
                        if (rate > 30) return "#ffaa00"   // Orange si > 30 ctrl/sec
                        return "#00ff00"                  // Vert si ≤ 30 ctrl/sec
                    }
                    font.pixelSize: 13
                    font.bold: true
                }
                
                Text {
                    text: "Messages filtrés:"
                    color: "#888"
                    font.pixelSize: 13
                }
                Text {
                    text: webSocketController && webSocketController.droppedMessagesCount !== undefined ? webSocketController.droppedMessagesCount.toString() + " ignorés" : "0 ignorés"
                    color: "#88aaff"  // Bleu = c'est bon, ils sont filtrés volontairement
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
            }
        }
        
        // Indicateur visuel de performance
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Performance réseau"
            
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
                
                // Barre de progression visuelle
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    color: "#0a0a0a"
                    border.color: "#444"
                    radius: 3
                    
                    Rectangle {
                        height: parent.height
                        width: {
                            if (!webSocketController || webSocketController.messagesPerSecond === undefined) return 0
                            var rate = webSocketController.messagesPerSecond
                            return Math.min(parent.width, (rate / 200.0) * parent.width)  // Max 200 msg/sec
                        }
                        color: {
                            if (!webSocketController || webSocketController.messagesPerSecond === undefined) return "#444"
                            var rate = webSocketController.messagesPerSecond
                            if (rate > 100) return "#ff4444"  // Rouge
                            if (rate > 50) return "#ffaa00"   // Orange
                            return "#00ff00"                  // Vert
                        }
                        radius: 3
                        
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!webSocketController) return "N/A"
                            var rate = webSocketController.messagesPerSecond || 0
                            if (rate <= 20) return "✓ Excellent"
                            if (rate <= 50) return "✓ Bon"
                            if (rate <= 100) return "⚠ Élevé"
                            return "✗ Saturé"
                        }
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                        style: Text.Outline
                        styleColor: "#000000"
                    }
                }
                
                // Conseils
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!webSocketController) return ""
                        var rate = webSocketController.messagesPerSecond || 0
                        var ctrlRate = webSocketController.controllersMessagesPerSecond || 0
                        
                        if (rate > 100) {
                            return "⚠️ Saturation détectée ! Vérifiez le throttling PureData (≤50ms recommandé)"
                        }
                        if (rate > 50) {
                            return "⚠️ Trafic élevé. Les optimisations QML filtrent " + (webSocketController.droppedMessagesCount || 0) + " messages."
                        }
                        if (ctrlRate <= 20) {
                            return "✓ Performance optimale. Throttling actif : 50ms, " + (webSocketController.droppedMessagesCount || 0) + " messages filtrés."
                        }
                        return "✓ Trafic normal. Optimisations actives."
                    }
                    color: {
                        if (!webSocketController) return "#888"
                        var rate = webSocketController.messagesPerSecond || 0
                        if (rate > 100) return "#ff4444"
                        if (rate > 50) return "#ffaa00"
                        return "#88ff88"
                    }
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
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
            
            Button {
                text: "Réinitialiser stats"
                Layout.preferredWidth: 150
                enabled: webSocketController !== null
                
                onClicked: {
                    if (webSocketController) {
                        webSocketController.messageCount = 0
                        webSocketController.droppedMessagesCount = 0
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        // Configuration des optimisations
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Réglages d'optimisation"
            
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
                columns: 3
                columnSpacing: 15
                rowSpacing: 10
                
                // Throttling
                Text {
                    text: "Throttling:"
                    color: "#888"
                    font.pixelSize: 13
                    Layout.preferredWidth: 120
                }
                SpinBox {
                    id: throttleSpinBox
                    from: 10
                    to: 200
                    stepSize: 10
                    value: webSocketController ? webSocketController.controllersThrottleMs : 50
                    editable: true
                    Layout.preferredWidth: 120
                    
                    onValueModified: {
                        if (webSocketController) {
                            webSocketController.controllersThrottleMs = value
                        }
                    }
                }
                Text {
                    text: "ms (" + (1000 / (throttleSpinBox.value || 50)).toFixed(1) + " msg/sec max)"
                    color: "#888"
                    font.pixelSize: 11
                }
                
                // Seuil volant
                Text {
                    text: "Seuil volant:"
                    color: "#888"
                    font.pixelSize: 13
                }
                SpinBox {
                    from: 1
                    to: 10
                    value: webSocketController ? webSocketController.wheelThreshold : 2
                    Layout.preferredWidth: 120
                    
                    onValueModified: {
                        if (webSocketController) {
                            webSocketController.wheelThreshold = value
                        }
                    }
                }
                Text {
                    text: "±degrés"
                    color: "#888"
                    font.pixelSize: 11
                }
                
                // Seuil joystick
                Text {
                    text: "Seuil joystick:"
                    color: "#888"
                    font.pixelSize: 13
                }
                SpinBox {
                    from: 1
                    to: 20
                    value: webSocketController ? webSocketController.joystickThreshold : 5
                    Layout.preferredWidth: 120
                    
                    onValueModified: {
                        if (webSocketController) {
                            webSocketController.joystickThreshold = value
                        }
                    }
                }
                Text {
                    text: "±unités"
                    color: "#888"
                    font.pixelSize: 11
                }
                
                // Seuil fader
                Text {
                    text: "Seuil fader:"
                    color: "#888"
                    font.pixelSize: 13
                }
                SpinBox {
                    from: 1
                    to: 10
                    value: webSocketController ? webSocketController.faderThreshold : 3
                    Layout.preferredWidth: 120
                    
                    onValueModified: {
                        if (webSocketController) {
                            webSocketController.faderThreshold = value
                        }
                    }
                }
                Text {
                    text: "±valeurs"
                    color: "#888"
                    font.pixelSize: 11
                }
            }
        }
        
        // Presets de configuration
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 10
            
            Text {
                text: "Presets:"
                color: "#888"
                font.pixelSize: 13
            }
            
            Button {
                text: "Ultra sensible"
                Layout.preferredWidth: 120
                enabled: webSocketController !== null
                
                onClicked: {
                    if (webSocketController) {
                        webSocketController.controllersThrottleMs = 20  // 50 msg/sec
                        webSocketController.wheelThreshold = 1
                        webSocketController.joystickThreshold = 2
                        webSocketController.faderThreshold = 1
                    }
                }
            }
            
            Button {
                text: "Équilibré"
                Layout.preferredWidth: 120
                enabled: webSocketController !== null
                
                onClicked: {
                    if (webSocketController) {
                        webSocketController.controllersThrottleMs = 50  // 20 msg/sec
                        webSocketController.wheelThreshold = 2
                        webSocketController.joystickThreshold = 5
                        webSocketController.faderThreshold = 3
                    }
                }
            }
            
            Button {
                text: "Économie réseau"
                Layout.preferredWidth: 120
                enabled: webSocketController !== null
                
                onClicked: {
                    if (webSocketController) {
                        webSocketController.controllersThrottleMs = 100  // 10 msg/sec
                        webSocketController.wheelThreshold = 5
                        webSocketController.joystickThreshold = 10
                        webSocketController.faderThreshold = 5
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
            visible: false // Désactivé en production
        }
        
        Item { Layout.fillHeight: true }
    }
}