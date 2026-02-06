import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import "components"
import "controllers"
import "admin"

Window {
    id: mainWindow
    objectName: "mainWindow"
    width: 1280
    height: 800
    visible: true
    title: qsTr("Sirène Pupitre")
    color: "#6f6a6a"

    // --- Ressources globales ---
    FontLoader {
        id: emojiFont
        source: "qrc:/fonts/NotoEmoji-VariableFont_wght.ttf"
    }
    readonly property string globalEmojiFont: emojiFont.name

    // --- Debug ---
    property bool debugMode: true  // Mettre à true pour activer les logs

    // --- État application ---
    property bool isAdminMode: false
    property bool isGamePlaying: false
    property bool userRequestedStop: false  // Clic Stop : ne pas laisser 0x01(playing=true) réécraser isGamePlaying
    property bool gameMode: false

    // --- UI ---
    property bool uiControlsEnabled: true

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
        webSocketController: webSocketController
        
        // Utiliser le signal existant pour tout
        onSettingsUpdated: {
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
    }
    
    WebSocketController {
        id: webSocketController
        serverUrl: (configController.config && configController.config.serverUrl) ? configController.config.serverUrl : "ws://127.0.0.1:10002"
        debugMode: mainWindow.debugMode
        configController: configController
        rootWindow: mainWindow
        
        onPlaybackPositionReceived: function(playing, bar, beatInBar, beat) {
            if (!playing) {
                mainWindow.userRequestedStop = false
                mainWindow.isGamePlaying = false
            } else if (!mainWindow.userRequestedStop) {
                mainWindow.isGamePlaying = true
            }
        }
        onPlaybackTickReceived: function(playing, tick) {
            if (!playing) {
                mainWindow.userRequestedStop = false
                mainWindow.isGamePlaying = false
            } else if (!mainWindow.userRequestedStop) {
                mainWindow.isGamePlaying = true
            }
        }
        
        onGameModeReceived: function(enabled) {
            mainWindow.gameMode = enabled
        }
        
        onDataReceived: function(data) {
            // Format 0x04 : Note de séquence MIDI -> mode jeu (vue 2D)
            if (data.isSequence) {
                if (mainWindow.gameMode && testViewLoader.item && testViewLoader.item.gameModeItem) {
                    testViewLoader.item.gameModeItem.midiEventReceived(data)
                }
                return
            }
            
            // Format 0x02 : Contrôleurs physiques uniquement
            if (data.isControllersOnly) {
                if (data.controllers && testViewLoader.item && testViewLoader.item.updateControllers) {
                    testViewLoader.item.updateControllers(data.controllers)
                }
                return
            }
            
            // Format 0x01 : Note volant uniquement -> curseur portée
            if (data.isVolantNote) {
                sirenController.midiNote = data.midiNote
                return
            }
            
            // Format JSON legacy
            if (data.midiNote !== undefined) {
                sirenController.midiNote = data.midiNote
            }
            if (data.controllers && testViewLoader.item && testViewLoader.item.updateControllers) {
                testViewLoader.item.updateControllers(data.controllers)
            }
        }
        
        onControlChangeReceived: function(ccNumber, ccValue) {
            if (mainWindow.gameMode && testViewLoader.item && testViewLoader.item.gameModeItem) {
                testViewLoader.item.gameModeItem.handleControlChange(ccNumber, ccValue)
            }
        }
        
        onConfigReceived: function(config) {
            // Configuration reçue
        }
    }
    
    // Panneau d'administration
    AdminPanel {
        id: adminPanel
        anchors.fill: parent
        visible: false
        enabled: visible
        z: 9999
        configController: configController
        webSocketController: webSocketController
        
        
        onClose: {
            adminPanel.visible = false
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
        visible: mainWindow.uiControlsEnabled
                 && configController.getValueAtPath(["admin", "enabled"], true)
        
        MouseArea {
            id: mouseAreaAdmin
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                if (configController.getValueAtPath(["admin", "enabled"], true)) {
                    adminPanel.visible = true
                } else {
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
    
    // Bandeau "Console connectée" (en haut à droite) quand Pd/console est connecté
    Rectangle {
        z: 5000
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
        visible: configController && configController.consoleConnected
        
        Text {
            text: "🎛️ CONSOLE CONNECTÉE"
            color: "#000"
            font.pixelSize: 14
            font.bold: true
            anchors.centerIn: parent
        }
    }
    
    // Bandeau "Pure Data non connecté" : visible seulement si pas connecté (ni WebSocket ouvert, ni console)
    Rectangle {
        z: 5000
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 220
        height: 35
        color: "#4a4a4a"
        border.color: "#888"
        border.width: 2
        radius: 8
        visible: configController && !configController.consoleConnected && !configController.waitingForConfig && !(webSocketController && webSocketController.connected)
        
        Text {
            text: "⚠️ Pure Data non connecté"
            color: "#ddd"
            font.pixelSize: 13
            font.bold: true
            anchors.centerIn: parent
        }
    }
    
    // Overlay d'attente de la configuration
    Rectangle {
        id: waitingConfigOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)  // Fond semi-transparent
        visible: configController && configController.waitingForConfig
        z: 10000  // Au-dessus de tout
        
        MouseArea {
            anchors.fill: parent
            // Empêcher les clics de passer à travers
            onClicked: function(mouse) {
                mouse.accepted = true
            }
        }
        
        // Contenu centré
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            // Indicateur de chargement (spinner)
            Item {
                width: 60
                height: 60
                anchors.horizontalCenter: parent.horizontalCenter
                
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: waitingConfigOverlay.visible
                }
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 60
                    height: 60
                    radius: 30
                    color: "transparent"
                    border.color: "#00ff00"
                    border.width: 4
                    
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 8
                        height: 20
                        color: "#00ff00"
                        radius: 4
                    }
                }
            }
            
            // Message
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⏳ Attente de la configuration..."
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Connexion à PureData en cours"
                color: "#CCCCCC"
                font.pixelSize: 14
            }
        }
    }
    
    // Vue principale 2D (seule vue du projet)
    Loader {
        id: testViewLoader
        anchors.fill: parent
        visible: !adminPanel.visible
        source: "qrc:/QML/pages/Test2D.qml"
        onItemChanged: {
            if (item) {
                item.configController = configController
                item.webSocketController = webSocketController
                item.sirenController = sirenController
                item.rootWindow = mainWindow
                item.setGameMode2D = function(value) {
                    mainWindow.gameMode = value
                }
            }
        }
    }
}
