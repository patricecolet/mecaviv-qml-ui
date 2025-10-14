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
    property real ambitusMin: sirenInfo ? sirenInfo.ambitus.min : 48.0
    property real ambitusMax: sirenInfo ? sirenInfo.ambitus.max : 84.0
    property string clef: sirenInfo ? sirenInfo.clef : "treble"
    
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
    }
    
    // Fonction pour traiter les événements MIDI
    function processMidiEvents() {
        var segments = []
        
        for (var i = 0; i < midiEvents.length; i++) {
            var event = midiEvents[i]
            
            // Créer un segment pour chaque événement
            segments.push({
                timestamp: event.timestamp,
                note: event.note,
                velocity: event.velocity,
                x: 0,  // Position X (sera calculée selon le temps)
                vibrato: event.controllers ? event.controllers.modPedal > 64 : false,
                tremolo: event.controllers ? event.controllers.pad > 0 : false,
                volume: event.velocity / 127.0
            })
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
            timestamp: event.timestamp || Date.now(),
            note: event.note || event.midiNote || 60,
            velocity: event.velocity || 100,
            controllers: event.controllers || {}
        })
    }
    
    // Mettre à jour les segments quand les événements changent
    onMidiEventsChanged: {
        lineSegmentsData = processMidiEvents()
    }
}

