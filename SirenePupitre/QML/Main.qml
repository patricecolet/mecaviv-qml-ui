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
    property bool userRequestedPlay: false  // Clic Play : ne pas laisser 0x01(playing=false) réécraser isGamePlaying
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

    // --- Contrôleurs ---

    // ConfigController : configuration, mode admin/restricted, état console
    ConfigController {
        id: configController
        webSocketController: webSocketController

        onSettingsUpdated: {
            // L'interface se met à jour automatiquement grâce aux bindings
        }

        onModeChanged: {
            if (configController.mode === "admin" && !isAdminMode) {
                isAdminMode = true
            } else if (configController.mode === "restricted" && isAdminMode) {
                isAdminMode = false
            }
        }
    }

    // SirenController : note MIDI courante (curseur portée, sirène)
    SirenController {
        id: sirenController
        configController: configController
    }

    // EncoderController : normalise la rotation/pression de l'encodeur (step/click/longPress)
    EncoderController {
        id: encoderController

        onStep: function(delta) {
            navigationManager.handleEncoderStep(delta)
        }

        onClicked: {
            navigationManager.handleEncoderClick()
        }

        onLongPressed: {
            navigationManager.handleEncoderLongPress()
        }
    }

    // NavigationManager : route les événements encodeur vers les différentes zones de l'UI
    NavigationManager {
        id: navigationManager
        configController: configController
        adminPanel: adminPanel
        testViewLoader: testViewLoader
    }

    // WebSocketController : connexion Pd, messages 0x01/0x02/0x04, game mode
    WebSocketController {
        id: webSocketController
        serverUrl: (configController.config && configController.config.serverUrl) ? configController.config.serverUrl : "ws://127.0.0.1:10002"
        debugMode: mainWindow.debugMode
        configController: configController
        rootWindow: mainWindow

        // --- Handlers WebSocket (ordre : playback → game mode → data binaire → config) ---

        // Playback : position / tick → met à jour isGamePlaying (sauf si user a cliqué Stop)
        onPlaybackPositionReceived: function(playing, bar, beatInBar, beat) {
            if (!playing) {
                if (mainWindow.userRequestedPlay)
                    return
                mainWindow.userRequestedStop = false
                mainWindow.isGamePlaying = false
            } else {
                mainWindow.userRequestedPlay = false
                if (!mainWindow.userRequestedStop)
                    mainWindow.isGamePlaying = true
            }
        }
        onPlaybackTickReceived: function(playing, tick) {
            if (!playing) {
                if (mainWindow.userRequestedPlay)
                    return
                mainWindow.userRequestedStop = false
                mainWindow.isGamePlaying = false
            } else {
                mainWindow.userRequestedPlay = false
                if (!mainWindow.userRequestedStop)
                    mainWindow.isGamePlaying = true
            }
        }

        // Game mode : activation/désactivation du mode jeu 2D
        onGameModeReceived: function(enabled) {
            mainWindow.gameMode = enabled
        }

        // Données binaires : 0x04 (séquence) → jeu, 0x02 (contrôleurs) → panneau, 0x01 (note) → portée
        // Navigation encodeur : messages binaires 0x06 (value) et 0x07 (push) uniquement (séparés du binaire 0x02)
        onDataReceived: function(data) {
            if (data.isSequence) {
                if (mainWindow.gameMode && testViewLoader.item && testViewLoader.item.gameModeItem) {
                    testViewLoader.item.gameModeItem.midiEventReceived(data)
                }
                return
            }
            if (data.isControllersOnly) {
                if (data.controllers) {
                    // Message binaire 0x02 : UNIQUEMENT pour l'affichage visuel des contrôleurs
                    // (panneau Contrôleurs, indicateurs, GearShift, etc.)
                    // Note: l'encodeur dans ce message est UNIQUEMENT pour l'affichage visuel
                    // La navigation utilise les messages binaires 0x06 (value) et 0x07 (push) séparés
                    if (testViewLoader.item && testViewLoader.item.updateControllers) {
                        testViewLoader.item.updateControllers(data.controllers)
                    }
                }
                return
            }
            if (data.isEncoderNavigation) {
                // Messages binaires 0x06 (value) et 0x07 (push) : navigation de l'encodeur UNIQUEMENT (pas d'affichage visuel)
                if (data.controllers && data.controllers.encoder && encoderController) {
                    encoderController.updateFromControllers(data.controllers)
                }
                return
            }
            if (data.isVolantNote) {
                sirenController.midiNote = data.midiNote
                if (data.velocity !== undefined) sirenController.velocity = Math.max(0, Math.min(127, data.velocity))
                return
            }
            if (data.midiNote !== undefined) {
                sirenController.midiNote = data.midiNote
            }
            if (data.controllers) {
                // Mettre à jour la vue Test2D (indicateurs visuels, GearShift, ControllersPanel, etc.)
                if (testViewLoader.item && testViewLoader.item.updateControllers) {
                    testViewLoader.item.updateControllers(data.controllers)
                }
                // Note: la navigation de l'encodeur utilise les messages binaires 0x06 (value) et 0x07 (push) séparés (isEncoderNavigation)
            }
        }

        // CC MIDI : transmis au mode jeu (gameModeItem)
        onControlChangeReceived: function(ccNumber, ccValue) {
            if (mainWindow.gameMode && testViewLoader.item && testViewLoader.item.gameModeItem) {
                testViewLoader.item.gameModeItem.handleControlChange(ccNumber, ccValue)
            }
        }

        // Valeurs int16 calibration pads (affichées sous les boutons), une seule structure [pad0, pad1]
        onPadCalibrationValuesReceived: function(values) {
            if (testViewLoader.item && testViewLoader.item.setPadCalibrationDisplayValues)
                testViewLoader.item.setPadCalibrationDisplayValues(values)
        }

        // Config envoyée par Pd (pour info)
        onConfigReceived: function(config) {
        }
    }

    // --- UI : panneaux et overlays (ordre par z-index : vue → boutons/bandeaux → overlays) ---

    // Vue principale 2D (z implicite 0)
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
                item.openAdminPanel = function() {
                    if (configController.getValueAtPath(["admin", "enabled"], true))
                        adminPanel.visible = true
                }
            }
        }
    }

    // Boutons et bandeaux de statut (z 0 ou 5000)
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

    // Overlays (z 9999 puis 10000)
    AdminPanel {
        id: adminPanel
        anchors.fill: parent
        visible: false
        enabled: visible
        z: 9999
        configController: configController
        webSocketController: webSocketController
        adminFocusIndex: navigationManager.adminFocusIndex

        onClose: {
            adminPanel.visible = false
        }
    }

    // Overlay d'attente de la configuration (z 10000)
    Rectangle {
        id: waitingConfigOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: configController && configController.waitingForConfig
        z: 10000
        
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
