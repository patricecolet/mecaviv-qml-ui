import QtQuick
import QtQuick3D
import "../components"
import "../components/ambitus"
import "."

Node {
    id: root
    
    // Propriétés de configuration
    property var configController: null
    property var sirenInfo: null
    property real currentNoteMidi: 60.0
    
    // Propriétés de jeu
    property var midiEvents: []  // Événements MIDI reçus
    property real gameStartTime: 0
    property bool gameActive: false
    
    // Propriété pour savoir si le mode jeu est actif (liée depuis SirenDisplay)
    property bool isGameModeActive: false
    
    // Propriété calculée pour les segments de ligne
    property var lineSegmentsData: []
    
    // Signal pour recevoir les événements MIDI
    signal midiEventReceived(var event)
    
    // Propriétés de la portée
    property real staffWidth: 1800
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
        if (!sirenInfo) return 0
        // Forcer la réévaluation avec updateCounter
        if (configController) {
            var dummy = configController.updateCounter
        }
        return sirenInfo.displayOctaveOffset || 0
    }
    
    // Calcul de l'offset pour la clé (comme dans MusicalStaff3D)
    property real clefWidth: 100  // Largeur de la clé
    property real ambitusOffset: clefWidth  // Offset pour l'ambitus
    
    // Portée musicale (cachée en mode normal)
    MusicalStaff3D {
        id: musicalStaff
        visible: false  // Toujours cachée - on utilise celle du mode normal
        
        configController: root.configController
        sirenInfo: root.sirenInfo
        currentNoteMidi: root.currentNoteMidi
        
        staffWidth: root.staffWidth
        lineSpacing: root.lineSpacing
        clef: root.clef
        ambitusMin: root.ambitusMin
        ambitusMax: root.ambitusMax
    }
    
    // Ligne mélodique (visible seulement en mode jeu)
    MelodicLine3D {
        id: melodicLine
        visible: root.isGameModeActive  // Visible seulement quand le mode jeu est actif
        
        lineSegments: lineSegmentsData
        lineSpacing: root.lineSpacing
        ambitusMin: root.ambitusMin
        ambitusMax: root.ambitusMax
        staffWidth: root.staffWidth
        ambitusOffset: root.ambitusOffset
        octaveOffset: sirenInfo ? sirenInfo.displayOctaveOffset : 0 
        clef: root.clef
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
    
    // Fonction pour arrêter le jeu
    function stopGame() {
        gameActive = false
    }
    
    // Fonction pour réinitialiser
    function resetGame() {
        midiEvents = []
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
    
    // Mettre à jour les segments quand les événements changent
    onMidiEventsChanged: {
        lineSegmentsData = processMidiEvents()
    }
}

