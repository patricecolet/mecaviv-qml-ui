import QtQuick 2.15

QtObject {
    id: root
    
    // Table des noms de notes en français
    readonly property var noteNames: ["Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
    
    // Convertir une note MIDI en fréquence avec transposition
    function midiToFrequency(midiNote, transposition) {
        // transposition est en octaves
        var transposedNote = midiNote + (transposition * 12)
        // Formule : f = 440 * 2^((n-69)/12)
        return 440 * Math.pow(2, (transposedNote - 69) / 12)
    }
    
    // Convertir une fréquence en RPM selon le nombre de sorties
    function frequencyToRPM(frequency, outputs) {
        // RPM = (fréquence * 60) / nombre de sorties
        return (frequency * 60) / outputs
    }
    
    // Convertir une note MIDI en nom de note
    function midiToNoteName(midiNote) {
        var noteIndex = Math.round(midiNote) % 12
        var octave = Math.floor(Math.round(midiNote) / 12) - 1
        return noteNames[noteIndex] + octave
    }
    
    // Convertir une fréquence en note MIDI (inverse)
    function frequencyToMidi(frequency) {
        // n = 69 + 12 * log2(f/440)
        return 69 + 12 * Math.log2(frequency / 440)
    }
    
    // Formater la fréquence pour l'affichage (arrondie)
    function formatFrequency(frequency) {
        return Math.round(frequency)
    }
    
    // Formater les RPM pour l'affichage (arrondie)
    function formatRPM(rpm) {
        return Math.round(rpm)
    }
    
    // Obtenir la couleur selon la hauteur de note (optionnel)
    function getNoteColor(midiNote) {
        // Dégradé du grave (rouge) vers l'aigu (bleu)
        var normalized = (midiNote - 24) / (108 - 24) // Normaliser entre 0 et 1
        normalized = Math.max(0, Math.min(1, normalized))
        
        var r = 1.0 - normalized
        var b = normalized
        var g = 0.5
        
        return Qt.rgba(r, g, b, 1.0)
    }
    
    // Vérifier si une note est dans l'ambitus
    function isNoteInRange(midiNote, min, max) {
        return midiNote >= min && midiNote <= max
    }
}
