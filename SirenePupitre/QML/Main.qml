import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick3D
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
    
    // Police Emoji globale
    FontLoader {
        id: emojiFont
        source: "qrc:/fonts/NotoEmoji-VariableFont_wght.ttf"
    }
    
    // Rendre la police accessible globalement
    readonly property string globalEmojiFont: emojiFont.name
    
    // Propriété pour le mode studio
    property bool studioMode: false
    property bool debugMode: true  // Mettre à true pour activer les logs
    property bool isAdminMode: false  // État admin persistant
    property bool isGamePlaying: false  // État de lecture du mode jeu

    // ➜ NOUVELLE PROPRIÉTÉ GLOBALE POUR LES BOUTONS UI
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
        webSocketController: webSocketController  // AJOUTER CETTE LIGNE
        //debugMode: mainWindow.debugMode
        
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
        //debugMode: mainWindow.debugMode
    }
    
    WebSocketController {
        id: webSocketController
        serverUrl: (configController.config && configController.config.serverUrl) ? configController.config.serverUrl : "ws://127.0.0.1:10002"
        debugMode: mainWindow.debugMode
        configController: configController
        rootWindow: mainWindow
        
        onPlaybackPositionReceived: function(playing, bar, beatInBar, beat) {
            // Mettre à jour l'état de lecture du mode jeu
            mainWindow.isGamePlaying = playing
        }
        
        onGameModeReceived: function(enabled) {
            // Changer le mode jeu depuis le serveur (PureData)
            display.gameMode = enabled
        }
        
        onDataReceived: function(data) {
            // Logs désactivés pour performance
            
            // Format 0x04 : Note de séquence MIDI -> uniquement au mode jeu
            if (data.isSequence) {
                if (display.gameMode) {
                    display.sendMidiEventToGame(data)
                }
                return
            }
            
            // Format 0x02 : Contrôleurs physiques uniquement -> mettre à jour les indicateurs
            if (data.isControllersOnly) {
                if (data.controllers) {
                    display.updateControllers(data.controllers)
                }
                return
            }
            
            // Format 0x01 : Note volant uniquement -> curseur portée, PAS le mode jeu
            if (data.isVolantNote) {
                sirenController.midiNote = data.midiNote
                return  // Ne va PAS au mode jeu
            }
            
            // Format JSON legacy (rétrocompatibilité) : Note MIDI + contrôleurs mélangés
            if (data.midiNote !== undefined) {
                sirenController.midiNote = data.midiNote
            }
            if (data.controllers) {
                display.updateControllers(data.controllers)
            }
            
            // Si mode jeu actif, transmettre au mode jeu (pour JSON legacy ou autres formats)
            if (display.gameMode) {
                display.sendMidiEventToGame(data)
            }
        }
        
        onControlChangeReceived: function(ccNumber, ccValue) {
            // Transmettre les CC au mode jeu pour contrôler l'enveloppe et les modulations
            if (display.gameMode && display.gameModeComponent) {
                display.gameModeComponent.handleControlChange(ccNumber, ccValue);
            }
        }
        
        onConfigReceived: function(config) {
            // Configuration reçue
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
        rootWindow: mainWindow
        webSocketController: webSocketController
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
        
        
        onClose: {
            adminPanel.visible = false
        }
    }
    
    // Bouton pour basculer le panneau des contrôleurs (en haut à droite)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 100
        height: 35
        color: "#2a2a2a"
        border.color: configController && configController.getValueAtPath(["controllersPanel", "visible"], false) ? "#00ff00" : "#FFD700"
        radius: 5
        visible: {
            if (isAdminMode) return false
            if (display.gameMode) return false
            if (!configController) return mainWindow.uiControlsEnabled
            var dummy = configController.updateCounter
            return mainWindow.uiControlsEnabled
                   && configController.isComponentVisible("studioButton")
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (configController) {
                    var currentValue = configController.getValueAtPath(["controllersPanel", "visible"], false)
                    configController.setValueAtPath(["controllersPanel", "visible"], !currentValue)
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
    
    // Bouton pour basculer le mode fretté (au 1/4 de l'écran en bas)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.25 - width / 2
        width: 140
        height: 60
        color: {
            if (!configController) return "#2a2a2a"
            var dummy = configController.updateCounter // Force la réévaluation
            var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
            var currentSirenId = ids.length > 0 ? ids[0] : "1"
            var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                return siren.id === currentSirenId
            })?.frettedMode?.enabled || false
            return frettedModeEnabled ? "#FFD700" : "#2a2a2a"
        }
        border.color: {
            if (!configController) return "#FFD700"
            var dummy = configController.updateCounter // Force la réévaluation
            var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
            var currentSirenId = ids.length > 0 ? ids[0] : "1"
            var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                return siren.id === currentSirenId
            })?.frettedMode?.enabled || false
            return frettedModeEnabled ? "#FFA500" : "#FFD700"
        }
        border.width: 2
        radius: 5
        visible: {
            if (display.gameMode) return false
            if (!configController) return mainWindow.uiControlsEnabled
            if (configController.getValueAtPath(["controllersPanel", "visible"], false)) return false
            return mainWindow.uiControlsEnabled
                   && configController.isComponentVisible("studioButton")
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (configController) {
                    var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
                    var currentSirenId = ids.length > 0 ? ids[0] : "1"
                    var sirens = configController.getValueAtPath(["sirenConfig", "sirens"], [])
                    var currentSiren = sirens.find(function(siren) {
                        return siren.id === currentSirenId
                    })
                    
                    if (currentSiren) {
                        var currentValue = currentSiren.frettedMode?.enabled || false
                        
                        // Trouver l'index de la sirène dans le tableau
                        var sirenIndex = sirens.findIndex(function(siren) {
                            return siren.id === currentSirenId
                        })
                        
                        if (sirenIndex >= 0) {
                            var newValue = !currentValue
                            configController.setValueAtPath(["sirenConfig", "sirens", sirenIndex, "frettedMode", "enabled"], newValue)
                        }
                    }
                }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                text: {
                    if (!configController) return "Fretté OFF"
                    var dummy = configController.updateCounter // Force la réévaluation
                    var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
                    var currentSirenId = ids.length > 0 ? ids[0] : "1"
                    var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                        return siren.id === currentSirenId
                    })?.frettedMode?.enabled || false
                    return frettedModeEnabled ? "Fretté ON" : "Fretté OFF"
                }
                color: {
                    if (!configController) return "#FFD700"
                    var dummy = configController.updateCounter // Force la réévaluation
                    var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
                    var currentSirenId = ids.length > 0 ? ids[0] : "1"
                    var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                        return siren.id === currentSirenId
                    })?.frettedMode?.enabled || false
                    return frettedModeEnabled ? "#000" : "#FFD700"
                }
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "↓ Bouton physique"
                color: {
                    if (!configController) return "#888"
                    var dummy = configController.updateCounter // Force la réévaluation
                    var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], ["1"]) 
                    var currentSirenId = ids.length > 0 ? ids[0] : "1"
                    var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                        return siren.id === currentSirenId
                    })?.frettedMode?.enabled || false
                    return frettedModeEnabled ? "#000" : "#888"
                }
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Bouton Play/Stop pour le mode jeu (au 1/4 de l'écran en bas, visible uniquement en mode jeu)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.25 - width / 2
        width: 140
        height: 60
        color: isGamePlaying ? "#1a5a3a" : "#2a2a2a"  // Vert foncé quand en lecture
        border.color: isGamePlaying ? "#4ade80" : "#6bb6ff"  // Bordure verte quand en lecture
        border.width: 2
        radius: 5
        visible: display.gameMode && mainWindow.uiControlsEnabled
        
        // Animation de pulsation quand en lecture
        SequentialAnimation on opacity {
            running: isGamePlaying && display.gameMode
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.7; duration: 800 }
            NumberAnimation { from: 0.7; to: 1.0; duration: 800 }
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (webSocketController) {
                    var action = isGamePlaying ? "stop" : "play"
                    webSocketController.sendBinaryMessage({
                        type: "MIDI_TRANSPORT",
                        action: action,
                        source: "pupitre"
                    })
                }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                text: isGamePlaying ? "⏹ Stop" : "▶︎ Play"
                color: isGamePlaying ? "#4ade80" : "#fff"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "↓ Bouton physique"
                color: isGamePlaying ? "#4ade80" : "#888"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Bouton pour basculer en mode jeu (au 3/4 de l'écran en bas)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        x: parent.width * 0.75 - width / 2
        width: 140
        height: 60
        color: display.gameMode ? "#00CED1" : "#2a2a2a"
        border.color: "#00CED1"
        border.width: 2
        radius: 5
        visible: {
            if (!configController) return mainWindow.uiControlsEnabled
            var dummy = configController.updateCounter
            if (configController.getValueAtPath(["controllersPanel", "visible"], false)) return false
            return mainWindow.uiControlsEnabled
                   && configController.isComponentVisible("studioButton")
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                var newGameMode = !display.gameMode
                display.gameMode = newGameMode
                
                // Informer PureData du changement de mode
                if (webSocketController) {
                    webSocketController.sendBinaryMessage({
                        type: "GAME_MODE",
                        enabled: newGameMode,
                        source: "pupitre"
                    })
                }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                text: display.gameMode ? "Mode Normal" : "Mode Jeu"
                color: display.gameMode ? "#000" : "#00CED1"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "↓ Bouton physique"
                color: display.gameMode ? "#000" : "#888"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
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
        visible: !studioMode
                 && mainWindow.uiControlsEnabled
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
}
