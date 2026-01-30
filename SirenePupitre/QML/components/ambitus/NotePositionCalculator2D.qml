import QtQuick
import "."

/**
 * Calculateur de positions 2D pour l'ambitus.
 * Conventions 2D : zone ambitus = [ambitusStartX, ambitusStartX + ambitusWidth],
 * graves (basses) à gauche, aiguës (hautes) à droite.
 * Y et note naturelle délégués à NotePositionCalculator (logique commune 3D/2D).
 * Root en Item (pas QtObject) pour que le child soit accepté par la default property sous Emscripten.
 */
Item {
    id: root

    NotePositionCalculator {
        id: _noteCalc
    }

    /**
     * Position X 2D : graves à gauche, aiguës à droite.
     * On utilise (1 - normalized) pour que la note la plus grave soit à gauche (ambitusStartX)
     * et la plus aiguë à droite (ambitusStartX + ambitusWidth). Robustesse min/max inversés.
     */
    function calculateNoteX2D(midiNote, ambitusMin, ambitusMax, ambitusStartX, ambitusWidth) {
        var lo = Math.min(ambitusMin, ambitusMax)
        var hi = Math.max(ambitusMin, ambitusMax)
        if (hi <= lo) return ambitusStartX
        var normalized = (midiNote - lo) / (hi - lo)
        return ambitusStartX + (1 - normalized) * ambitusWidth
    }

    /** Délègue au calculateur commun (même portée, clé, etc.). */
    function calculateNoteY(offsetNote, lineSpacing, clef) {
        return _noteCalc.calculateNoteYPosition(offsetNote, lineSpacing, clef)
    }

    /** Délègue au calculateur commun. */
    function isNaturalNote(midiNote) {
        return _noteCalc.isNaturalNote(midiNote)
    }
}
