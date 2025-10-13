import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick3D
import "components"
import "controllers"
import "admin"

Window {
    id: mainWindow
    width: 1280
    height: 800
    visible: true
    title: qsTr("Sirène Pupitre")
    color: "#6f6a6a"
    
    // Police Emoji globale
    FontLoader {
        id: emojiFont
        source: "qrc:/fonts/NotoEmoji-VariableFont_wght.ttf"
        onStatusChanged: {
            if (status === FontLoader.Ready) {
                console.log("✅ [Global] Police Emoji chargée:", name)
            }
        }
    }
    
    // Rendre la police accessible globalement
    readonly property string globalEmojiFont: emojiFont.name
    
    // Propriété pour le mode studio
    property bool studioMode: false
    property bool debugMode: true  // Mettre à true pour activer les logs
    property bool isAdminMode: false  // État admin persistant
    
    // Synchroniser isAdminMode avec le mode global
    onIsAdminModeChanged: {
        if (configController) {
            var newMode = isAdminMode ? "admin" : "restricted"
            if (configController.mode !== newMode) {
                configController.setMode(newMode)
            }
        }
    }
    
    // Contrôleurs
    ConfigController {
        id: configController
        webSocketController: webSocketController  // AJOUTER CETTE LIGNE
        //debugMode: mainWindow.debugMode
        
        // Utiliser le signal existant pour tout
        onSettingsUpdated: {
            console.log("Configuration mise à jour")
            // L'interface se met à jour automatiquement grâce aux bindings
        }
        
        // Synchroniser le mode global avec isAdminMode
        onModeChanged: {
            if (configController.mode === "admin" && !isAdminMode) {
                isAdminMode = true
            } else if (configController.mode === "restricted" && isAdminMode) {
                isAdminMode = false
            }
        }
    }
    
    SirenController {
        id: sirenController
        configController: configController
        //debugMode: mainWindow.debugMode
    }
    
    WebSocketController {
        id: webSocketController
        serverUrl: (configController.config && configController.config.serverUrl) ? configController.config.serverUrl : "ws://127.0.0.1:10002"
        debugMode: mainWindow.debugMode
        configController: configController
        
        onDataReceived: function(data) {
            // Logs désactivés pour performance
            
            if (data.midiNote !== undefined) {
                sirenController.midiNote = data.midiNote
            }
            if (data.controllers) {
                display.updateControllers(data.controllers)
            }
        }
        
        onConfigReceived: function(config) {
            console.log("Configuration reçue via WebSocket:", JSON.stringify(config))
        }
    }
    
    
    // Affichage principal - Mode normal
    SirenDisplay {
        id: display
        anchors.fill: parent
        visible: !studioMode && !adminPanel.visible
        sirenController: sirenController
        sirenInfo: configController.currentSirenInfo
        configController: configController
    }
    
    // Mode Studio pour debug/présentation
    StudioView {
        id: studioView
        anchors.fill: parent
        visible: studioMode && !isAdminMode
        //debugMode: mainWindow.debugMode  // Passer le flag
    }
    
    // Authentification supprimée - accès direct à l'admin
    
    // Panneau d'administration
    AdminPanel {
        id: adminPanel
        anchors.fill: parent
        visible: false
        enabled: visible
        z: 9999
        configController: configController  // Vérifiez que c'est bien là
        webSocketController: webSocketController  // Vérifiez que c'est bien là
        
        Component.onCompleted: {
            console.log("AdminPanel Component.onCompleted - configController:", configController)
            console.log("AdminPanel Component.onCompleted - webSocketController:", webSocketController)
        }
        
        onClose: {
            adminPanel.visible = false
        }
    }
    
    // Bouton pour basculer entre les modes
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 120
        height: 40
        color: "#2a2a2a"
        border.color: studioMode ? "#00ff00" : "#FFD700"
        radius: 5
        visible: {
            if (isAdminMode) return false
            if (!configController) return true
            var dummy = configController.updateCounter
            return configController.isComponentVisible("studioButton")
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: studioMode = !studioMode
        }
        
        Text {
            text: studioMode ? "Mode Normal" : "Mode Studio"
            color: "white"
            font.pixelSize: 14
            anchors.centerIn: parent
        }
    }
    
    // Bouton pour basculer le panneau des contrôleurs (en bas à droite, au-dessus de l'espace libre)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 20
        anchors.rightMargin: 20
        width: 100
        height: 35
        color: "#2a2a2a"
        border.color: configController && configController.getValueAtPath(["controllersPanel", "visible"], false) ? "#00ff00" : "#FFD700"
        radius: 5
        visible: {
            if (isAdminMode) return false
            if (!configController) return true
            var dummy = configController.updateCounter
            return configController.isComponentVisible("studioButton")
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (configController) {
                    var currentValue = configController.getValueAtPath(["controllersPanel", "visible"], false)
                    configController.setValueAtPath(["controllersPanel", "visible"], !currentValue)
                    console.log("Panneau contrôleurs basculé:", !currentValue)
                }
            }
        }
        
        Text {
            text: configController && configController.getValueAtPath(["controllersPanel", "visible"], false) ? "Masquer" : "Contrôleurs"
            color: "white"
            font.pixelSize: 12
            anchors.centerIn: parent
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
        visible: !studioMode && configController.getValueAtPath(["admin", "enabled"], true)
        
        MouseArea {
            id: mouseAreaAdmin
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                console.log("Bouton admin cliqué")
                console.log("Ouverture du panneau admin")
                if (configController.getValueAtPath(["admin", "enabled"], true)) {
                    adminPanel.visible = true
                } else {
                    console.log("Accès admin désactivé par configuration")
                }
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
        visible: configController && configController.consoleConnected // Only visible when console is connected
        
        Text {
            text: "🎛️ CONSOLE CONNECTÉE"
            color: "#000"
            font.pixelSize: 14
            font.bold: true
            anchors.centerIn: parent
        }
    }
}
