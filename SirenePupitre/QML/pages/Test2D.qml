import QtQuick
import QtQuick.Controls
import "../components"
import "../components/ambitus"
import "../utils"
import "../game"
import "../game/microtonal"

Page {
    id: root
    title: "Test Composants 2D"

    property color accentColor: '#d1ab00'
    property color backgroundColor: "#1a1a1a"
    property bool uiControlsEnabled: true
    /** Aligné sur Main : fin de séquence Pd (0x01 playing=false) met à jour rootWindow.isGamePlaying. */
    readonly property bool isGamePlaying: root.rootWindow ? root.rootWindow.isGamePlaying : false
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

    MicrotonalViewModel {
        id: microtonalVm
        onMidiAnchorChanged: root.syncMicrotonalCurrentCentsFromPitch()
    }

    /** Fin de séquence côté Pd : isGamePlaying passe à false sans clic Stop — couper aussi le transport UI. */
    Connections {
        target: root.rootWindow
        enabled: root.rootWindow !== null
        function onIsGamePlayingChanged() {
            if (!root.rootWindow || root.rootWindow.isGamePlaying)
                return
            if (!root.transportDisplayActive)
                return
            root.transportDisplayActive = false
            root.transportPlayRequestedAtMs = -1
            root.transportClockNowMs = 0
        }
    }

    Binding {
        target: microtonalVm
        property: "voletOpenLive"
        value: Math.max(0, Math.min(1, root.velocity / 127.0))
    }

    MicrotonalTypes {
        id: microtonalTypes
    }

    function syncMicrotonalSubMode() {
        if (!root.useMicrotonalDisplay)
            return
        if (!root.gameMode) {
            // Vue normale : garder le mode séquencé pour que ConductorCueDriver applique
            // le JSON + transport (tick/mesure). Le mode « dirigé » n’utilise que CONDUCTOR_CUE WS.
            microtonalVm.subMode = microtonalTypes.modeSequencedStrict
        } else if (microtonalVm.subMode === microtonalTypes.modeDirected
                || microtonalVm.subMode === 2) {
            microtonalVm.subMode = microtonalTypes.modeSequencedStrict
        }
    }

    function _getPrimarySirenIndex() {
        if (!root.configController || !root.configController.primarySiren)
            return -1
        var sirens = root.configController.config && root.configController.config.sirenConfig
                ? (root.configController.config.sirenConfig.sirens || []) : []
        for (var i = 0; i < sirens.length; i++) {
            if (Number(sirens[i].id) === Number(root.configController.primarySiren.id))
                return i
        }
        return -1
    }

    function ensureFrettedModeDisabledInMicrotonalGame() {
        if (!root.useMicrotonalDisplay || !root.gameMode || !root.configController)
            return
        var idx = root._getPrimarySirenIndex()
        if (idx < 0)
            return
        var enabledPath = ["sirenConfig", "sirens", idx, "frettedMode", "enabled"]
        var isEnabled = !!root.configController.getValueAtPath(enabledPath, false)
        if (isEnabled)
            root.configController.setValueAtPath(enabledPath, false)
    }

    function syncMicrotonalCurrentCentsFromPitch() {
        if (!root.useMicrotonalDisplay)
            return
        var note = Number(root.clampedNote)
        var anchor = Number(microtonalVm.midiAnchor)
        if (!isFinite(note) || !isFinite(anchor))
            return
        microtonalVm.currentCents = (note - anchor) * 100.0
    }

    /** Play/Stop transport : même logique que le bouton overlay mode jeu (WebSocket + état Main). */
    function toggleTransportPlayStop() {
        if (!root.webSocketController)
            return
        var playing = root.rootWindow && root.rootWindow.isGamePlaying
        var newPlaying = !playing
        if (newPlaying) {
            if (root.rootWindow) {
                root.rootWindow.userRequestedStop = false
                root.rootWindow.userRequestedPlay = true
                root.rootWindow.isGamePlaying = true
            }
            root.transportPlayRequestedAtMs = Date.now()
            root.transportClockNowMs = root.transportPlayRequestedAtMs
            if (gameModeOverlay && gameModeOverlay.sequencerController)
                gameModeOverlay.sequencerController.startFromZero()
            if (root._gameModeItem && typeof root._gameModeItem.startGame === "function")
                root._gameModeItem.startGame()
            root.transportDisplayActive = true
            root.webSocketController.sendBinaryMessage({
                type: "MIDI_TRANSPORT",
                action: "play",
                midiDelayMs: root.midiTransportDelayMs,
                source: "pupitre"
            })
        } else {
            root.transportDisplayActive = false
            root.transportPlayRequestedAtMs = -1
            root.transportClockNowMs = 0
            root.webSocketController.sendBinaryMessage({
                type: "MIDI_TRANSPORT",
                action: "stop",
                source: "pupitre"
            })
            if (root.rootWindow) {
                root.rootWindow.userRequestedPlay = false
                root.rootWindow.userRequestedStop = true
                root.rootWindow.isGamePlaying = false
            }
        }
    }

    // Note à afficher sur la portée (SirenController.clampedNote = ambitus continu, pas arrondi fretté)
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
    
    // Focus UI encodeur mode jeu : 0 Options, 1 Play/Stop, 2 Morceaux, 3 (microtonal) Options, 4 (microtonal) Morceaux, 5 microtonal, 6 Mode Normal
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
    /** true = vue microtonale (mode normal + mode jeu) */
    property bool useMicrotonalDisplay: false
    // Options du menu Options (persistantes car GameAutonomyPanel peut être détruit en vue normale)
    property bool playAccompaniment: false
    property bool autonomyVolant: false
    property bool autonomyVolet: false
    property bool autonomyVibrato: false
    property bool autonomyTremolo: false

    // Affichage mesure/temps : n’afficher les valeurs qu’une fois Pd lancé (après fallingTime), pas avant
    property bool transportDisplayActive: false
    /** Pré-roll entre Play et démarrage réel de la séquence Pd. */
    property int midiTransportDelayMs: 5000
    property real transportPlayRequestedAtMs: 0
    property real transportClockNowMs: 0
    readonly property bool transportInNegativeAnticipation: {
        if (!root.transportDisplayActive || !root.rootWindow || !root.rootWindow.isGamePlaying)
            return false
        if (root.transportPlayRequestedAtMs <= 0)
            return false
        return (root.transportClockNowMs - root.transportPlayRequestedAtMs) < root.midiTransportDelayMs
    }
    readonly property real transportAnticipationRemainingMs: root.transportInNegativeAnticipation
            ? Math.max(0, root.midiTransportDelayMs - (root.transportClockNowMs - root.transportPlayRequestedAtMs))
            : 0
    readonly property real transportAnticipationRemainingBeats: {
        var bpm = (sequencerController && isFinite(sequencerController.currentTempoBpm) && sequencerController.currentTempoBpm > 0)
                ? sequencerController.currentTempoBpm : 120
        return root.transportAnticipationRemainingMs * bpm / 60000.0
    }
    readonly property real transportPositiveElapsedMs: {
        if (!root.transportDisplayActive || !root.rootWindow || !root.rootWindow.isGamePlaying)
            return 0
        if (root.transportPlayRequestedAtMs <= 0)
            return 0
        return Math.max(0, (root.transportClockNowMs - root.transportPlayRequestedAtMs) - root.midiTransportDelayMs)
    }
    readonly property real transportPositiveGlobalBeat: {
        var bpm = (sequencerController && isFinite(sequencerController.currentTempoBpm) && sequencerController.currentTempoBpm > 0)
                ? sequencerController.currentTempoBpm : 120
        return 1 + (root.transportPositiveElapsedMs * bpm / 60000.0)
    }
    readonly property int transportPositiveBarInt: Math.max(1, Math.floor((root.transportPositiveGlobalBeat - 1) / root.transportBeatsPerBarDisplay) + 1)
    readonly property int transportPositiveBeatInBarInt: Math.max(1, (Math.floor(root.transportPositiveGlobalBeat - 1) % root.transportBeatsPerBarDisplay) + 1)
    readonly property int transportBeatsPerBarDisplay: 4
    readonly property int transportAnticipationRemainingBeatsInt: Math.max(0, Math.ceil(root.transportAnticipationRemainingBeats - 1e-6))
    readonly property int transportAnticipationRemainingBarsInt: Math.max(0, Math.ceil(root.transportAnticipationRemainingBeatsInt / root.transportBeatsPerBarDisplay))
    readonly property color transportValueColor: root.transportInNegativeAnticipation ? "#ff9f43" : "#fff"
    readonly property string transportMeasureDisplayText: {
        if (!root.transportDisplayActive || !sequencerController)
            return "— / —"
        if (root.transportInNegativeAnticipation)
            return "-" + root.transportAnticipationRemainingBarsInt + " / —"
        return root.transportPositiveBarInt + " / " + (sequencerController.totalBars > 0 ? sequencerController.totalBars : "—")
    }
    readonly property string transportTimeDisplayText: {
        if (!root.transportDisplayActive || !sequencerController)
            return "— / —"
        if (root.transportInNegativeAnticipation)
            return "-" + root.transportAnticipationRemainingBeatsInt + " / " + root.transportBeatsPerBarDisplay
        return root.transportPositiveBeatInBarInt + " / " + root.transportBeatsPerBarDisplay
    }

    Timer {
        id: transportAnticipationTimer
        interval: 50
        repeat: true
        running: root.transportDisplayActive && root.rootWindow && root.rootWindow.isGamePlaying
        onTriggered: root.transportClockNowMs = Date.now()
    }

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
            root.transportPlayRequestedAtMs = 0
            root.transportClockNowMs = 0
            root.gameModeFocusIndex = 0
        } else {
            root._wasPlayingWhenLeaving = root.rootWindow ? root.rootWindow.isGamePlaying : false
            root._gameModeItem = null
            root.transportDisplayActive = false
            root.transportPlayRequestedAtMs = 0
            root.transportClockNowMs = 0
        }
        root.syncMicrotonalSubMode()
        root.ensureFrettedModeDisabledInMicrotonalGame()
    }

    onUseMicrotonalDisplayChanged: {
        if (root.useMicrotonalDisplay) {
            root.syncMicrotonalSubMode()
            root.ensureFrettedModeDisabledInMicrotonalGame()
            root.syncMicrotonalCurrentCentsFromPitch()
        }
    }

    onSirenInfoChanged: root.ensureFrettedModeDisabledInMicrotonalGame()
    onClampedNoteChanged: root.syncMicrotonalCurrentCentsFromPitch()

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
        id: test2dBackground
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
            anchors.bottomMargin: root.useMicrotonalDisplay ? 8 : 20

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
                z: 0
                anchors.top: sirenSelector.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: sirenSelector.horizontalCenter
                value: root.velocity
                padConnected: configController ? configController.padConnected : false
                accentColor: root.accentColor
                configController: root.configController
                // En mode microtonal le volet sert d'indicateur : la jauge vélocité est superflue
                visible: !(root.useMicrotonalDisplay && !root.gameMode)
                         && !padConnected
                         && (configController ? configController.getConfigValue("displayConfig.components.velocityGauge.visible", true) : true)

                onVelocityChanged: function(v) {
                    if (sirenController) sirenController.velocity = v
                }
            }

            /** Marge haute de la zone microtonale : sous TopDisplays et sélecteur de sirène */
            readonly property real microtonalTopInset: {
                var tb = topDisplays.mapToItem(infoContainer, 0, topDisplays.height).y
                if (root.useMicrotonalDisplay && !root.gameMode) {
                    var sb = sirenSelector.mapToItem(infoContainer, 0, sirenSelector.height).y
                    return Math.max(tb, sb) + 16
                }
                var vb = velocityGauge.mapToItem(infoContainer, 0, velocityGauge.height).y
                return Math.max(tb, vb) + 16
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
                visible: (root.configController ? root.configController.isComponentVisible("musicalStaff") : true)
                        && !(root.useMicrotonalDisplay && !root.gameMode)
            }

            MicrotonalDisplay {
                id: microtonalDisplayNormal
                visible: root.useMicrotonalDisplay && !root.gameMode
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: parent.microtonalTopInset
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.useMicrotonalDisplay ? 128 : 100
                z: 2
                viewModel: microtonalVm
                layoutPreset: "normal"
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
                useMicrotonalDisplay: root.useMicrotonalDisplay
                isGamePlaying: root.isGamePlaying
                consoleConnected: configController ? configController.consoleConnected : false
                encoderFocusIndex: root.encoderUiFocusIndex
                gameOptionsDialog: gameOptionsDialog

                onToggleControllers: {
                    if (configController) {
                        var v = configController.getValueAtPath(["controllersPanel", "visible"], false)
                        var newValue = !v
                        configController.setValueAtPath(["controllersPanel", "visible"], newValue)
                        root.controllersPanelVisible = newValue  // Mise à jour immédiate via propriété locale
                        console.log("[Test2D] Contrôleurs:", newValue ? "affichés" : "masqués")
                    } else {
                        root.controllersPanelVisible = !root.controllersPanelVisible
                        console.log("[Test2D] Contrôleurs (sans config):", root.controllersPanelVisible ? "affichés" : "masqués")
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
                onTogglePlayStop: root.toggleTransportPlayStop()
                onAdminClicked: if (root.openAdminPanel) root.openAdminPanel()
            }
        }

        /**
         * Hors de infoContainer, ancré au Rectangle plein écran.
         * Hors microtonal : marge fixe 40 px du bas (comme avant).
         * En microtonal + jauge dockée : y dérivé de mapToItem(velocityGauge) — la formule
         * bottomMargin = 20+20+h+8 échoue si velocityGauge.height vaut 0 avant layout (Web)
         * ou si la marge dépasse la hauteur utile → item ramené en haut.
         */
        GearShiftPositionIndicator {
            id: gearShiftIndicator
            z: 150
            visible: !root.controllersPanelVisible
                    && (configController
                        ? configController.getConfigValue("displayConfig.components.musicalStaff.gearShiftIndicator.visible", true)
                        : true)
            anchors.left: test2dBackground.left
            anchors.leftMargin: 20
            anchors.bottom: test2dBackground.bottom
            anchors.bottomMargin: 20
            currentPosition: configController ? (configController.gearShiftPosition || 0) : 0
            configController: root.configController
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

            // Ambitus compact (portée ou clavier) en haut de la vue microtonal
            StaffZone2D {
                id: microtonalAmbitusStrip
                visible: root.useMicrotonalDisplay
                anchors.top: parent.top
                anchors.topMargin: 50
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                height: 72
                z: 5
                accentColor: root.accentColor
                currentNoteMidi: root.displayNoteForStaff
                currentVelocity: root.velocity
                sirenInfo: root.sirenInfo
                configController: root.configController
                lineSpacing: 10
                lineThickness: 1
                showProgressBar: false
                showCursor: true
                showMicrotonalTargetMarker: true
                microtonalTargetMidi: (microtonalVm.glissTargetMidi >= 0)
                    ? microtonalVm.glissTargetMidi
                    : microtonalVm.midiAnchor + microtonalVm.targetCents / 100.0
            }

            // Zone bas-droite : microtonal -> Options/Morceaux ; sinon toggles affichage
            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                z: 10
                spacing: 8
                Rectangle {
                    id: microtonalOptionsBtn
                    visible: root.useMicrotonalDisplay
                    width: Math.max(100, optionsQuickText.contentWidth + 20)
                    height: 38
                    radius: 8
                    property bool isFocused: root.gameModeFocusIndex === 3
                    color: "#2a2a2a"
                    border.color: isFocused ? root.gameModeFocusColor : "#6bb6ff"
                    border.width: isFocused ? 2 : 1

                    Text {
                        id: optionsQuickText
                        anchors.centerIn: parent
                        text: "Options"
                        color: microtonalOptionsBtn.isFocused ? root.gameModeFocusColor : "#fff"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (gameOptionsDialog)
                                gameOptionsDialog.open()
                        }
                    }
                }

                Rectangle {
                    id: microtonalSongsBtn
                    visible: root.useMicrotonalDisplay
                    width: Math.max(140, songsQuickText.contentWidth + 20)
                    height: 38
                    radius: 8
                    property bool isFocused: root.gameModeFocusIndex === 4
                    color: "#2a2a2a"
                    border.color: isFocused ? root.gameModeFocusColor : "#6bb6ff"
                    border.width: isFocused ? 2 : 1

                    Text {
                        id: songsQuickText
                        anchors.centerIn: parent
                        text: "Morceaux"
                        color: microtonalSongsBtn.isFocused ? root.gameModeFocusColor : "#fff"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (gameModeOverlay.gameAutonomyPanel
                                    && gameModeOverlay.gameAutonomyPanel.songSelectorDialog) {
                                gameModeOverlay.gameAutonomyPanel.loadMidiFilesList()
                                gameModeOverlay.gameAutonomyPanel.songSelectorDialog.open()
                            }
                        }
                    }
                }

                CheckBox {
                    id: anticipationCheckbox
                    visible: !root.useMicrotonalDisplay
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
                    visible: !root.useMicrotonalDisplay
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
                    onClicked: root.toggleTransportPlayStop()
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

            // Bloc Mesure/Temps/Tempo : entre Play (25%) et Mode Normal (75%), légèrement à gauche du centre
            Rectangle {
                id: positionInSongFrame
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -130
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
                                text: root.transportMeasureDisplayText
                                color: root.transportValueColor
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                        Row {
                            spacing: 8
                            Text { text: "Temps"; color: "#888"; font.pixelSize: 9; width: 44 }
                            Text {
                                text: root.transportTimeDisplayText
                                color: root.transportValueColor
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

            NumberDisplay2D {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: 130
                width: 180
                height: 72
                visible: root.useMicrotonalDisplay
                value: root.frequency
                label: "Hz"
                digitColor: root.accentColor
                inactiveColor: "#003333"
                frameColor: root.accentColor
                scaleX: 1.4 * root.uiScale
                scaleY: 0.65 * root.uiScale
                z: 10
            }

            Item {
                id: gameOverlayStaffZone
                z: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 110
                height: 145

                states: [
                    State {
                        name: "microtonalGame"
                        when: root.useMicrotonalDisplay
                        AnchorChanges {
                            target: gameOverlayStaffZone
                            anchors.top: parent.top
                            anchors.bottom: playStopButton.top
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges {
                            target: gameOverlayStaffZone
                            anchors.topMargin: 84
                            anchors.bottomMargin: 6
                            anchors.verticalCenterOffset: 0
                        }
                    }
                ]

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
                    visible: !root.useMicrotonalDisplay
                }

                Component {
                    id: microtonalGameModeComponent
                    MicrotonalGameMode {
                        viewModel: microtonalVm
                    }
                }

                Component {
                    id: normalGameModeComponent
                    GameMode { }
                }

                Loader {
                    id: gameModeLoader
                    anchors.fill: parent
                    z: 1
                    active: root.gameMode || (root.rootWindow && root.rootWindow.isGamePlaying) || (root.rootWindow && root.rootWindow.isGamePlaying)
                    sourceComponent: root.useMicrotonalDisplay ? microtonalGameModeComponent : normalGameModeComponent
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
                        item.gameOptionsDialog = gameOptionsDialog
                    }
                }
            }
            
            // Exposer GameAutonomyPanel pour NavigationManager
            readonly property var gameAutonomyPanel: gameAutonomyLoader.item
        }
    }

    GameOptionsDialog {
        id: gameOptionsDialog
        parent: root
        z: 10000
        configController: root.configController
        useMicrotonalDisplay: root.useMicrotonalDisplay
        playAccompaniment: root.playAccompaniment
        autonomyVolant: root.autonomyVolant
        autonomyVolet: root.autonomyVolet
        autonomyVibrato: root.autonomyVibrato
        autonomyTremolo: root.autonomyTremolo
        pupitreId: "P1"
        onMicrotonalDisplayChanged: function(enabled) {
            root.useMicrotonalDisplay = enabled
        }
        onAccompanimentChanged: function(enabled) {
            root.playAccompaniment = enabled
        }
        onAutonomyChanged: function(device, enabled) {
            if (device === "volant")
                root.autonomyVolant = enabled
            else if (device === "volet")
                root.autonomyVolet = enabled
            else if (device === "vibrato")
                root.autonomyVibrato = enabled
            else if (device === "tremolo")
                root.autonomyTremolo = enabled
        }
    }

    ConductorCueDriver {
        id: conductorCueDriver
        viewModel: microtonalVm
        webSocketController: root.webSocketController
        // id fichier (pas test2dBackground.gameModeOverlay : les ids enfants ne sont pas des propriétés du Rectangle)
        sequencerController: gameModeOverlay.sequencerController
        configController: root.configController
        useMicrotonalDisplay: root.useMicrotonalDisplay
        subMode: microtonalVm.subMode
        playRequestedAtMs: root.transportPlayRequestedAtMs
        transportDelayMs: root.midiTransportDelayMs
        transportRunActive: root.transportDisplayActive
    }
}
