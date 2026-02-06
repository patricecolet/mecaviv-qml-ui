import QtQuick
import "../components/ambitus"
import "."
import "GameSequencer.js" as GameSequencer

Item {
    id: root
    
    // Propriétés de configuration
    property var configController: null
    property var sirenInfo: null
    property real currentNoteMidi: 60.0
    property var sequencer: null  // Référence au SequencerController
    
    // Propriétés de jeu
    property var midiEvents: []  // Événements MIDI reçus
    property real gameStartTime: 0
    property bool gameActive: false
    
    // Propriété pour savoir si le mode jeu est actif (liée depuis Test2D)
    property bool isGameModeActive: true  // Toujours actif quand GameMode est chargé
    
    // Propriété pour suivre le temps du séquenceur (mis à jour par le Timer)
    property real _sequencerTime: 0

    // Option : afficher les segments d'anticipation (fin note N → début note N+1). Désactivé par défaut.
    property bool showAnticipationLine: false
    // Option : afficher les barres de mesure en chute. Désactivé par défaut.
    property bool showMeasureBars: false
    
    // Propriété calculée pour les segments de ligne
    // Si sequencer est disponible, utiliser les segments calculés avec lookahead
    // Sinon, utiliser les événements MIDI reçus
    // Dépend de _sequencerTime pour forcer la réévaluation
    property var lineSegmentsData: {
        // Utiliser _sequencerTime pour forcer la réévaluation quand le Timer met à jour
        var dummy = root._sequencerTime
        // Ne pas afficher les notes en chute tant qu'on n'a pas appuyé sur Play
        if (!root.sequencer || !root.sequencer.isPlaying)
            return []
        if (root.sequencer.sequencerNotes && root.sequencer.sequencerNotes.length > 0) {
            // Utiliser le séquenceur pour calculer les segments avec lookahead
            var currentMs = root.sequencer.currentTimeMs || 0
            var lookahead = root.sequencer.lookaheadMs || 8000
            var notes = root.sequencer.sequencerNotes
            var ppq = root.sequencer.sequencerPpq || 480
            var tempoMap = root.sequencer.sequencerTempoMap || []
            
            // Debug log (limité pour éviter le spam)
            if (dummy % 1000 < 50) {  // Log toutes les secondes environ
                console.log("🎮 [GameMode] lineSegmentsData - notes:", notes.length, "currentMs:", currentMs, "lookahead:", lookahead)
            }
            
            // Mettre à jour les variables globales du module GameSequencer
            GameSequencer._notes = notes
            GameSequencer._ppq = ppq
            GameSequencer._tempoMap = tempoMap
            
            var segments = GameSequencer.getSegmentsInWindowFromMs(notes, currentMs, lookahead)
            if (dummy % 1000 < 50 && segments.length > 0) {
                console.log("🎮 [GameMode] segments calculés:", segments.length, "premier:", segments[0])
            }
            return segments
        } else {
            // Fallback : utiliser les événements MIDI reçus
            // Utiliser midiEvents pour forcer la réévaluation
            var dummy2 = root.midiEvents.length
            var fallbackSegments = processMidiEvents()
            if (fallbackSegments.length > 0) {
                console.log("🎮 [GameMode] fallback segments:", fallbackSegments.length)
            }
            return fallbackSegments
        }
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
    
    // Propriétés de la portée
    property real staffWidth: 1600
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

    // Segments pour la ligne d'anticipation : fenêtre élargie vers le passé
    // pour inclure les notes actuellement en chute (visibles sur la portée)
    property var anticipationSegmentsData: {
        var dummy = root._sequencerTime
        if (!root.sequencer || !root.sequencer.isPlaying)
            return []
        if (!root.sequencer.sequencerNotes || root.sequencer.sequencerNotes.length === 0)
            return []
        var currentMs = root.sequencer.currentTimeMs || 0
        var lookahead = root.sequencer.lookaheadMs || 8000
        var fft = root.sequencer.animationFallDurationMs || 5000
        var notes = root.sequencer.sequencerNotes
        // Fenêtre élargie : [currentMs - fft, currentMs + lookahead]
        // Inclut les notes dont le timestamp est passé mais qui tombent encore
        var wideStart = Math.max(0, currentMs - fft)
        GameSequencer._notes = notes
        GameSequencer._ppq = root.sequencer.sequencerPpq || 480
        GameSequencer._tempoMap = root.sequencer.sequencerTempoMap || []
        return GameSequencer.getSegmentsInWindowFromMs(notes, wideStart, lookahead + fft)
    }

    // Données des barres de mesure dans la fenêtre lookahead (pour création dynamique)
    property var measureBarsData: {
        var dummy = root._sequencerTime
        // Ne pas afficher les barres de mesure tant qu'on n'a pas appuyé sur Play
        if (!root.sequencer || !root.sequencer.isPlaying || !root.sequencer.sequencerNotes || root.sequencer.sequencerNotes.length === 0)
            return []
        var currentMs = root.sequencer.currentTimeMs || 0
        var lookahead = root.sequencer.lookaheadMs || 8000
        var ppq = root.sequencer.sequencerPpq || 480
        var tmap = root.sequencer.sequencerTempoMap || []
        var smap = root.sequencer.sequencerTimeSignatureMap || []
        return GameSequencer.getMeasureStartsInWindow(currentMs, lookahead, ppq, tmap, smap)
    }

    property var _measureBarCache: ({})
    Component {
        id: measureBarComponent
        FallingMeasureBar2D {}
    }

    // Zone de jeu : ordre d'affichage (notes z:1, ligne d'anticipation z:2 au-dessus, barres de mesure z:3)
    Item {
        id: gameArea
        anchors.fill: parent

        // Ligne d'anticipation (volant) — z: 2 au-dessus des notes pour rester visible
        // Utilise anticipationSegments (fenêtre élargie) pour inclure les notes actuellement en chute
        AnticipationLine2D {
            z: 2
            anchors.fill: parent
            visible: root.isGameModeActive && root.showAnticipationLine
            lineSegments: root.anticipationSegmentsData
            currentNoteMidi: root.currentNoteMidi
            currentTimeMs: root.sequencer ? root.sequencer.currentTimeMs : 0
            fallSpeed: 150
            fixedFallTime: root.sequencer ? root.sequencer.animationFallDurationMs : 5000
            lineSpacing: root.lineSpacing
            clef: root.clef
            ambitusMin: root.ambitusMin
            ambitusMax: root.ambitusMax
            staffWidth: root.staffWidth
            staffPosX: root.staffPosX
            ambitusOffset: root.ambitusOffset
            octaveOffset: root.octaveOffset
        }

        // Ligne mélodique 2D (notes en chute) — z: 1
        MelodicLine2D {
            id: melodicLine
            z: 1
            anchors.fill: parent
            visible: root.isGameModeActive

            lineSegments: root.lineSegmentsData
            currentTimeMs: root.sequencer ? root.sequencer.currentTimeMs : 0
            lineSpacing: root.lineSpacing
            clef: root.clef
            ambitusMin: root.ambitusMin
            ambitusMax: root.ambitusMax
            staffWidth: root.staffWidth
            staffPosX: root.staffPosX
            ambitusOffset: root.ambitusOffset
            octaveOffset: root.octaveOffset
            fixedFallTime: root.sequencer ? root.sequencer.animationFallDurationMs : 5000

            vibratoAmount: root.vibratoAmount
            vibratoRate: root.vibratoRate
            tremoloAmount: root.tremoloAmount
            tremoloRate: root.tremoloRate
            attackTime: root.attackTime
            releaseTime: root.releaseTime
        }
    }

    onShowMeasureBarsChanged: {
        if (!root.showMeasureBars) {
            for (var k in _measureBarCache) {
                var barObj = _measureBarCache[k]
                if (barObj && barObj.destroy) barObj.destroy()
            }
            _measureBarCache = {}
        }
    }
    onMeasureBarsDataChanged: {
        if (!root.sequencer || !root.showMeasureBars) return
        var currentMs = root.sequencer.currentTimeMs || 0
        var midiDelay = root.sequencer.animationFallDurationMs || 5000
        var cursorBarY = melodicLine ? melodicLine.cursorBarY : (root.height / 2 + 30)
        var list = measureBarsData || []
        for (var i = 0; i < list.length; i++) {
            var m = list[i]
            var bar = m.bar
            var startMs = m.startMs
            var key = "bar-" + bar
            if (_measureBarCache[key]) {
                if (_measureBarCache[key].parent) continue
                delete _measureBarCache[key]
            }
            var fallMs = GameSequencer.calculateFallDurationMs(startMs, currentMs, midiDelay)
            if (fallMs <= 0) continue
            var obj = measureBarComponent.createObject(root, {
                targetY: cursorBarY,
                fallSpeed: 150,
                fixedFallTime: midiDelay,
                fallDurationMs: fallMs,
                measureNumber: bar,
                accentColor: "#d1ab00"
            })
            if (obj) {
                obj.z = 3
                _measureBarCache[key] = obj
            }
        }
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
        // Vider les événements MIDI
        midiEvents = []
        // NE PAS faire lineSegmentsData = [] ici !
        // Cela détruirait le binding QML de façon permanente.
        // Le binding retourne déjà [] quand !sequencer.isPlaying.
        gameActive = false
        gameStartTime = 0
        
        // Effacer toutes les notes en vol
        if (melodicLine) {
            melodicLine.clearAllNotes()
        }
        // Détruire les barres de mesure et vider le cache
        for (var k in _measureBarCache) {
            var barObj = _measureBarCache[k]
            if (barObj && barObj.destroy) barObj.destroy()
        }
        _measureBarCache = {}
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
    
    // Timer pour mettre à jour _sequencerTime régulièrement quand le séquenceur joue
    // Cela force la réévaluation de lineSegmentsData qui dépend de _sequencerTime
    Timer {
        interval: 50  // Mise à jour toutes les 50ms (même fréquence que l'extrapolation du séquenceur)
        running: root.sequencer && root.sequencer.isPlaying
        repeat: true
        onTriggered: {
            if (root.sequencer) {
                root._sequencerTime = root.sequencer.currentTimeMs || 0
            }
        }
    }
    
    // Mettre à jour _sequencerTime quand le séquenceur change
    onSequencerChanged: {
        if (sequencer) {
            console.log("🎮 [GameMode] Sequencer assigné, notes:", sequencer.sequencerNotes ? sequencer.sequencerNotes.length : 0, "currentTimeMs:", sequencer.currentTimeMs)
            _sequencerTime = sequencer.currentTimeMs || 0
        }
    }
    
    // Mettre à jour _sequencerTime quand les événements MIDI changent (fallback si pas de séquenceur)
    // Ne pas réassigner lineSegmentsData directement, laisser le binding faire son travail
    onMidiEventsChanged: {
        // Le binding de lineSegmentsData se mettra à jour automatiquement
        // car il vérifie si sequencer.sequencerNotes existe
    }
}

