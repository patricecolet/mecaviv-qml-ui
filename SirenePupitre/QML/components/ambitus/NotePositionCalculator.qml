import QtQuick 2.15

QtObject {
    // Table des notes naturelles (MIDI % 12)
    readonly property var naturalNotes: ({
        0: 0,   // Do
        2: 1,   // Ré
        4: 2,   // Mi
        5: 3,   // Fa
        7: 4,   // Sol
        9: 5,   // La
        11: 6   // Si
    })
    
    // Fonction pour calculer la position X d'une note dans l'ambitus
    function calculateNoteXPosition(midiNote, ambitusMin, ambitusMax, staffPosX, staffWidth) {
        // Position normalisée entre 0 et 1
        var normalizedPosition = (midiNote - ambitusMin) / (ambitusMax - ambitusMin)
        
        // Position X réelle
        return staffPosX - staffWidth/2 + normalizedPosition * staffWidth
    }
    
    // Fonction pour calculer la position Y d'une note sur la portée
    function calculateNoteYPosition(midiNote, lineSpacing, clef) {
        // Notes de référence sur la première ligne (la plus basse)
        var firstLineNote
        var firstLinePosition
        
        if (clef === "treble") {
            firstLineNote = 60      // Do4 (troisième interligne)
            firstLinePosition = 0.5 // Troisième interligne
        } else {
            firstLineNote = 43      // Sol2 (première ligne)
            firstLinePosition = -2  // Première ligne
        }
        
        // Calculer la différence en demi-tons depuis la note de référence
        var semitoneDiff = midiNote - firstLineNote
        
        // Position Y: chaque demi-ton = 0.25 (alternance ligne/interligne)
        // Un demi-ton = 0.25 * lineSpacing (car 2 demi-tons = 0.5 * lineSpacing = une position)
        return (firstLinePosition + semitoneDiff * 0.25) * lineSpacing
    }
    

    
    // Fonction pour vérifier si une note est naturelle
    function isNaturalNote(midiNote) {
        var noteIndex = midiNote % 12
        return noteIndex === 0 || noteIndex === 2 || noteIndex === 4 || 
               noteIndex === 5 || noteIndex === 7 || noteIndex === 9 || 
               noteIndex === 11
    }
}
