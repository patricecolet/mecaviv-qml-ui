/**
 * Monitoring de la lecture Pd : position (0x01) au moment où les messages MIDI sont joués.
 * N'alimente que l'affichage transport (mesure, beat). Plus de chargement MIDI ni de calcul de position en ms.
 */
import QtQuick

Item {
    id: root
    width: 0
    height: 0

    property var configController: null
    property var rootWindow: null

    property bool isPlaying: false
    property int currentBar: 1
    property int currentBeatInBar: 1
    property real currentBeat: 1.0
    property real currentTempoBpm: 120

    /** Titre du morceau actuellement chargé (affiché dans GameAutonomyPanel). */
    property string currentSongTitle: ""
    /** Chemin relatif du morceau chargé. */
    property string currentMidiPath: ""

    readonly property string positionDisplayText: {
        var b = root.currentBar
        var t = root.currentBeat
        if (typeof b !== "number" || typeof t !== "number" || !isFinite(b) || !isFinite(t))
            return "—"
        var bar = b < 0 ? Math.max(-9999, Math.min(-1, Math.floor(b))) : Math.max(1, Math.min(9999, Math.floor(b)))
        var beat = Math.max(1, Math.min(17, t))
        return bar + " · " + beat.toFixed(1)
    }

    readonly property string currentTimeDisplay: "—"
    readonly property string totalTimeDisplay: "—"
    readonly property int totalBars: 0

    /** Mémorise le morceau choisi (titre + chemin). Le chargement effectif est fait par Pd. */
    function loadSong(path, title) {
        root.currentMidiPath = path || ""
        root.currentSongTitle = title || ""
    }

    function reset() {
        root.isPlaying = false
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
    }

    function startFromZero() {
        root.isPlaying = true
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
    }

    function requestStop() {
        if (root.configController && root.configController.webSocketController) {
            root.configController.webSocketController.sendBinaryMessage({
                type: "MIDI_TRANSPORT",
                action: "stop",
                source: "pupitre"
            })
        }
        if (root.rootWindow) {
            root.rootWindow.userRequestedStop = true
            root.rootWindow.isGamePlaying = false
        }
    }

    property bool _positionConnected: false
    function connectPlaybackSignals() {
        if (root._positionConnected || !root.configController || !root.configController.webSocketController) return
        var ws = root.configController.webSocketController
        ws.playbackPositionReceived.connect(function(playing, bar, beatInBar, beat) {
            if (!playing) root.reset()
            else {
                root.currentBar = Math.max(1, Math.min(9999, Math.floor(bar)))
                root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(beatInBar || 1)))
                root.currentBeat = Math.max(1, Math.min(17, (typeof beat === "number" && isFinite(beat)) ? beat : 1))
            }
            root.isPlaying = playing
        })
        root._positionConnected = true
    }

    onConfigControllerChanged: connectPlaybackSignals()
    Component.onCompleted: connectPlaybackSignals()
}
