import QtQuick
import "."
import "GameSequencer.js" as GameSequencer

Item {
    id: root
    
    // Propriétés de configuration
    property var configController: null
    property var sirenInfo: null
    property real currentNoteMidi: 60.0
    
    // Propriétés de jeu
    property var midiEvents: []  // Événements MIDI reçus
    property real gameStartTime: 0
    property bool gameActive: false
    
    // Séquenceur partagé (optionnel) : si fourni, mesure/temps/tempo viennent de lui
    property var sequencer: null

    property bool isGameModeActive: false
    property var lineSegmentsData: []

    // État local (utilisé quand sequencer est null)
    property real _localTimeMs: 0
    property int _localBar: 1
    property int _localBeatInBar: 1
    property real _localBeat: 1.0
    property int _localTotalBars: 1
    property real _localTempoBpm: 120

    // Position / transport : depuis sequencer si fourni, sinon état local
    readonly property real currentTimeMs: root.sequencer ? root.sequencer.currentTimeMs : root._localTimeMs
    readonly property int currentBar: root.sequencer ? root.sequencer.currentBar : root._localBar
    readonly property int currentBeatInBar: root.sequencer ? root.sequencer.currentBeatInBar : root._localBeatInBar
    readonly property real currentBeat: root.sequencer ? root.sequencer.currentBeat : root._localBeat
    readonly property int totalBars: root.sequencer ? root.sequencer.totalBars : root._localTotalBars
    readonly property real currentTempoBpm: root.sequencer ? root.sequencer.currentTempoBpm : root._localTempoBpm
    // Chaîne formatée pour l’affichage (évite les bindings imbriqués foireux côté Test2D)
    readonly property string positionDisplayText: {
        var b = currentBar
        var t = currentBeat
        if (typeof b !== "number" || typeof t !== "number" || !isFinite(b) || !isFinite(t))
            return "—"
        var bar = Math.max(1, Math.min(9999, Math.floor(b)))
        var beat = Math.max(1, Math.min(17, t))
        return bar + " · " + beat.toFixed(1)
    }
    // Temps écoulé formaté mm:ss (ex. "1:23")
    readonly property string currentTimeDisplay: {
        var ms = currentTimeMs
        if (typeof ms !== "number" || !isFinite(ms) || ms < 0) return "0:00"
        var sec = Math.floor(ms / 1000)
        var min = Math.floor(sec / 60)
        sec = sec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }
    // Quand true, lineSegmentsData est fourni par le séquenceur (getSegmentsInWindowFromMs)
    property bool useSequencerData: false

    function updateLineSegmentsFromSequencer() {
        if (!root.sequencer || !root.useSequencerData) return
        if (!root.sequencer.isPlaying) {
            root.lineSegmentsData = []
            return
        }
        var notes = root.sequencer.sequencerNotes || []
        var t = root.sequencer.currentTimeMs
        var look = root.sequencer.lookaheadMs || 8000
        var segs = GameSequencer.getSegmentsInWindowFromMs(notes, t, look)
        root.lineSegmentsData = segs
    }

    // Signal pour recevoir les événements MIDI
    signal midiEventReceived(var event)
    
    // Paramètres MIDI CC (Control Change) - Désactivés par défaut
    property real vibratoAmount: 0.0    // CC1 (0-127 → 0.0-2.0)
    property real vibratoRate: 5.0      // CC9 (0-127 → 1.0-10.0 Hz)
    property real tremoloAmount: 0.0    // CC92 (0-127 → 0.0-0.3)
    property real tremoloRate: 4.0      // CC15 (0-127 → 1.0-10.0 Hz)
    property real attackTime: 0         // CC73 (0-127 → 0ms-38.1s, formule: 38100/(128-cc))
    property real releaseTime: 0        // CC72 (0-127 → 0ms-38.1s, formule: 38100/(128-cc))
    
    // Propriétés de la portée (staffWidth suit la largeur du conteneur en 2D)
    property real staffWidth: root.width || 1600
    property real staffPosX: 0
    property real lineSpacing: 20
    
    // Propriétés calculées avec réévaluation forcée
    property real ambitusMin: {
        if (!sirenInfo) return 48.0
        // Forcer la réévaluation avec updateCounter
        if (configController) {
            var dummy = configController.updateCounter
        }
        return sirenInfo.ambitus.min
    }
    
    property real ambitusMax: {
        if (!sirenInfo) return 84.0
        // Forcer la réévaluation avec updateCounter
        if (configController) {
            var dummy = configController.updateCounter
        }
        return sirenInfo.mode === "restricted" && sirenInfo.restrictedMax !== undefined ? sirenInfo.restrictedMax : sirenInfo.ambitus.max
    }
    
    property string clef: {
        if (!sirenInfo) return "treble"
        // Forcer la réévaluation avec updateCounter
        if (configController) {
            var dummy = configController.updateCounter
        }
        return sirenInfo.clef
    }
    
    property int octaveOffset: {
        // Utiliser le MÊME octaveOffset que la portée visible pour alignement
        if (!sirenInfo) return 0
        if (configController) {
            var dummy = configController.updateCounter
        }
        return sirenInfo.displayOctaveOffset || 0
    }
    
    // Accès à la config pour calculer ambitusOffset (comme dans MusicalStaff3D)
    property var staffConfig: {
        if (!configController) return {}
        var dummy = configController.updateCounter
        return configController.getConfigValue("displayConfig.components.musicalStaff", {})
    }
    property var clefConfig: staffConfig.clef || {}
    property var keySignatureConfig: staffConfig.keySignature || {}
    
    // Calcul dynamique des offsets (EXACTEMENT comme MusicalStaff3D)
    property bool showClef: clefConfig.visible !== false // true par défaut
    property bool showKeySignature: keySignatureConfig.visible === true // false par défaut
    property real clefWidth: showClef ? (clefConfig.width || 100) : 0
    property real keySignatureWidth: showKeySignature ? (keySignatureConfig.width || 80) : 0
    property real ambitusOffset: clefWidth + keySignatureWidth
    
    // Ligne mélodique 2D (notes en chute) — même coordonnées que la portée 2D de l'overlay
    MelodicLine2D {
        id: melodicLine
        anchors.fill: parent
        
        fixedFallTime: root.sequencer ? root.sequencer.animationFallDurationMs : 5000
        lineSegments: root.lineSegmentsData
        currentTimeMs: root.currentTimeMs
        lineSpacing: root.lineSpacing
        clef: root.clef
        ambitusMin: root.ambitusMin
        ambitusMax: root.ambitusMax
        staffWidth: root.staffWidth
        staffPosX: root.staffPosX
        ambitusOffset: root.ambitusOffset
        octaveOffset: root.octaveOffset
        
        vibratoAmount: root.vibratoAmount
        vibratoRate: root.vibratoRate
        tremoloAmount: root.tremoloAmount
        tremoloRate: root.tremoloRate
        attackTime: root.attackTime
        releaseTime: root.releaseTime
    }
    
    // Fonction pour traiter les événements MIDI
    function processMidiEvents() {
        var segments = []
        
        for (var i = 0; i < midiEvents.length; i++) {
            var event = midiEvents[i]
            
            // Créer un segment UNIQUEMENT au noteOn (velocity > 0)
            if (event.velocity > 0) {
                segments.push({
                    timestamp: event.timestamp,
                    note: event.note,
                    velocity: event.velocity,
                    duration: event.duration ?? 500,  // Utiliser la durée du paquet, ou 500ms par défaut
                    x: 0,
                    vibrato: event.controllers ? event.controllers.modPedal > 64 : false,
                    tremolo: event.controllers ? event.controllers.pad > 0 : false,
                    volume: event.velocity / 127.0
                })
            }
        }
        
        return segments
    }
    
    // Fonction pour ajouter un événement MIDI
    function addMidiEvent(event) {
        var newEvents = midiEvents.slice()  // Copier le tableau
        newEvents.push(event)
        
        // Trier par timestamp
        newEvents.sort(function(a, b) {
            return a.timestamp - b.timestamp
        })
        
        // Réassigner pour déclencher onMidiEventsChanged
        midiEvents = newEvents
    }
    
    // Fonction pour démarrer le jeu
    function startGame() {
        gameStartTime = Date.now()
        gameActive = true
    }
    
    // Fonction pour réinitialiser le mode jeu (appelée lors d'un stop)
    function resetGame() {
        midiEvents = []
        lineSegmentsData = []
        _localTimeMs = 0
        _localBar = 1
        _localBeatInBar = 1
        _localBeat = 1.0
        _localTotalBars = 1
        _localTempoBpm = 120
        if (!root.sequencer)
            useSequencerData = false
        gameActive = false
        gameStartTime = 0
        if (melodicLine)
            melodicLine.clearAllNotes()
    }
    
    // Fonction pour arrêter le jeu
    function stopGame() {
        gameActive = false
    }
    
    // Gérer la réception d'événements MIDI
    onMidiEventReceived: function(event) {
        // Ajouter l'événement à la liste
        addMidiEvent({
            timestamp: event.timestamp ?? Date.now(),
            note: event.note ?? event.midiNote ?? 60,
            velocity: event.velocity ?? 100,
            duration: event.duration ?? 500,  // Durée en ms
            controllers: event.controllers ?? {}
        })
    }
    
    // Gérer les Control Change MIDI
    function handleControlChange(ccNumber, ccValue) {
        // Sécurité : clamp à 0-127 (plage MIDI valide)
        var clampedValue = Math.max(0, Math.min(127, ccValue));
        // Normaliser la valeur MIDI (0-127 → 0.0-1.0)
        var normalized = clampedValue / 127.0;
        
        switch(ccNumber) {
            case 1:  // Vibrato Amount
                vibratoAmount = normalized * 4.0;  // 0.0 à 4.0 (×2)
                break;
            case 9:  // Vibrato Rate
                vibratoRate = 1.0 + normalized * 19.0;  // 1.0 à 20.0 Hz (×2)
                break;
            case 92:  // Tremolo Amount
                tremoloAmount = normalized * 0.6;  // 0.0 à 0.6 (×2)
                break;
            case 15:  // Tremolo Rate
                tremoloRate = 1.0 + normalized * 19.0;  // 1.0 à 20.0 Hz (×2)
                break;
            case 73:  // Attack Time
                attackTime = (ccValue == 0) ? 0 : 38100 / (128 - ccValue);  // Formule exacte du firmware
                break;
            case 72:  // Release Time
                releaseTime = (ccValue == 0) ? 0 : 38100 / (128 - ccValue);  // Formule exacte du firmware
                break;
        }
    }
    
    // Mettre à jour les segments quand les événements changent (sauf si séquenceur actif)
    onMidiEventsChanged: {
        if (!useSequencerData)
            lineSegmentsData = processMidiEvents()
    }

    onSequencerChanged: {
        root.useSequencerData = !!root.sequencer
        if (root.sequencer) {
            if (root.sequencer.isPlaying)
                root.updateLineSegmentsFromSequencer()
            else
                root.lineSegmentsData = []
        } else {
            root.lineSegmentsData = []
        }
    }

    Connections {
        target: root.sequencer
        enabled: !!root.sequencer
        function onCurrentTimeMsChanged() {
            if (root.useSequencerData)
                root.updateLineSegmentsFromSequencer()
        }
        function onIsPlayingChanged() {
            if (!root.sequencer || !root.useSequencerData) return
            if (root.sequencer.isPlaying)
                root.updateLineSegmentsFromSequencer()
            else
                root.lineSegmentsData = []
        }
        function onSequencerNotesChanged() {
            if (root.useSequencerData)
                root.updateLineSegmentsFromSequencer()
        }
    }
}

