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
    /** Durée de chute (ms) jusqu'au point de jeu — même valeur que l'animation (MelodicLine2D). Délai avant envoi de « play » à Pd. */
    property real animationFallDurationMs: 5000

    /** Timestamp (Date.now()) au clic Play, pour phase countdown. */
    property real playStartTimestamp: 0
    /** Délai (ms) entre l'envoi du message "play" et le démarrage réel de Pd. Peut être plusieurs secondes si Pd met du temps à démarrer. Mis à jour au 1er message Pd. */
    property real _pdStartDelayMs: 0
    /** Pour ne logger la transition preroll -> >=0 qu'une seule fois. */
    property bool _loggedPrerollTransition: false
    /** Temps d'affichage : pendant le countdown (avant 1er message Pd) = 0 ; après = currentTimeMs. Pilote segments et barres. */
    readonly property real displayTimeMs: (root.isPlaying && !root._receivedPositionSinceStart) ? 0 : root.currentTimeMs
    /** Mesure d'affichage : pendant le countdown = 1 ; après = currentBar. */
    readonly property int displayBar: (root.isPlaying && !root._receivedPositionSinceStart) ? 1 : root.currentBar

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
        root.isPlaying = false
        root.previousBeat = -1
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = 0
        root._receivedPositionSinceStart = false
        root.playStartTimestamp = 0
    }

    /** Démarre le séquenceur UI depuis 0 (à appeler avant d'envoyer play à Pd). */
    function startFromZero() {
        root.currentTimeMs = 0
        root.currentBar = 1
        root.currentBeatInBar = 1
        root.currentBeat = 1.0
        root.lastPositionMs = 0
        root._lastUpdateTimestamp = Date.now()
        root._receivedPositionSinceStart = false
        root._loggedPrerollTransition = false
        root.playStartTimestamp = Date.now()
        root.isPlaying = true
    }

    function applyPositionFromPd(playing, timeMs) {
        root.lastPositionMs = timeMs
        if (!playing) return
        var wasPreroll = !root._receivedPositionSinceStart
        root._receivedPositionSinceStart = true
        
        var now = Date.now()
        // Si on vient du preroll, corriger le timestamp pour correspondre exactement à Pd
        if (wasPreroll) {
            // Le message "play" a été envoyé à playStartTimestamp + animationFallDurationMs
            // Pd commence à timeMs=0 à ce moment-là
            // Quand Pd envoie sa première position avec timeMs, on doit ajuster _lastUpdateTimestamp
            // pour que l'extrapolation continue correctement à partir de cette valeur
            // On ajuste _lastUpdateTimestamp pour que l'extrapolation donne timeMs
            root._lastUpdateTimestamp = now - timeMs
        } else {
            root._lastUpdateTimestamp = now
        }
        
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
                var wasPreroll = !root._receivedPositionSinceStart
                root._receivedPositionSinceStart = true
                // Pd envoie mesure 0 = première mesure → afficher mesure 1 (1-based)
                var bar1 = Math.max(1, bar)
                root.currentBar = bar1
                root.currentBeatInBar = Math.max(1, Math.min(16, beatInBar || 1))
                root.currentBeat = Math.max(1, Math.min(17, (typeof beat === "number" && isFinite(beat)) ? beat : 1))
                var timeMs = GameSequencer.positionToMsWithMaps(bar1, beatInBar, beat, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
                
                var now = Date.now()
                var tempsUI = 0
                if (wasPreroll) {
                    var playMessageTime = root.playStartTimestamp + root.animationFallDurationMs
                    tempsUI = now - playMessageTime
                    var pdDelayMs = (timeMs - tempsUI) < 0 ? Math.max(0, tempsUI - timeMs) : 0
                    root._pdStartDelayMs = pdDelayMs
                } else {
                    tempsUI = root.lastPositionMs + (now - root._lastUpdateTimestamp)
                }
                var drift = timeMs - tempsUI
                var sens = drift > 0 ? "Pd en avance" : (drift < 0 ? "UI en avance" : "synchro")
                console.log("décalage: m%1 b%2 | Pd=%3 ms UI=%4 ms drift=%5 ms (%6)"
                            .arg(bar1).arg(beat.toFixed(1)).arg(timeMs).arg(Math.round(tempsUI)).arg(drift).arg(sens))
                root.lastPositionMs = timeMs
                root.currentTimeMs = timeMs
                root._lastUpdateTimestamp = now
                root.currentTempoBpm = GameSequencer.getBpmAtMs(timeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
            }
            root.isPlaying = playing
            root.previousBeat = beat
        })
        root._tickConnected = true
    }

    // Extrapolation : avancer currentTimeMs entre deux messages Pd. Utilise la même logique que Pd (tempo map + time signature) pour éviter un décalage de currentBar (ex. barres « en double » avec numéro +2).
    Timer {
        id: extrapolationTimer
        interval: 50
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (!root.isPlaying) return
            var now = Date.now()
            // Pendant le preroll (avant premier message Pd), calculer le temps depuis playStartTimestamp
            if (!root._receivedPositionSinceStart) {
                if (root.playStartTimestamp > 0) {
                    // Le message "play" sera envoyé à playStartTimestamp + animationFallDurationMs
                    // Pd commencera à timeMs=0 à ce moment-là, mais avec un délai de traitement
                    // On calcule currentTimeMs comme le temps écoulé depuis que le message "play" serait envoyé
                    // en tenant compte du délai de traitement de Pd (_pdStartDelayMs)
                    var playMessageTime = root.playStartTimestamp + root.animationFallDurationMs
                    var timeSincePlayMessage = now - playMessageTime
                    // Soustraire le délai de traitement de Pd pour correspondre exactement à ce que Pd calculera
                    root.currentTimeMs = timeSincePlayMessage - root._pdStartDelayMs
                } else {
                    root.currentTimeMs = -root.animationFallDurationMs
                }
                
                // Calculer les mesures preroll (négatives) : temps avant le début
                var timeBeforeStart = -root.currentTimeMs  // currentTimeMs est négatif, donc timeBeforeStart est positif
                
                if (timeBeforeStart > 0 && root.currentTimeMs < 0) {
                    // Calculer les beats avant le début en utilisant le tempo
                    var bpm = root.sequencerBpm || 120
                    var beatsBeforeStart = (timeBeforeStart / 1000) * (bpm / 60)
                    // Calculer les mesures (en supposant 4/4 par défaut)
                    var beatsPerBar = 4  // TODO: utiliser la vraie signature temporelle
                    var prerollBar = Math.floor(beatsBeforeStart / beatsPerBar) + 1
                    var prerollBeatInBar = (Math.floor(beatsBeforeStart) % beatsPerBar) + 1
                    var prerollBeat = (beatsBeforeStart % beatsPerBar) + 1
                    
                    // Assigner les mesures négatives pour l'affichage
                    root.currentBar = -prerollBar
                    root.currentBeatInBar = Math.max(1, Math.min(16, prerollBeatInBar))
                    root.currentBeat = prerollBeat
                    root.currentTempoBpm = bpm
                    return  // Ne pas continuer avec positionFromMs pendant le preroll
                }
                if (root.currentTimeMs >= 0 && !root._loggedPrerollTransition)
                    root._loggedPrerollTransition = true
            }
            if (root._receivedPositionSinceStart) {
                var delta = now - root._lastUpdateTimestamp
                root.currentTimeMs = root.lastPositionMs + delta
            }
            var pos = GameSequencer.positionFromMs(root.currentTimeMs, root.sequencerBpm, root.sequencerPpq, root.sequencerTempoMap, root.sequencerTimeSignatureMap)
            var newBar = Math.max(1, Math.min(9999, Math.floor(pos.bar)))
            var oldBar = root.currentBar
            
            // Ne jamais reculer : les maps (tempo/time sig) peuvent donner barre 1 pour un temps déjà en barre 2+ (ex. première barre très longue)
            if (newBar >= oldBar) {
                root.currentBar = newBar
            }
            // Toujours mettre à jour le beat, même si on reste dans la même mesure
            root.currentBeatInBar = Math.max(1, Math.min(16, Math.floor(pos.beatInBar || 1)))
            root.currentBeat = Math.max(1, Math.min(17, (typeof pos.beat === "number" && isFinite(pos.beat)) ? pos.beat : 1))
            
            root.currentTempoBpm = GameSequencer.getBpmAtMs(root.currentTimeMs, root.sequencerPpq, root.sequencerTempoMap, root.sequencerBpm)
        }
    }

    onConfigControllerChanged: connectPlaybackSignals()
    Component.onCompleted: connectPlaybackSignals()
}
