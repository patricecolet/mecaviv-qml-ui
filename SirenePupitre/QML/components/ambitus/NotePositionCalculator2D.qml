import QtQuick
import "."

/**
 * Calculateur de positions 2D pour l'ambitus.
 * Une seule convention : X = grave→gauche, aiguë→droite. Y = délégation 3D (inverser ici si sens 2D faux).
 * Root en Item (pas QtObject) pour Emscripten.
 */
Item {
    id: root

    NotePositionCalculator {
        id: _noteCalc
    }

    /** X 2D : t = 0 (grave) → left, t = 1 (aiguë) → right. Une seule formule, pas de miroir. */
    function calculateNoteX2D(midiNote, ambitusMin, ambitusMax, ambitusStartX, ambitusWidth) {
        var lo = Math.min(ambitusMin, ambitusMax)
        var hi = Math.max(ambitusMin, ambitusMax)
        if (hi <= lo) return ambitusStartX
        var t = (midiNote - lo) / (hi - lo)
        var left = Math.min(ambitusStartX, ambitusStartX + ambitusWidth)
        var right = Math.max(ambitusStartX, ambitusStartX + ambitusWidth)
        return left + t * (right - left)
    }

    /** Y 2D : on inverse le Y du calculateur 3D pour que haut écran = notes aiguës (convention 2D). */
    function calculateNoteY(offsetNote, lineSpacing, clef) {
        return -_noteCalc.calculateNoteYPosition(offsetNote, lineSpacing, clef)
    }

    /** Délègue au calculateur commun. */
    function isNaturalNote(midiNote) {
        return _noteCalc.isNaturalNote(midiNote)
    }
}
