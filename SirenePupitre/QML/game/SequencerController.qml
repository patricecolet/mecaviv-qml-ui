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

    // Position courante (affichage transport)
    property real currentTimeMs: 0
    property int currentBar: 1
    property int currentBeatInBar: 1
    property real currentBeat: 1.0
    property real currentTempoBpm: 120
    property int totalBars: 1
    property real totalDurationMs: 0
    /** Fin du morceau en ms (meta end-of-track ou dernier tick). Utilisé pour envoyer stop quand targetY l’atteint. */
    property real endOfPieceMs: 0

    // Morceau chargé
    property string currentMidiPath: ""
    property string currentSongTitle: ""
    property var sequencerNotes: []
    property real sequencerBpm: 120
    property real sequencerPpq: 480
    property var sequencerTempoMap: []
    property var sequencerTimeSignatureMap: []
    property real lookaheadMs: 8000
    /** Durée de chute (ms) jusqu'au point de jeu — même valeur que l'animation (MelodicLine2D). Délai avant envoi de « play » à Pd. */
    property real animationFallDurationMs: 5000
    
    // Cache pour optimiser les calculs de position
    property real _lastPositionTimeMs: -1
    property var _lastPositionResult: null


    readonly property string positionDisplayText: {
        var b = root.currentBar
        var t = root.currentBeat
        if (typeof b !== "number" || typeof t !== "number" || !isFinite(b) || !isFinite(t))
            return "—"
        // Permettre les mesures négatives (preroll) ou positives (normal)
        var bar = b < 0 ? Math.max(-9999, Math.min(-1, Math.floor(b))) : Math.max(1, Math.min(9999, Math.floor(b)))
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
        root.endOfPieceMs = 0
        root.isPlaying = false
        root.previousBeat = -1
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = 0
        // Réinitialiser le cache
        root._lastPositionTimeMs = -1
        root._lastPositionResult = null
    }

    /** Démarre le séquenceur UI depuis 0. PureData retarde la sortie MIDI de animationFallDurationMs. */
    function startFromZero() {
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = Date.now()
        root.isPlaying = true
        root.currentTimeMs = 0
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
        root.currentTempoBpm = root.sequencerBpm || 120
    }

    function applyPositionFromPd(playing, timeMs) {
        if (!playing) return
        
        root.lastPositionMs = timeMs
        root._lastUpdateTimestamp = Date.now()
        root.currentTimeMs = timeMs
        
        var pos = GameSequencer.positionFromMs(timeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
        root.currentBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
        root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar)))
        root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
        root.currentTempoBpm = GameSequencer.getBpmAtMs(timeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
    }

    /** Envoie stop à Pd et met à jour l’UI (fin du morceau atteinte à targetY). */
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
        GameSequencer.loadNotes(root.currentMidiPath, channelOrTrack, function(notes, bpm, ppq, tempoMap, timeSignatureMap, endOfTrackTick) {
            root.sequencerNotes = notes || []
            root.sequencerPpq = ppq || 480
            root.sequencerTempoMap = tempoMap || []
            root.sequencerTimeSignatureMap = timeSignatureMap || []
            if (root.sequencerTempoMap.length > 0 && root.sequencerTempoMap[0].microsecondsPerQuarter > 0)
                root.sequencerBpm = Math.round(60000000 / root.sequencerTempoMap[0].microsecondsPerQuarter)
            else
                root.sequencerBpm = (typeof bpm === "number" && bpm > 0) ? bpm : 120
            root.totalDurationMs = GameSequencer.getTotalDurationMs(root.sequencerNotes, ppq, tempoMap)
            // Fin du morceau : meta end-of-track si fournie, sinon dernier tick (fin dernière note)
            // + falltime pour que le stop soit envoyé quand la fin a atteint targetY (dernières notes jouées)
            var endMs = (endOfTrackTick != null && typeof endOfTrackTick === "number" && endOfTrackTick >= 0)
                ? GameSequencer.tickToMs(endOfTrackTick, ppq, tempoMap)
                : root.totalDurationMs
            var fallMs = root.animationFallDurationMs || 5000
            root.endOfPieceMs = endMs + fallMs
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
                if (root.endOfPieceMs > 0 && timeMs >= root.endOfPieceMs) {
                    root.requestStop()
                    root.reset()
                    root.isPlaying = false
                    root.previousBeat = tick
                    return
                }
            }
            root.isPlaying = playing
            root.previousBeat = tick
        })
        ws.playbackPositionReceived.connect(function(playing, bar, beatInBar, beat) {
            if (!playing) root.reset()
            if (playing) {
                // Utiliser bar/beat de Pd uniquement pour recaler le temps (Pd peut être en retard)
                var bar1 = Math.max(1, bar)
                var timeMs = GameSequencer.positionToMsWithMaps(bar1, beatInBar, beat, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
                root.lastPositionMs = timeMs
                root.currentTimeMs = timeMs
                root._lastUpdateTimestamp = Date.now()
                // Fin du morceau : quand la position (targetY) atteint la fin, envoyer stop
                if (root.endOfPieceMs > 0 && timeMs >= root.endOfPieceMs) {
                    root.requestStop()
                    root.reset()
                    root.isPlaying = false
                    root.previousBeat = beat
                    return
                }
                root.currentTempoBpm = GameSequencer.getBpmAtMs(timeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
                // Affichage = mesure à targetY (ce qui est joué), pas à spawn (délai MIDI)
                var displayTimeMs = timeMs - root.animationFallDurationMs
                var pos = GameSequencer.positionFromMs(displayTimeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
                // Mettre à jour le cache
                root._lastPositionTimeMs = displayTimeMs
                root._lastPositionResult = pos
                root.currentBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
                root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar || 1)))
                root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
            }
            root.isPlaying = playing
            root.previousBeat = beat
        })
        root._tickConnected = true
    }

    // Extrapolation : avancer currentTimeMs entre deux messages Pd
    Timer {
        id: extrapolationTimer
        interval: 50
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (!root.isPlaying) return
            
            // Extrapolation linéaire depuis le dernier message Pd
            var now = Date.now()
            var delta = now - root._lastUpdateTimestamp
            root.currentTimeMs = root.lastPositionMs + delta
            
            // Fin du morceau : quand la position (targetY) atteint la fin, envoyer stop
            if (root.endOfPieceMs > 0 && root.currentTimeMs >= root.endOfPieceMs) {
                root.requestStop()
                root.reset()
                return
            }
            
            // Affichage = mesure à targetY (ce qui est joué), pas à spawn (délai MIDI)
            var displayTimeMs = root.currentTimeMs - root.animationFallDurationMs
            
            // Toujours recalculer pour éviter les erreurs lors des changements de signature
            // (le cache peut causer des valeurs incorrectes lors des transitions)
            var pos = GameSequencer.positionFromMs(displayTimeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
            root._lastPositionTimeMs = displayTimeMs
            root._lastPositionResult = pos
            
            root.currentBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
            root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar || 1)))
            root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
            root.currentTempoBpm = GameSequencer.getBpmAtMs(root.currentTimeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
        }
    }

    onConfigControllerChanged: connectPlaybackSignals()
    Component.onCompleted: connectPlaybackSignals()
}
