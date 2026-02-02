/**
 * Contrôleur de séquenceur indépendant du mode jeu.
 * Gère la position Pd, mesure, temps, tempo, chargement MIDI.
 * Plusieurs jeux peuvent consommer les mêmes données (affichages différents).
 */
import QtQuick
import "GameSequencer.js" as GameSequencer

Item {
    id: root
    width: 0
    height: 0

    property var configController: null
    property var rootWindow: null

    // État lecture (mis à jour par Pd)
    property bool isPlaying: false
    property real previousBeat: -1
    property real lastPositionMs: 0
    property real _lastUpdateTimestamp: 0  // Référence pour extrapolation (Date.now() au dernier resync)
    /** True dès qu'on a reçu au moins une position Pd depuis le dernier startFromZero(). Pendant la pré-mesure (avant premier message Pd), reste false pour ne pas extrapoler le temps. */
    property bool _receivedPositionSinceStart: false
    readonly property bool receivedPositionSinceStart: _receivedPositionSinceStart

    // Position courante (affichage transport)
    property real currentTimeMs: 0
    property int currentBar: 1
    property int currentBeatInBar: 1
    property real currentBeat: 1.0
    property real currentTempoBpm: 120
    property int totalBars: 1
    property real totalDurationMs: 0

    // Morceau chargé
    property string currentMidiPath: ""
    property string currentSongTitle: ""
    property var sequencerNotes: []
    property real sequencerBpm: 120
    property real sequencerPpq: 480
    property var sequencerTempoMap: []
    property var sequencerTimeSignatureMap: []
    property real lookaheadMs: 8000
    /** Durée de chute (ms) jusqu’au point de jeu — même valeur que l’animation (MelodicLine2D). Délai avant envoi de « play » à Pd. */
    property real animationFallDurationMs: 5000

    /** Timestamp (Date.now()) au clic Play, pour phase countdown. */
    property real playStartTimestamp: 0
    /** Temps d'affichage : pendant le countdown (avant 1er message Pd) = 0 ; après = currentTimeMs. Pilote segments et barres. */
    readonly property real displayTimeMs: (root.isPlaying && !root._receivedPositionSinceStart) ? 0 : root.currentTimeMs
    /** Mesure d'affichage : pendant le countdown = 1 ; après = currentBar. */
    readonly property int displayBar: (root.isPlaying && !root._receivedPositionSinceStart) ? 1 : root.currentBar

    readonly property string positionDisplayText: {
        var b = root.currentBar
        var t = root.currentBeat
        if (typeof b !== "number" || typeof t !== "number" || !isFinite(b) || !isFinite(t))
            return "—"
        var bar = Math.max(1, Math.min(9999, Math.floor(b)))
        var beat = Math.max(1, Math.min(17, t))
        return bar + " · " + beat.toFixed(1)
    }

    readonly property string currentTimeDisplay: {
        var ms = root.currentTimeMs
        if (typeof ms !== "number" || !isFinite(ms) || ms < 0) return "0:00"
        var sec = Math.floor(ms / 1000)
        var min = Math.floor(sec / 60)
        sec = sec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    readonly property string totalTimeDisplay: {
        var ms = root.totalDurationMs
        if (typeof ms !== "number" || !isFinite(ms) || ms < 0) return "0:00"
        var sec = Math.floor(ms / 1000)
        var min = Math.floor(sec / 60)
        sec = sec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function reset() {
        root.currentTimeMs = 0
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
        root.currentTempoBpm = 120
        root.totalDurationMs = 0
        root.isPlaying = false
        root.previousBeat = -1
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = 0
        root._receivedPositionSinceStart = false
        root.playStartTimestamp = 0
    }

    /** Démarre le séquenceur UI depuis 0 (à appeler avant d’envoyer play à Pd). */
    function startFromZero() {
        root.currentTimeMs = 0
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = Date.now()
        root._receivedPositionSinceStart = false
        root.playStartTimestamp = Date.now()
        root.isPlaying = true
    }

    function applyPositionFromPd(playing, timeMs) {
        root.lastPositionMs = timeMs
        if (!playing) return
        root._receivedPositionSinceStart = true
        root.currentTimeMs = timeMs
        var pos = GameSequencer.positionFromMs(timeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
        root.currentBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
        root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar)))
        root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
        root.currentTempoBpm = GameSequencer.getBpmAtMs(timeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
    }

    function getChannelForCurrentSiren() {
        if (!root.configController || !root.configController.primarySiren || !root.configController.config) return 0
        var sirens = root.configController.config.sirenConfig && root.configController.config.sirenConfig.sirens
        if (!sirens || sirens.length === 0) return 0
        for (var i = 0; i < sirens.length; i++) {
            if (sirens[i].id === root.configController.primarySiren.id) return i
        }
        return 0
    }

    function loadSong(path, title) {
        root.currentMidiPath = path || ""
        root.currentSongTitle = title || ""
        root.reloadNotesForCurrentChannel()
    }

    function reloadNotesForCurrentChannel() {
        if (!root.currentMidiPath || !root.configController) return
        var channelOrTrack = root.getChannelForCurrentSiren()
        GameSequencer.loadNotes(root.currentMidiPath, channelOrTrack, function(notes, bpm, ppq, tempoMap, timeSignatureMap) {
            root.sequencerNotes = notes || []
            root.sequencerPpq = ppq || 480
            root.sequencerTempoMap = tempoMap || []
            root.sequencerTimeSignatureMap = timeSignatureMap || []
            if (root.sequencerTempoMap.length > 0 && root.sequencerTempoMap[0].microsecondsPerQuarter > 0)
                root.sequencerBpm = Math.round(60000000 / root.sequencerTempoMap[0].microsecondsPerQuarter)
            else
                root.sequencerBpm = (typeof bpm === "number" && bpm > 0) ? bpm : 120
            root.totalDurationMs = GameSequencer.getTotalDurationMs(root.sequencerNotes, ppq, tempoMap)
            // Calcul du nombre de mesures via changements de signature (ticks entre changements -> mesures par signature)
            root.totalBars = GameSequencer.getTotalBarsFromSignatures(root.totalDurationMs, ppq, tempoMap, timeSignatureMap)
        })
    }

    property bool _tickConnected: false
    function connectPlaybackSignals() {
        if (root._tickConnected || !root.configController || !root.configController.webSocketController) return
        var ws = root.configController.webSocketController
        ws.playbackTickReceived.connect(function(playing, tick) {
            if (!playing) root.reset()
            if (playing) {
                var timeMs = GameSequencer.tickToMs(tick, root.sequencerPpq, root.sequencerTempoMap)
                root.applyPositionFromPd(playing, timeMs)
            }
            root.isPlaying = playing
            root.previousBeat = tick
        })
        ws.playbackPositionReceived.connect(function(playing, bar, beatInBar, beat) {
            if (!playing) root.reset()
            if (playing) {
                root._receivedPositionSinceStart = true
                // Pd envoie mesure 0 = première mesure → afficher mesure 1 (1-based)
                var bar1 = Math.max(1, bar)
                root.currentBar = bar1
                root.currentBeatInBar = Math.max(1, Math.min(16, beatInBar || 1))
                root.currentBeat = Math.max(1, Math.min(17, (typeof beat === "number" && isFinite(beat)) ? beat : 1))
                var timeMs = GameSequencer.positionToMsWithMaps(bar1, beatInBar, beat, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
                root.lastPositionMs = timeMs
                root.currentTimeMs = timeMs
                root._lastUpdateTimestamp = Date.now()  // resync pour extrapolation
                root.currentTempoBpm = GameSequencer.getBpmAtMs(timeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
                // Log pour diagnostic recul mesure : timeMs=0 ? maps vides au moment Pd ?
                var tempoLen = root.sequencerTempoMap ? root.sequencerTempoMap.length : 0
                var timeSigLen = root.sequencerTimeSignatureMap ? root.sequencerTimeSignatureMap.length : 0
                console.log("[Pd position] bar=" + bar1 + " timeMs=" + timeMs + " tempoMapLen=" + tempoLen + " timeSigLen=" + timeSigLen)
            }
            root.isPlaying = playing
            root.previousBeat = beat
        })
        root._tickConnected = true
    }

    // Extrapolation : avancer currentTimeMs entre deux messages Pd. Utilise la même logique que Pd (tempo map + time signature) pour éviter un décalage de currentBar (ex. barres « en double » avec numéro +2).
    Timer {
        interval: 50
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (!root.isPlaying) return
            if (!root._receivedPositionSinceStart) return
            var now = Date.now()
            root.currentTimeMs = root.lastPositionMs + (now - root._lastUpdateTimestamp)
            var pos = GameSequencer.positionFromMs(root.currentTimeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
            var newBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
            var oldBar = root.currentBar
            // Ne jamais reculer : les maps (tempo/time sig) peuvent donner barre 1 pour un temps déjà en barre 2+ (ex. première barre très longue)
            if (newBar >= oldBar) {
                root.currentBar = newBar
                root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar || 1)))
                root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
            }
            root.currentTempoBpm = GameSequencer.getBpmAtMs(root.currentTimeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
        }
    }

    onConfigControllerChanged: connectPlaybackSignals()
    Component.onCompleted: connectPlaybackSignals()
}
