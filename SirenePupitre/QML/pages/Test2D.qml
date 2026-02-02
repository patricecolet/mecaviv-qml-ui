import QtQuick
import QtQuick.Controls
import "../components"
import "../components/ambitus"
import "../utils"
import "../admin"
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
    property bool adminPanelVisible: false
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
    property real rpm: sirenController ? sirenController.trueRpm : 1200
    property int frequency: sirenController ? sirenController.trueFrequency : 440
    property int velocity: 100
    property real bend: 0.0
    property real uiScale: (configController && configController.getValueAtPath(["ui", "scale"], 0.8)) || 0.8

    // Référence au GameMode (overlay) pour que Main puisse envoyer les événements MIDI séquence
    property var _gameModeItem: null
    property var gameModeItem: _gameModeItem

    // Affichage mesure/temps : n’afficher les valeurs qu’une fois Pd lancé (après fallingTime), pas avant
    property bool transportDisplayActive: false

    onGameModeChanged: {
        if (root.gameMode) {
            // Entrée en mode jeu : état propre (bouton Play gris, séquenceur arrêté)
            if (root.rootWindow) {
                root.rootWindow.userRequestedStop = false
                root.rootWindow.isGamePlaying = false
            }
            if (sequencerController)
                sequencerController.reset()
            root.transportDisplayActive = false
        } else {
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
        }

        Item {
            id: infoContainer
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20

            SirenSelector {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                configController: root.configController
                accentColor: root.accentColor
                sirenInfo: root.sirenInfo
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
                sirenInfo: root.sirenInfo
                configController: root.configController
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
                height: parent.height * 0.35
                configController: root.configController
                webSocketController: null
                visible: configController ? configController.getValueAtPath(["controllersPanel", "visible"], false) : false
            }

            Test2DButtons {
                controllersPanelVisible: controllersPanel.visible
                configController: root.configController
                uiControlsEnabled: root.uiControlsEnabled
                gameMode: root.gameMode
                isGamePlaying: root.isGamePlaying
                consoleConnected: configController ? configController.consoleConnected : false

                onToggleControllers: {
                    if (configController) {
                        var v = configController.getValueAtPath(["controllersPanel", "visible"], false)
                        configController.setValueAtPath(["controllersPanel", "visible"], !v)
                    } else {
                        controllersPanel.visible = !controllersPanel.visible
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
                onAdminClicked: root.adminPanelVisible = true
            }
        }

        // Overlay mode jeu : séquenceur partagé + portée 2D + transport (visible quand gameMode)
        Item {
            id: gameModeOverlay
            z: 100
            anchors.fill: parent
            visible: root.gameMode

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

            // Les barres de mesure sont maintenant créées dynamiquement dans GameMode

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
                                ? (sequencerController.positionDisplayText + " / " + sequencerController.totalBars)
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
                                : "0:00 / 0:00"
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
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                x: parent.width * 0.25 - width / 2
                width: 140
                height: 60
                z: 10
                color: (root.rootWindow && root.rootWindow.isGamePlaying) ? "#1a5a3a" : "#2a2a2a"
                border.color: (root.rootWindow && root.rootWindow.isGamePlaying) ? "#4ade80" : "#6bb6ff"
                border.width: 2
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
                                var fallMs = (sequencerController && sequencerController.animationFallDurationMs > 0)
                                    ? sequencerController.animationFallDurationMs
                                    : (root._gameModeItem && root._gameModeItem.melodicLine ? root._gameModeItem.melodicLine.fixedFallTime : 5000)
                                playPdDelayTimer.interval = Math.max(0, Math.round(fallMs))
                                playPdDelayTimer.start()
                            } else {
                                playPdDelayTimer.stop()
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
                Timer {
                    id: playPdDelayTimer
                    interval: sequencerController ? sequencerController.animationFallDurationMs : 5000
                    repeat: false
                    onTriggered: {
                        root.transportDisplayActive = true
                        if (root.webSocketController)
                            root.webSocketController.sendBinaryMessage({
                                type: "MIDI_TRANSPORT",
                                action: "play",
                                source: "pupitre"
                            })
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: (root.rootWindow && root.rootWindow.isGamePlaying) ? "⏹ Stop" : "▶︎ Play"
                        color: (root.rootWindow && root.rootWindow.isGamePlaying) ? "#4ade80" : "#fff"
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
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                x: parent.width * 0.75 - width / 2
                width: 140
                height: 60
                z: 10
                color: "#00CED1"
                border.color: "#00CED1"
                border.width: 2
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "Mode Normal"
                    color: "#000"
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
                anchors.verticalCenterOffset: 50
                height: 95

                StaffZone2D {
                    anchors.fill: parent
                    accentColor: root.accentColor
                    currentNoteMidi: root.clampedNote
                    sirenInfo: root.sirenInfo
                    configController: root.configController
                    lineSpacing: 16
                    lineThickness: 1.5
                }

                Loader {
                    id: gameModeLoader
                    anchors.fill: parent
                    z: 1
                    active: root.gameMode
                    source: "../game/GameMode.qml"
                    onLoaded: {
                        if (item) {
                            item.configController = root.configController
                            item.sirenInfo = root.sirenInfo
                            item.sequencer = sequencerController
                            item.lineSpacing = 16
                            item.staffWidth = gameOverlayStaffZone.width
                            item.staffPosX = 0
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
                    }
                }
            }
        }
    }

    AdminPanel {
        anchors.fill: parent
        visible: root.adminPanelVisible
        enabled: root.adminPanelVisible
        z: 10000
        configController: root.configController
        webSocketController: root.webSocketController
        onClose: root.adminPanelVisible = false
    }
}
