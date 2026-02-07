import QtQuick
import "../components/ambitus"
import "."

Item {
    id: root

    property var configController: null
    property var sirenInfo: null
    property real currentNoteMidi: 60.0
    /** Mis à true par Test2D quand l'utilisateur appuie sur Play (pour le Timer et le filtre de segments). */
    property bool isPlaying: false

    property var midiEvents: []
    property real gameStartTime: 0
    property bool gameActive: false
    property bool isGameModeActive: true

    property real _currentTimeMs: 0
    property real lookaheadMs: 8000
    property real fixedFallTime: 5000

    property bool showAnticipationLine: false
    property bool showMeasureBars: false

    property var lineSegmentsData: {
        var dummy = root._currentTimeMs
        if (!root.isPlaying) return []
        var all = root.processMidiEvents()
        var list = []
        var endMs = root._currentTimeMs + root.lookaheadMs
        for (var i = 0; i < all.length; i++) {
            var t = all[i].timestamp
            if (t >= root._currentTimeMs && t <= endMs)
                list.push(all[i])
        }
        return list
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

    property var anticipationSegmentsData: {
        var dummy = root._currentTimeMs
        if (!root.isPlaying) return []
        var all = root.processMidiEvents()
        var list = []
        var wideStart = Math.max(0, root._currentTimeMs - root.fixedFallTime)
        var endMs = root._currentTimeMs + root.lookaheadMs + root.fixedFallTime
        for (var i = 0; i < all.length; i++) {
            var t = all[i].timestamp
            if (t >= wideStart && t <= endMs)
                list.push(all[i])
        }
        return list
    }

    property var measureBarsData: []

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
            currentTimeMs: root._currentTimeMs
            fallSpeed: 150
            fixedFallTime: root.fixedFallTime
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
            currentTimeMs: root._currentTimeMs
            lineSpacing: root.lineSpacing
            clef: root.clef
            ambitusMin: root.ambitusMin
            ambitusMax: root.ambitusMax
            staffWidth: root.staffWidth
            staffPosX: root.staffPosX
            ambitusOffset: root.ambitusOffset
            octaveOffset: root.octaveOffset
            fixedFallTime: root.fixedFallTime

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
        // Barres de mesure désactivées (measureBarsData = [])
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
    
    function addMidiEvent(event) {
        var elapsed = (root.gameStartTime > 0) ? (Date.now() - root.gameStartTime) : 0
        var newEvents = midiEvents.slice()
        newEvents.push({
            timestamp: elapsed,
            note: event.note ?? event.midiNote ?? 60,
            velocity: event.velocity ?? 100,
            duration: event.duration ?? 500,
            controllers: event.controllers ?? {}
        })
        newEvents.sort(function(a, b) { return a.timestamp - b.timestamp })
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
    
    onMidiEventReceived: function(event) {
        addMidiEvent(event)
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
    
    Timer {
        interval: 50
        running: root.isPlaying && root.gameStartTime > 0
        repeat: true
        onTriggered: {
            root._currentTimeMs = Date.now() - root.gameStartTime
        }
    }
}

