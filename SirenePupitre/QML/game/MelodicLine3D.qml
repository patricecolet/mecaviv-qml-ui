import QtQuick
import QtQuick3D
import "../components/ambitus"
Node {
    id: root
        // Instances
    NotePositionCalculator {
        id: noteCalc
    }
    // Propriétés
    property var lineSegments: []
    property real lineSpacing: 20
    property real ambitusMin: 48.0
    property real ambitusMax: 84.0
    property real staffWidth: 1800
    property real ambitusOffset: 0
    property real fallSpeed: 150  // Vitesse de chute
    property real spawnHeight: 500  // Hauteur de départ
    property int octaveOffset: 0 
    property string clef: "treble"
    // Propriétés calculées
    readonly property real ambitusRange: ambitusMax - ambitusMin
    readonly property real staffHeight: ambitusRange * lineSpacing
    
    // Component pour créer les cubes (créé une seule fois)
    Component {
        id: cubeComponent
        FallingNote {
        }
    }
    
// Fonction pour convertir une note MIDI en position Y sur la portée
function noteToY(note) {
    // Appliquer octaveOffset comme dans AmbitusDisplay3D pour que les cubes atteignent les notes
    var offsetNote = note + (octaveOffset * 12)
    var y = noteCalc.calculateNoteYPosition(offsetNote, lineSpacing, clef)
    return y
}
function noteToX(note) {
    // Utiliser la même fonction que AmbitusDisplay3D pour la cohérence
    // staffPosX = 0 + ambitusOffset/2 (comme dans AmbitusDisplay3D)
    // staffWidth = staffWidth - ambitusOffset (comme dans AmbitusDisplay3D)
    var staffPosX = ambitusOffset / 2
    var effectiveStaffWidth = staffWidth - ambitusOffset
    var x = noteCalc.calculateNoteXPosition(note, ambitusMin, ambitusMax, staffPosX, effectiveStaffWidth)
    
    //console.log("🎵 noteToX - note:", note, "ambitusMin:", ambitusMin, "ambitusMax:", ambitusMax, "staffPosX:", staffPosX, "effectiveStaffWidth:", effectiveStaffWidth, "X:", x.toFixed(1))
    return x
}

    
    // Fonction pour obtenir une couleur selon la hauteur de la note
    function noteToColor(note) {
        var normalized = (note - ambitusMin) / ambitusRange
        var hue = 240 - (normalized * 180)  // 240 (bleu) -> 60 (rouge)
        return Qt.hsla(hue / 360, 0.8, 0.6, 1.0)
    }
    
    // Fonction pour créer un cube
    function createCube(segment) {
        var vel = segment.velocity
        
        // Filtrer les noteOff (vélocité = 0 ou undefined)
        if (vel === 0 || vel === undefined) {
            return  // Ne pas créer de cube pour noteOff
        }
        
        cubeComponent.createObject(root, {
            "targetY": noteToY(segment.note),
            "targetX": noteToX(segment.note),
            "spawnHeight": root.spawnHeight,
            "fallSpeed": root.fallSpeed,
            "cubeColor": noteToColor(segment.note),
            "velocity": vel,
            "duration": segment.duration ?? 1000  // Durée en ms (utiliser ?? au lieu de ||)
        })
    }
    
    // Surveiller les changements de lineSegments
    onLineSegmentsChanged: {
        // Créer un cube seulement pour le dernier segment (nouveau)
        if (lineSegments.length > 0) {
            var lastSegment = lineSegments[lineSegments.length - 1]
            createCube(lastSegment)
        }
    }
}
