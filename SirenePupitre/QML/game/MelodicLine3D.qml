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
    property real staffWidth: 1600
    property real staffPosX: 0
    property real ambitusOffset: 0
    property real fallSpeed: 150  // Vitesse de chute constante
    property real fixedFallTime: 5000  // Temps de chute fixe en ms (notes arrivent toutes en 5s)
    
    // Position Y de la barre du curseur (calculée comme dans NoteCursor3D.qml)
    property real cursorOffsetY: 30  // Distance sous la première note (par défaut)
    property real firstNoteY: noteCalc.calculateNoteYPosition(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    property real cursorBarY: firstNoteY - cursorOffsetY  // Bas du curseur vertical
    
    property int octaveOffset: 0 
    property string clef: "treble"
    
    // Paramètres MIDI CC (reçus depuis GameMode)
    property real vibratoAmount: 1.12
    property real vibratoRate: 5.0
    property real tremoloAmount: 0.15
    property real tremoloRate: 4.0
    property real attackTime: 100
    property real releaseTime: 200
    // Propriétés calculées
    readonly property real ambitusRange: ambitusMax - ambitusMin
    readonly property real staffHeight: ambitusRange * lineSpacing
    
    // Mode monophonique - Référence à la note courante
    property var currentNote: null
    
    
    // Component pour créer les cubes (créé une seule fois)
    Component {
        id: cubeComponent
        FallingNoteCustomGeo {
        }
    }
    
// Fonction pour convertir une note MIDI en position Y sur la portée
function noteToY(note) {
    // Appliquer octaveOffset comme AmbitusDisplay3D pour alignement avec la portée visible
    var offsetNote = note + (octaveOffset * 12)
    var y = noteCalc.calculateNoteYPosition(offsetNote, lineSpacing, clef)
    return y
}
function noteToX(note) {
    // Utiliser EXACTEMENT les mêmes paramètres que MusicalStaff3D passe à AmbitusDisplay3D
    // IMPORTANT : floor/ceil comme dans MusicalStaff3D ligne 112-113 !
    var flooredMin = Math.floor(ambitusMin)
    var ceiledMax = Math.ceil(ambitusMax)
    var adjustedStaffPosX = staffPosX + ambitusOffset / 2
    var adjustedStaffWidth = staffWidth - ambitusOffset
    var x = noteCalc.calculateNoteXPosition(note, flooredMin, ceiledMax, adjustedStaffPosX, adjustedStaffWidth)
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
        
        // Créer la nouvelle note d'abord
        var newNote = cubeComponent.createObject(root, {
            "targetY": root.cursorBarY,  // TOUTES les notes disparaissent à la barre du curseur
            "targetX": noteToX(segment.note),
            "fallSpeed": root.fallSpeed,
            "fixedFallTime": root.fixedFallTime,
            "cubeColor": noteToColor(segment.note),
            "velocity": vel,
            "duration": segment.duration ?? 1000,  // Durée en ms
            // Paramètres MIDI CC
            "attackTime": root.attackTime,
            "releaseTime": root.releaseTime,
            "vibratoAmount": root.vibratoAmount,
            "vibratoRate": root.vibratoRate,
            "tremoloAmount": root.tremoloAmount,
            "tremoloRate": root.tremoloRate
        })
        
        // MODE MONOPHONIQUE : Si une note était déjà en cours, la tronquer au niveau du bas de la nouvelle
        if (currentNote !== null && newNote !== null) {
            // Calculer le bas de la nouvelle note (centre - moitié de la durée, SANS le release)
            // Le release est au-dessus, donc on utilise totalDurationHeight, pas totalHeight
            var newNoteBottom = newNote.currentY - (newNote.totalDurationHeight * newNote.scale.y) / 2.0
            
            // Convertir en coordonnées locales de currentNote
            var deltaY = newNoteBottom - currentNote.currentY
            var localClip = deltaY / currentNote.scale.y
            
            currentNote.truncateNote(localClip)
        }
        
        // Garder la référence de la note courante
        currentNote = newNote
    }
    
    // Surveiller les changements de lineSegments
    onLineSegmentsChanged: {
        // Créer un cube seulement pour le dernier segment (nouveau)
        if (lineSegments.length > 0) {
            var lastSegment = lineSegments[lineSegments.length - 1]
            createCube(lastSegment)
        }
    }
    
    // Fonction pour réinitialiser toutes les notes (appelée lors d'un stop)
    function clearAllNotes() {
        // Détruire toutes les notes enfants
        for (var i = root.children.length - 1; i >= 0; i--) {
            var child = root.children[i]
            // Vérifier si c'est un FallingNoteCustomGeo (pas le NotePositionCalculator)
            if (child && child.targetY !== undefined) {
                child.destroy()
            }
        }
        // Réinitialiser la référence
        currentNote = null
    }
}
