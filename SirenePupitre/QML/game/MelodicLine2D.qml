import QtQuick
import "../components/ambitus"
import "."
import "GameSequencer.js" as GameSequencer

/**
 * Ligne mélodique 2D : gère les segments et crée les notes en chute (FallingNote2D).
 * Même API que MelodicLine3D (lineSegments, lineSpacing, ambitus, staffWidth, cursorBarY, etc.)
 * en coordonnées 2D (pixels). À placer en sibling de StaffZone2D dans l'overlay mode jeu.
 */
Item {
    id: root

    NotePositionCalculator2D {
        id: noteCalc2D
    }

    property var lineSegments: []
    // Temps courant en ms (séquenceur lookahead) — si > 0 et plusieurs segments, on crée une note par segment
    property real currentTimeMs: 0
    property real lineSpacing: 20
    property real ambitusMin: 48.0
    property real ambitusMax: 84.0
    property real staffWidth: 1600
    property real staffPosX: 0
    property real ambitusOffset: 0
    property real fallSpeed: 150
    property real fixedFallTime: 5000

    property real centerY: height / 2
    property real cursorOffsetY: 30
    property int octaveOffset: 0
    property string clef: "treble"

    property real vibratoAmount: 1.12
    property real vibratoRate: 5.0
    property real tremoloAmount: 0.15
    property real tremoloRate: 4.0
    property real attackTime: 100
    property real releaseTime: 200

    readonly property real ambitusRange: ambitusMax - ambitusMin
    // Même repère X que MusicalStaff2D / AmbitusDisplay2D (marge incluse)
    readonly property real _ambitusMarginX: lineSpacing * 2
    readonly property real _ambitusStartX: staffPosX + ambitusOffset + _ambitusMarginX
    readonly property real _ambitusWidth: (staffWidth - ambitusOffset) - _ambitusMarginX * 2
    readonly property real _firstNoteY: noteCalc2D.calculateNoteY(ambitusMin + (octaveOffset * 12), lineSpacing, clef)
    readonly property real cursorBarY: centerY + _firstNoteY + cursorOffsetY

    property var currentNote: null
    // Segments pour lesquels une note en chute existe déjà (clé = "timestamp-note") — on ne détruit jamais une note "sortie" de la fenêtre, elle finit sa chute
    property var _segmentNotes: ({})
    property int _lastLoggedSegments: 0

    Component {
        id: noteComponent
        FallingNote2D {}
    }

    function noteToY(note) {
        var offsetNote = note + (octaveOffset * 12)
        return centerY + noteCalc2D.calculateNoteY(offsetNote, lineSpacing, clef)
    }

    // Même formule que AmbitusDisplay2D : ambitusStartX + ambitusWidth pour aligner notes en chute et cercles de l'ambitus
    function noteToX(note) {
        var flooredMin = Math.floor(ambitusMin)
        var ceiledMax = Math.ceil(ambitusMax)
        return noteCalc2D.calculateNoteX2D(note, flooredMin, ceiledMax, _ambitusStartX, _ambitusWidth)
    }

    function noteToColor(note) {
        var normalized = (note - ambitusMin) / ambitusRange
        var hue = 240 - (normalized * 180)
        return Qt.hsla(hue / 360, 0.8, 0.6, 1.0)
    }

    function createCube(segment, fallDurationMs) {
        var vel = segment.velocity
        if (vel === 0 || vel === undefined)
            return null
        // Ne pas créer si la note est déjà passée
        if (fallDurationMs <= 0)
            return null

        var opts = {
            "targetY": root.cursorBarY,
            "targetX": noteToX(segment.note),
            "midiNote": segment.note,
            "fallSpeed": root.fallSpeed,
            "fixedFallTime": root.fixedFallTime,
            "fallDurationMs": fallDurationMs,
            "cubeColor": noteToColor(segment.note),
            "velocity": vel,
            "duration": segment.duration ?? 1000,
            "attackTime": root.attackTime,
            "releaseTime": root.releaseTime,
            "vibratoAmount": root.vibratoAmount,
            "vibratoRate": root.vibratoRate,
            "tremoloAmount": root.tremoloAmount,
            "tremoloRate": root.tremoloRate
        }

        var newNote = noteComponent.createObject(root, opts)
        return newNote
    }

    // Clé stable (timestamp en ms entier) pour éviter destroy/recreate à cause du flottant
    function segmentKey(seg) {
        var t = Number(seg.timestamp || 0)
        var n = seg.note !== undefined ? seg.note : 0
        return Math.round(t) + "-" + n
    }

    onLineSegmentsChanged: {
        // Ne PAS détruire les notes quand lineSegments est vide :
        // les notes en chute se détruisent elles-mêmes à la fin de leur animation.
        // clearAllNotes() n'est appelé que sur un stop explicite.
        if (lineSegments.length === 0)
            return
        // Créer les notes manquantes pour tous les segments dans la fenêtre
        for (var j = 0; j < lineSegments.length; j++) {
            var seg = lineSegments[j]
            var sk = segmentKey(seg)
            if (_segmentNotes[sk]) {
                // Vérifier si la note existe encore (pas détruite)
                var existingNote = _segmentNotes[sk]
                if (!existingNote || !existingNote.parent) {
                    // Note détruite, la retirer du cache pour permettre recreation si nécessaire
                    delete _segmentNotes[sk]
                } else {
                    continue  // Note existe encore
                }
            }
            var t = seg.timestamp || 0
            var fallMs = GameSequencer.calculateFallDurationMs(t, currentTimeMs, root.fixedFallTime)
            if (fallMs > 0) {
                var created = createCube(seg, fallMs)
                if (created) {
                    _segmentNotes[sk] = created
                }
            }
        }
    }

    function clearAllNotes() {
        for (var i = root.children.length - 1; i >= 0; i--) {
            var child = root.children[i]
            if (child && child.targetY !== undefined)
                child.destroy()
        }
        for (var k in _segmentNotes)
            delete _segmentNotes[k]
        currentNote = null
    }
}
