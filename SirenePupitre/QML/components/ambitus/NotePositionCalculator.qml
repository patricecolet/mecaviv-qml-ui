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
    
    // Fonction pour obtenir la position diatonique d'une note MIDI
    // Utilise la gamme diatonique (7 notes) plutôt que chromatique (12 notes)
    function getDiatonicPosition(midiNote) {
        var noteClass = Math.floor(midiNote) % 12  // 0-11
        var octave = Math.floor(Math.floor(midiNote) / 12)
        
        // Trouver la note naturelle la plus proche
        // Les dièses/bémols partagent la position Y de leur note naturelle voisine
        var diatonicNote = 0
        if (noteClass === 0 || noteClass === 1) diatonicNote = 0      // Do / Do#
        else if (noteClass === 2 || noteClass === 3) diatonicNote = 1 // Ré / Ré#
        else if (noteClass === 4) diatonicNote = 2                    // Mi
        else if (noteClass === 5 || noteClass === 6) diatonicNote = 3 // Fa / Fa#
        else if (noteClass === 7 || noteClass === 8) diatonicNote = 4 // Sol / Sol#
        else if (noteClass === 9 || noteClass === 10) diatonicNote = 5 // La / La#
        else if (noteClass === 11) diatonicNote = 6                   // Si
        
        // Position diatonique totale = (octave * 7) + position dans l'octave
        return octave * 7 + diatonicNote
    }
    
    // Fonction pour calculer la position Y d'une note sur la portée
    // Basée sur la position diatonique pour un espacement correct
    function calculateNoteYPosition(midiNote, lineSpacing, clef) {
        var diatonicPos = getDiatonicPosition(midiNote)
        
        // Notes de référence et leurs positions diatoniques
        var referenceMidi, referenceDiatonic, referenceY
        
        if (clef === "treble") {
            // Clé de Sol : Sol4 (MIDI 67) est sur la 2ème ligne (Y = -1)
            referenceMidi = 67        // Sol4
            referenceDiatonic = getDiatonicPosition(67)
            referenceY = -1           // 2ème ligne
        } else {  // bass
            // Clé de Fa : Fa3 (MIDI 53) est sur la 4ème ligne (Y = +1)
            referenceMidi = 53        // Fa3
            referenceDiatonic = getDiatonicPosition(53)
            referenceY = 1            // 4ème ligne
        }
        
        // Différence de positions diatoniques
        var diatonicDiff = diatonicPos - referenceDiatonic
        
        // Chaque position diatonique = 0.5 * lineSpacing (une ligne ou un interligne)
        return (referenceY + diatonicDiff * 0.5) * lineSpacing
    }
    
    // Fonction pour vérifier si une note est naturelle
    function isNaturalNote(midiNote) {
        var noteIndex = Math.floor(midiNote) % 12
        return noteIndex === 0 || noteIndex === 2 || noteIndex === 4 || 
               noteIndex === 5 || noteIndex === 7 || noteIndex === 9 || 
               noteIndex === 11
    }
}
