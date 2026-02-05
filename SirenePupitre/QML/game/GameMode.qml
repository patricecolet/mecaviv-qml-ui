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
    property var lineSegmentsData

    Component.onCompleted: {
        if (lineSegmentsData === undefined)
            lineSegmentsData = []
        if (staffWidth === 0)
            staffWidth = root.width || 1600
    }

    // État local (utilisé quand sequencer est null)
    property real _localTimeMs: 0
    property int _localBar: 1
    property int _localBeatInBar: 1
    property real _localBeat: 1.0
    property int _localTotalBars: 1
    property real _localTempoBpm: 120

    // Position / transport : depuis sequencer si fourni, sinon état local
    /** Temps "layout" : temps réel du séquenceur (négatif en preroll). Utilisé pour segments, barres et durée de chute des notes (aligné avec les barres). */
    readonly property real layoutTimeMs: root.sequencer ? root.sequencer.currentTimeMs : root._localTimeMs
    /** Temps pour affichage / compat : >= 0 (0 pendant preroll). Utiliser layoutTimeMs pour barres et notes. */
    readonly property real currentTimeMs: {
        if (!root.sequencer) return root._localTimeMs
        var t = root.sequencer.currentTimeMs
        return Math.max(0, t)
    }
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
        // Permettre les mesures négatives (preroll) ou positives (normal)
        var bar = b < 0 ? Math.max(-9999, Math.min(-1, Math.floor(b))) : Math.max(1, Math.min(9999, Math.floor(b)))
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
        var t = root.layoutTimeMs  // Même référence que les barres (négatif en preroll) pour aligner notes et barres
        var look = root.sequencer.lookaheadMs || 8000
        // En fin de morceau : étendre le lookahead jusqu'à la fin du contenu pour que les dernières notes restent visibles
        var contentEndMs = root.sequencer.endOfPieceMs - (root.sequencer.animationFallDurationMs || 5000)
        if (contentEndMs > 0 && t < contentEndMs)
            look = Math.max(look, contentEndMs - t)
        var segs = GameSequencer.getSegmentsInWindowFromMs(notes, t, look)
        root.lineSegmentsData = segs
    }
    
    // Suivi de la dernière mesure pour créer les barres
    property int _lastBar: 0
    // Cache pour éviter les recalculs trop fréquents
    property real _lastUpdateMeasureBarsTime: -1
    property int _lastStartBar: 0
    property int _lastEndBar: 0
    // Numéro de la plus grande barre déjà affichée (pour éviter de recréer les barres détruites)
    property int _highestBarShown: 0

    /** Retourne true si une barre pour ce numéro existe déjà ou a déjà été affichée et détruite. */
    function _measureBarExists(barNumber) {
        // Si cette barre a déjà été affichée et détruite, ne pas la recréer
        if (barNumber <= root._highestBarShown) {
            var bar = measureBarsContainer._createdBars[barNumber]
            // Seulement retourner true si la barre n'existe pas (a été détruite)
            // ou si elle existe encore
            if (!bar) return true  // Déjà affichée et détruite
            if (!bar.parent || bar.parent !== measureBarsContainer) {
                delete measureBarsContainer._createdBars[barNumber]
                return true  // Déjà affichée et détruite
            }
            return true  // Existe encore
        }
        
        var bar = measureBarsContainer._createdBars[barNumber]
        if (!bar) return false
        // Vérifier que la barre est toujours dans le conteneur (pas encore détruite)
        if (!bar.parent || bar.parent !== measureBarsContainer) {
            delete measureBarsContainer._createdBars[barNumber]
            return false
        }
        return true
    }

    /** Temps en ms du début de la mesure (négatif pour preroll). */
    function _measureStartMsForBar(barNumber) {
        var seq = root.sequencer
        var bpm = seq.sequencerBpm || seq.currentTempoBpm || 120
        var msPerBar = (60000 / bpm) * 4
        if (barNumber < 0)
            return barNumber * msPerBar
        var ppq = seq.sequencerPpq || 480
        var tempoMap = seq.sequencerTempoMap || []
        var timeSignatureMap = seq.sequencerTimeSignatureMap || []
        if (tempoMap.length > 0 && timeSignatureMap.length > 0) {
            // Utiliser directement positionToMsWithMaps sans ajustement firstNoteTimeMs
            // pour éviter les incohérences lors des changements de signature
            var measureStartMs = GameSequencer.positionToMsWithMaps(barNumber, 1, 1.0, ppq, tempoMap, timeSignatureMap)
            return measureStartMs
        }
        return (barNumber - 1) * msPerBar
    }

    /** Durée de chute en ms (0 = ne pas créer, barre déjà passée). */
    function _fallDurationMsForMeasureBar(measureStartMs, currentTimeMs, fixedFallTime) {
        return GameSequencer.calculateFallDurationMs(measureStartMs, currentTimeMs, fixedFallTime)
    }

    function createMeasureBar(barNumber) {
        if (!root.sequencer || !root.sequencer.isPlaying) return
        if (_measureBarExists(barNumber)) return

        var currentTimeMs = root.layoutTimeMs || 0
        var fixedFallTime = root.sequencer.animationFallDurationMs || 5000
        var measureStartMs = _measureStartMsForBar(barNumber)
        var fallDurationMs = _fallDurationMsForMeasureBar(measureStartMs, currentTimeMs, fixedFallTime)
        
        // Ne pas créer si la barre est déjà passée
        if (fallDurationMs <= 0) return

        var targetY = melodicLine ? melodicLine.cursorBarY : (root.height / 2)
        var fallSpeed = melodicLine ? melodicLine.fallSpeed : 150

        var opts = {
            "targetY": targetY,
            "fallSpeed": fallSpeed,
            "fixedFallTime": fixedFallTime,
            "fallDurationMs": fallDurationMs,
            "measureNumber": barNumber,
            "accentColor": "#d1ab00"
        }

        var newBar = measureBarComponent.createObject(measureBarsContainer, opts)
        if (newBar) {
            measureBarsContainer._createdBars[barNumber] = newBar
            // Enregistrer la plus grande barre affichée pour éviter de la recréer après destruction
            if (barNumber > root._highestBarShown)
                root._highestBarShown = barNumber
        }
    }
    
    function updateMeasureBars() {
        if (!root.sequencer || !root.sequencer.isPlaying) return

        var currentTimeMs = root.layoutTimeMs || 0
        var fixedFallTime = root.sequencer.animationFallDurationMs || 5000
        var lookaheadMs = root.sequencer.lookaheadMs || 8000
        var ppq = root.sequencer.sequencerPpq || 480
        var tempoMap = root.sequencer.sequencerTempoMap || []
        var timeSignatureMap = root.sequencer.sequencerTimeSignatureMap || []
        var bpm = root.sequencer.sequencerBpm || root.sequencer.currentTempoBpm || 120

        // Optimisation : éviter les recalculs trop fréquents (max toutes les 200ms)
        // Sauf si on a changé de mesure ou si les maps ont changé
        var timeSinceLastUpdate = currentTimeMs - root._lastUpdateMeasureBarsTime
        var currentBar = root.sequencer ? root.sequencer.currentBar : 1
        var needsFullRecalc = (timeSinceLastUpdate < 0 || timeSinceLastUpdate > 200) || 
                              (root._lastStartBar === 0 || root._lastEndBar === 0) ||
                              (currentBar < root._lastStartBar || currentBar > root._lastEndBar)
        
        if (!needsFullRecalc && root._lastStartBar > 0 && root._lastEndBar > 0) {
            // Mise à jour incrémentale : seulement créer les nouvelles barres nécessaires
            var endTimeMs = currentTimeMs + lookaheadMs
            var endPos = GameSequencer.positionFromMs(endTimeMs, bpm, ppq, tempoMap, timeSignatureMap)
            var newEndBar = Math.max(root._lastStartBar, Math.ceil(endPos.bar))
            
            // Créer seulement les barres manquantes à la fin
            if (newEndBar > root._lastEndBar) {
                for (var i = root._lastEndBar + 1; i <= newEndBar; i++) {
                    createMeasureBar(i)
                }
                root._lastEndBar = newEndBar
            }
            return
        }

        // Recalcul complet
        var startTimeMs = Math.max(0, currentTimeMs - fixedFallTime)
        var startPos = GameSequencer.positionFromMs(startTimeMs, bpm, ppq, tempoMap, timeSignatureMap)
        var startBar = Math.max(1, Math.floor(startPos.bar))

        var endTimeMs = currentTimeMs + lookaheadMs
        var endPos = GameSequencer.positionFromMs(endTimeMs, bpm, ppq, tempoMap, timeSignatureMap)
        var endBar = Math.max(startBar, Math.ceil(endPos.bar))

        for (var i = startBar; i <= endBar; i++) {
            createMeasureBar(i)
        }
        
        // Mettre à jour le cache
        root._lastUpdateMeasureBarsTime = currentTimeMs
        root._lastStartBar = startBar
        root._lastEndBar = endBar
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
    
    // Propriétés de la portée (staffWidth : défaut root.width||1600, peut être surchargé par le parent ex. Test2D)
    property real staffWidth
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
        currentTimeMs: root.layoutTimeMs
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
    
    // Conteneur pour les barres de mesure en chute
    Item {
        id: measureBarsContainer
        anchors.fill: parent
        z: 5  // Au-dessus de la ligne mélodique mais sous d'autres éléments
        
        Component {
            id: measureBarComponent
            FallingMeasureBar2D {}
        }
        
        // Barres de mesure déjà créées (clé = numéro de mesure)
        property var _createdBars: ({})
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
        // Nettoyer les barres de mesure
        clearMeasureBars()
    }
    
    function clearMeasureBars() {
        for (var key in measureBarsContainer._createdBars) {
            var bar = measureBarsContainer._createdBars[key]
            if (bar && typeof bar.destroy === "function")
                bar.destroy()
        }
        measureBarsContainer._createdBars = {}
        // Réinitialiser le cache
        root._lastUpdateMeasureBarsTime = -1
        root._lastStartBar = 0
        root._lastEndBar = 0
        root._highestBarShown = 0
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
        // Nettoyer les barres de mesure quand le séquenceur change (nouveau morceau)
        root.clearMeasureBars()
        if (root.sequencer) {
            if (root.sequencer.isPlaying) {
                root.updateLineSegmentsFromSequencer()
                root.updateMeasureBars()
            } else {
                root.lineSegmentsData = []
            }
        } else {
            root.lineSegmentsData = []
        }
    }

    Connections {
        target: root.sequencer
        enabled: !!root.sequencer
        function onCurrentTimeMsChanged() {
            // Toujours recalculer les segments quand currentTimeMs change
            // Pendant le preroll, currentTimeMs reste à 0 donc les segments restent stables
            // Après le preroll, currentTimeMs change et les segments sont mis à jour
            if (root.useSequencerData) {
                root.updateLineSegmentsFromSequencer()
            }
            root.updateMeasureBars()
        }
        // Ne pas appeler updateMeasureBars ici : currentBar dérive de currentTimeMs, on évite la double mise à jour
        function onCurrentBarChanged() {
            // (barres mises à jour via onCurrentTimeMsChanged)
        }
        function onIsPlayingChanged() {
            if (!root.sequencer || !root.useSequencerData) return
            if (root.sequencer.isPlaying) {
                root.updateLineSegmentsFromSequencer()
                // Nettoyer les barres existantes avant de recréer
                root.clearMeasureBars()
                root.updateMeasureBars()
            } else {
                root.lineSegmentsData = []
                root.clearMeasureBars()
            }
        }
        function onSequencerNotesChanged() {
            if (root.useSequencerData) {
                root.updateLineSegmentsFromSequencer()
                // Quand les notes changent (nouveau morceau), nettoyer et recréer les barres
                if (root.sequencer.isPlaying) {
                    root.clearMeasureBars()
                    root.updateMeasureBars()
                }
            }
        }
        function onSequencerTempoMapChanged() {
            // Quand la tempo map change (nouveau morceau), nettoyer et recréer les barres
            if (root.sequencer && root.sequencer.isPlaying) {
                root.clearMeasureBars()
                root.updateMeasureBars()
            }
        }
        function onSequencerTimeSignatureMapChanged() {
            // Quand la time signature map change (nouveau morceau), nettoyer et recréer les barres
            if (root.sequencer && root.sequencer.isPlaying) {
                root.clearMeasureBars()
                root.updateMeasureBars()
            }
        }
    }
}

