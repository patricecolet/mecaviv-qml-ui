import QtQuick
import QtQuick.Controls
import "../components"
import "../components/ambitus"
import "../utils"
import "../game"

Page {
    id: root
    title: "Test Composants 2D"

    property color accentColor: '#d1ab00'
    property color backgroundColor: "#1a1a1a"
    property bool uiControlsEnabled: true
    property bool isGamePlaying: false
    property var rootWindow: null  // Main : pour lire gameMode2D (binding)
    property var setGameMode2D: null  // Callback Main pour écrire gameMode2D (plus fiable que rootWindow en écriture)
    property bool gameMode: rootWindow ? rootWindow.gameMode : false  // Mode jeu (seule vue)
    property var openAdminPanel: null  // fourni par Main pour ouvrir le panneau Admin global
    property var webSocketController: null

    readonly property var _defaultSirenInfo: ({
        name: "S1",
        ambitus: { min: 48, max: 84 },
        clef: "treble",
        mode: "restricted",
        restrictedMax: 72,
        displayOctaveOffset: 0
    })
    property var sirenController: null
    property var sirenInfo: (configController && configController.currentSirenInfo) ? configController.currentSirenInfo : _defaultSirenInfo
    property var configController: null
    property real midiNote: sirenController ? sirenController.midiNote : 69.0
    property real clampedNote: sirenController ? sirenController.clampedNote : 69.0
    property string noteName: sirenController ? sirenController.trueNoteName : "La4"

    MusicUtils { id: _musicUtils }

    // Note à afficher sur la portée (mode jeu : clampedNote ; Pd peut envoyer la note courante plus tard)
    property real displayNoteForStaff: root.clampedNote

    property real rpm: sirenController ? sirenController.trueRpm : 1200
    property int frequency: sirenController ? sirenController.trueFrequency : 440
    property int velocity: sirenController ? sirenController.velocity : 127
    property real bend: 0.0
    property real uiScale: (configController && configController.getValueAtPath(["ui", "scale"], 0.8)) || 0.8

    // Focus UI pour l’encodeur dans la vue principale : 0 = ADMIN, 1 = CONTRÔLEURS
    property int encoderUiFocusIndex: 0
    
    // Exposer controllersPanel pour NavigationManager
    property alias controllersPanel: controllersPanel
    
    // Focus UI pour l'encodeur en mode jeu : 0 = Play/Stop, 1 = Morceaux, 2 = Options, 3 = Ligne anticipation, 4 = Barres mesure, 5 = Mode Normal
    property int gameModeFocusIndex: 0
    property color gameModeFocusColor: "#00BFFF"
    readonly property int gameModeFocusCount: 6
    
    // Exposer GameAutonomyPanel (depuis l'overlay) pour NavigationManager
    readonly property var gameAutonomyPanel: gameModeOverlay ? gameModeOverlay.gameAutonomyPanel : null
    
    // Propriété locale pour contrôler la visibilité du panneau Contrôleurs (comme controllersPanelVisible dans Test2DButtons)
    property bool controllersPanelVisible: configController ? configController.getValueAtPath(["controllersPanel", "visible"], false) : false

    // Référence au GameMode (overlay) pour que Main puisse envoyer les événements MIDI séquence
    property var _gameModeItem: null
    property var gameModeItem: _gameModeItem
    property bool _wasPlayingWhenLeaving: false

    // Options mode jeu (liées à GameMode)
    property bool showAnticipationLine: false
    property bool showMeasureBars: false
    // Options du menu Options (persistantes car GameAutonomyPanel peut être détruit en vue normale)
    property bool playAccompaniment: false
    property bool autonomyVolant: false
    property bool autonomyVolet: false
    property bool autonomyVibrato: false
    property bool autonomyTremolo: false

    // Affichage mesure/temps : n’afficher les valeurs qu’une fois Pd lancé (après fallingTime), pas avant
    property bool transportDisplayActive: false

    onGameModeChanged: {
        if (root.gameMode) {
            // Entrée en mode jeu
            if (root._wasPlayingWhenLeaving) {
                // Retour pendant la lecture : ne pas reset, restaurer _gameModeItem
                root._gameModeItem = gameModeLoader.item
            } else {
                // Première entrée ou après stop : état propre
                if (root.rootWindow) {
                    root.rootWindow.userRequestedStop = false
                    root.rootWindow.isGamePlaying = false
                }
                if (sequencerController)
                    sequencerController.reset()
                root._gameModeItem = gameModeLoader.item
            }
            root._wasPlayingWhenLeaving = false
            root.transportDisplayActive = false
            root.gameModeFocusIndex = 0
        } else {
            root._wasPlayingWhenLeaving = root.rootWindow ? root.rootWindow.isGamePlaying : false
            root._gameModeItem = null
            root.transportDisplayActive = false
        }
    }

    function updateControllers(controllersData) {
        if (controllersPanel && controllersPanel.updateControllers) {
            controllersPanel.updateControllers(controllersData)
        }
        if (configController && controllersData && controllersData.gearShift !== undefined) {
            var pos = controllersData.gearShift.position || 0
            configController.gearShiftPosition = pos
        }
    }

    function setPadCalibrationDisplayValues(values) {
        if (controllersPanel && controllersPanel.setPadCalibrationValues)
            controllersPanel.setPadCalibrationValues(values)
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor

        TopDisplays2D {
            id: topDisplays
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            accentColor: root.accentColor
            rpm: root.rpm
            frequency: root.frequency
            noteName: root.noteName
            midiNote: root.midiNote
            velocity: root.velocity
            bend: root.bend
            configController: root.configController
        }

        Item {
            id: infoContainer
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20

            SirenSelector {
                id: sirenSelector
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                configController: root.configController
                accentColor: root.accentColor
                sirenInfo: root.sirenInfo
            }

            VelocityGauge2D {
                id: velocityGauge
                anchors.top: sirenSelector.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: sirenSelector.horizontalCenter
                value: root.velocity
                padConnected: configController ? configController.padConnected : false
                accentColor: root.accentColor
                configController: root.configController

                onVelocityChanged: function(v) {
                    if (sirenController) sirenController.velocity = v
                }
            }

            ScrollView {
                anchors.top: parent.top
                anchors.topMargin: 130
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                contentWidth: contentWrapper.width
                contentHeight: contentWrapper.height
                z: 0

                Item {
                    id: contentWrapper
                    width: scrollViewContent.width
                    height: scrollViewContent.height

                    Column {
                        id: scrollViewContent
                        width: 400
                        spacing: 20
                        padding: 12
                    }
                }
            }

            StaffZone2D {
                id: staffZone
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                z: 1
                accentColor: root.accentColor
                currentNoteMidi: root.clampedNote
                currentVelocity: root.velocity
                sirenInfo: root.sirenInfo
                configController: root.configController
                rpm: root.rpm
                frequency: root.frequency
                visible: root.configController ? root.configController.isComponentVisible("musicalStaff") : true
            }

            GearShiftPositionIndicator {
                anchors.fill: parent
                visible: true
                currentPosition: configController ? (configController.gearShiftPosition || 0) : 0
                configController: root.configController
            }

            ControllersPanel {
                id: controllersPanel
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(280, parent.height * 0.42)
                z: 200  // Au-dessus de la portée (z:1) et du gameModeOverlay (z:100)
                configController: root.configController
                webSocketController: root.webSocketController
                visible: root.controllersPanelVisible
            }

            Test2DButtons {
                controllersPanelVisible: root.controllersPanelVisible
                configController: root.configController
                uiControlsEnabled: root.uiControlsEnabled
                gameMode: root.gameMode
                isGamePlaying: root.isGamePlaying
                consoleConnected: configController ? configController.consoleConnected : false
                encoderFocusIndex: root.encoderUiFocusIndex

                onToggleControllers: {
                    if (configController) {
                        var v = configController.getValueAtPath(["controllersPanel", "visible"], false)
                        var newValue = !v
                        configController.setValueAtPath(["controllersPanel", "visible"], newValue)
                        root.controllersPanelVisible = newValue  // Mise à jour immédiate via propriété locale
                        console.log("🎮 [Test2D] Contrôleurs:", newValue ? "affichés" : "masqués")
                    } else {
                        root.controllersPanelVisible = !root.controllersPanelVisible
                        console.log("🎮 [Test2D] Contrôleurs (sans config):", root.controllersPanelVisible ? "affichés" : "masqués")
                    }
                }
                onToggleGameMode: {
                    var newVal = !root.gameMode
                    if (root.setGameMode2D) {
                        root.setGameMode2D(newVal)
                        if (root.webSocketController) {
                            root.webSocketController.sendBinaryMessage({
                                type: "GAME_MODE",
                                enabled: newVal,
                                source: "pupitre"
                            })
                        }
                    } else if (root.rootWindow) {
                        root.rootWindow.gameMode = newVal
                        if (root.webSocketController) {
                            root.webSocketController.sendBinaryMessage({
                                type: "GAME_MODE",
                                enabled: newVal,
                                source: "pupitre"
                            })
                        }
                    }
                }
                onTogglePlayStop: root.isGamePlaying = !root.isGamePlaying
                onAdminClicked: if (root.openAdminPanel) root.openAdminPanel()
            }
        }

        // Overlay mode jeu : séquenceur partagé + portée 2D + transport (visible quand gameMode)
        Item {
            id: gameModeOverlay
            z: 100
            anchors.fill: parent
            visible: root.gameMode
            
            // Exposer sequencerController pour NavigationManager
            readonly property var sequencerController: sequencerController

            Rectangle {
                anchors.fill: parent
                color: root.backgroundColor
            }

            // Séquenceur indépendant du jeu (mesure, temps, tempo, MIDI) — consommé par transport et jeux
            SequencerController {
                id: sequencerController
                configController: root.configController
                rootWindow: root.rootWindow
            }

            // Options affichage (ligne d'anticipation, barres de mesure) — bindings vers GameMode
            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                z: 10
                spacing: 8
                CheckBox {
                    id: anticipationCheckbox
                    text: "Ligne d'anticipation"
                    checked: root.showAnticipationLine
                    property bool isFocused: root.gameModeFocusIndex === 3
                    onCheckedChanged: root.showAnticipationLine = checked
                    palette.buttonText: isFocused ? root.gameModeFocusColor : "#fff"
                    contentItem: Text {
                        text: parent.text
                        color: parent.isFocused ? root.gameModeFocusColor : "#fff"
                        font.pixelSize: 14
                        font.bold: parent.isFocused
                        leftPadding: parent.indicator.width + parent.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: anticipationCheckbox.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 3
                        border.color: parent.parent.isFocused ? root.gameModeFocusColor : (anticipationCheckbox.checked ? "#FFD700" : "#666")
                        border.width: parent.parent.isFocused ? 2 : 1
                        color: "transparent"
                        Rectangle {
                            width: 12; height: 12; x: 4; y: 4; radius: 2
                            color: parent.parent.parent.isFocused ? root.gameModeFocusColor : "#FFD700"
                            visible: anticipationCheckbox.checked
                        }
                    }
                }
                CheckBox {
                    id: measureBarsCheckbox
                    text: "Barres de mesure"
                    checked: root.showMeasureBars
                    property bool isFocused: root.gameModeFocusIndex === 4
                    onCheckedChanged: root.showMeasureBars = checked
                    palette.buttonText: isFocused ? root.gameModeFocusColor : "#fff"
                    contentItem: Text {
                        text: parent.text
                        color: parent.isFocused ? root.gameModeFocusColor : "#fff"
                        font.pixelSize: 14
                        font.bold: parent.isFocused
                        leftPadding: parent.indicator.width + parent.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: measureBarsCheckbox.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 3
                        border.color: parent.parent.isFocused ? root.gameModeFocusColor : (measureBarsCheckbox.checked ? "#FFD700" : "#666")
                        border.width: parent.parent.isFocused ? 2 : 1
                        color: "transparent"
                        Rectangle {
                            width: 12; height: 12; x: 4; y: 4; radius: 2
                            color: parent.parent.parent.isFocused ? root.gameModeFocusColor : "#FFD700"
                            visible: measureBarsCheckbox.checked
                        }
                    }
                }
            }

            // Transport : mesure, temps, tempo (à gauche du Play) — encadré large pour mesure complète et durée totale
            Rectangle {
                id: positionInSongFrame
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                x: parent.width * 0.25 - 140 / 2 - 12 - width
                width: 220
                height: 88
                z: 10
                color: "#2a2a2a"
                border.color: "#6bb6ff"
                border.width: 2
                radius: 5

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "Mesure"; color: "#888"; font.pixelSize: 9; width: 44 }
                        Text {
                            text: root.transportDisplayActive && sequencerController
                                ? (sequencerController.positionDisplayText + " / " + (sequencerController.totalBars > 0 ? sequencerController.totalBars : "—"))
                                : "— / —"
                            color: "#fff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Temps"; color: "#888"; font.pixelSize: 9; width: 44 }
                        Text {
                            text: root.transportDisplayActive && sequencerController
                                ? (sequencerController.currentTimeDisplay + " / " + sequencerController.totalTimeDisplay)
                                : "— / —"
                            color: "#fff"
                            font.pixelSize: 12
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Tempo"; color: "#888"; font.pixelSize: 9; width: 44 }
                        Text {
                            text: root.transportDisplayActive && sequencerController
                                ? (Math.round(sequencerController.currentTempoBpm) + " BPM")
                                : "—"
                            color: "#fff"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Play/Stop (en bas à gauche, 1/4)
            Rectangle {
                id: playStopButton
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                x: parent.width * 0.25 - width / 2
                width: 140
                height: 60
                z: 10
                property bool isFocused: root.gameModeFocusIndex === 1
                color: (root.rootWindow && root.rootWindow.isGamePlaying) ? "#1a5a3a" : "#2a2a2a"
                border.color: isFocused ? root.gameModeFocusColor : ((root.rootWindow && root.rootWindow.isGamePlaying) ? "#4ade80" : "#6bb6ff")
                border.width: isFocused ? 3 : 2
                radius: 5

                SequentialAnimation on opacity {
                    running: root.rootWindow && root.rootWindow.isGamePlaying
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.7; duration: 800 }
                    NumberAnimation { from: 0.7; to: 1.0; duration: 800 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.webSocketController) {
                            var playing = root.rootWindow && root.rootWindow.isGamePlaying
                            var newPlaying = !playing
                            if (newPlaying) {
                                if (root.rootWindow) {
                                    root.rootWindow.userRequestedStop = false
                                    root.rootWindow.isGamePlaying = true
                                }
                                if (sequencerController)
                                    sequencerController.startFromZero()
                                if (root._gameModeItem && typeof root._gameModeItem.startGame === "function")
                                    root._gameModeItem.startGame()
                                root.transportDisplayActive = true
                                root.webSocketController.sendBinaryMessage({
                                    type: "MIDI_TRANSPORT",
                                    action: "play",
                                    midiDelayMs: 5000,
                                    source: "pupitre"
                                })
                            } else {
                                root.transportDisplayActive = false
                                root.webSocketController.sendBinaryMessage({
                                    type: "MIDI_TRANSPORT",
                                    action: "stop",
                                    source: "pupitre"
                                })
                                if (root.rootWindow) {
                                    root.rootWindow.userRequestedStop = true
                                    root.rootWindow.isGamePlaying = false
                                }
                            }
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: (root.rootWindow && root.rootWindow.isGamePlaying) ? "⏹ Stop" : "▶︎ Play"
                        color: playStopButton.isFocused ? root.gameModeFocusColor : ((root.rootWindow && root.rootWindow.isGamePlaying) ? "#4ade80" : "#fff")
                        font.pixelSize: 14
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "↓ Bouton physique"
                        color: (root.rootWindow && root.rootWindow.isGamePlaying) ? "#4ade80" : "#888"
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Mode Normal (en bas à droite, 3/4 — même position que Mode Jeu en vue normale)
            Rectangle {
                id: modeNormalButton
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                x: parent.width * 0.75 - width / 2
                width: 140
                height: 60
                z: 10
                property bool isFocused: root.gameModeFocusIndex === 5
                color: "#00CED1"
                border.color: isFocused ? root.gameModeFocusColor : "#00CED1"
                border.width: isFocused ? 3 : 2
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "Mode Normal"
                    color: parent.isFocused ? root.gameModeFocusColor : "#000"
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.setGameMode2D) {
                            root.setGameMode2D(false)
                            if (root.webSocketController) {
                                root.webSocketController.sendBinaryMessage({
                                    type: "GAME_MODE",
                                    enabled: false,
                                    source: "pupitre"
                                })
                            }
                        } else if (root.rootWindow) {
                            root.rootWindow.gameMode = false
                            if (root.webSocketController) {
                                root.webSocketController.sendBinaryMessage({
                                    type: "GAME_MODE",
                                    enabled: false,
                                    source: "pupitre"
                                })
                            }
                        }
                    }
                }
            }

            Item {
                id: gameOverlayStaffZone
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 110
                height: 145

                StaffZone2D {
                    anchors.fill: parent
                    accentColor: root.accentColor
                    currentNoteMidi: root.displayNoteForStaff
                    currentVelocity: root.velocity
                    sirenInfo: root.sirenInfo
                    configController: root.configController
                    rpm: root.rpm
                    frequency: root.frequency
                    lineSpacing: 16
                    lineThickness: 1.5
                }

                Loader {
                    id: gameModeLoader
                    anchors.fill: parent
                    z: 1
                    active: root.gameMode || (root.rootWindow && root.rootWindow.isGamePlaying) || (root.rootWindow && root.rootWindow.isGamePlaying)
                    source: "../game/GameMode.qml"
                    onLoaded: {
                        if (item) {
                            item.configController = root.configController
                            item.sirenInfo = root.sirenInfo
                            item.lineSpacing = 16
                            item.staffWidth = gameOverlayStaffZone.width
                            item.staffPosX = 0
                            item.currentNoteMidi = Qt.binding(function() { return root.clampedNote })
                            item.showAnticipationLine = Qt.binding(function() { return root.showAnticipationLine })
                            item.showMeasureBars = Qt.binding(function() { return root.showMeasureBars })
                            item.isPlaying = Qt.binding(function() { return !!(root.rootWindow && root.rootWindow.isGamePlaying) })
                            root._gameModeItem = item
                        }
                    }
                    onStatusChanged: {
                        if (status === Loader.Null || status === Loader.Error)
                            root._gameModeItem = null
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 70
                spacing: 80

                NumberDisplay2D {
                    width: 180
                    height: 72
                    value: root.rpm
                    label: "RPM"
                    digitColor: root.accentColor
                    inactiveColor: "#003333"
                    frameColor: root.accentColor
                    scaleX: 1.6 * root.uiScale
                    scaleY: 0.75 * root.uiScale
                }

                NumberDisplay2D {
                    width: 180
                    height: 72
                    value: root.frequency
                    label: "Hz"
                    digitColor: root.accentColor
                    inactiveColor: "#003333"
                    frameColor: root.accentColor
                    scaleX: 1.4 * root.uiScale
                    scaleY: 0.65 * root.uiScale
                }
            }

            Loader {
                id: gameAutonomyLoader
                anchors.fill: parent
                active: root.gameMode
                source: "../game/GameAutonomyPanel.qml"
                onLoaded: {
                    if (item) {
                        item.configController = root.configController
                        item.rootWindow = root.rootWindow
                        item.sequencer = sequencerController
                        item.gameMode = Qt.binding(function() { return root.gameModeItem })
                        // Passer le focus depuis Test2D
                        item.gameModeFocusIndex = Qt.binding(function() { return root.gameModeFocusIndex })
                        item.gameModeFocusColor = Qt.binding(function() { return root.gameModeFocusColor })
                        // Options du menu : Test2D est la source de vérité (persiste en vue normale)
                        item.playAccompaniment = Qt.binding(function() { return root.playAccompaniment })
                        item.autonomyVolant = Qt.binding(function() { return root.autonomyVolant })
                        item.autonomyVolet = Qt.binding(function() { return root.autonomyVolet })
                        item.autonomyVibrato = Qt.binding(function() { return root.autonomyVibrato })
                        item.autonomyTremolo = Qt.binding(function() { return root.autonomyTremolo })
                        item.test2DPage = root  // Pour mettre à jour Test2D depuis le panel
                    }
                }
            }
            
            // Exposer GameAutonomyPanel pour NavigationManager
            readonly property var gameAutonomyPanel: gameAutonomyLoader.item
        }
    }
}
