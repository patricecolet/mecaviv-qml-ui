import QtQuick 2.15
import "../utils"

QtObject {
    id: root
    
    // Lien vers le ConfigController
    property var configController: null
    
    // Données d'entrée
    property real midiNote: 60.0
    /** Note dans l’ambitus (continue). L’arrondi mode fretté s’applique seulement à freq/rpm/noteName. */
    property real clampedNote: 60.0
    property int velocity: 127  // 0-127 (volant 0x03, ou jauge manuelle si pas de pad)
    
    // Données calculées
    property int frequency: 0
    property int rpm: 0
    property string noteName: ""
    property string sirenName: ""
    
    // Vraies valeurs (non limitées)
    property int trueFrequency: 0
    property int trueRpm: 0
    property string trueNoteName: ""
    
    // Utils
    property MusicUtils musicUtils: MusicUtils {}
    
    // Mise à jour quand la note change
    onMidiNoteChanged: calculate()
    
    // Connexion au configController
    onConfigControllerChanged: {
        if (configController) {
            configController.ready.connect(function() {
                calculate()
            })
        }
    }
    
    function calculate() {
        if (!configController || !configController.primarySiren) {
            clampedNote = midiNote
            return
        }
        
        var siren = configController.primarySiren
        sirenName = siren.name
        
        // Limiter la note selon le mode et l'ambitus (curseur portée, microtonal : toujours cette valeur)
        var minNote = configController.getMinNote()
        var maxNote = configController.getMaxNote()
        clampedNote = Math.max(minNote, Math.min(midiNote, maxNote))
        
        // Mode fretté : quantifier seulement Hz / RPM / nom (pas la même valeur que le curseur)
        var ids = configController.getValueAtPath(["sirenConfig", "currentSirens"], [1]) 
        var currentSirenId = ids.length > 0 ? ids[0] : 1
        var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
            return Number(siren.id) === Number(currentSirenId)
        })?.frettedMode?.enabled || false
        
        var noteForLimitedDisplay = frettedModeEnabled ? Math.round(clampedNote) : clampedNote
        
        // Logs désactivés pour performance
        
        // Calculer les vraies valeurs (non limitées)
        var trueFreq = musicUtils.midiToFrequency(midiNote, siren.transposition)
        trueFrequency = musicUtils.formatFrequency(trueFreq)
        var trueCalculatedRpm = musicUtils.frequencyToRPM(trueFreq, siren.outputs)
        trueRpm = musicUtils.formatRPM(trueCalculatedRpm)
        trueNoteName = musicUtils.midiToNoteName(midiNote)
        
        // Calculer les valeurs limitées (pour l'ambitus)
        var freq = musicUtils.midiToFrequency(noteForLimitedDisplay, siren.transposition)
        frequency = musicUtils.formatFrequency(freq)
        var calculatedRpm = musicUtils.frequencyToRPM(freq, siren.outputs)
        rpm = musicUtils.formatRPM(calculatedRpm)
        noteName = musicUtils.midiToNoteName(noteForLimitedDisplay)
        
        // Log désactivé pour performance
    }
    
    // Méthode pour obtenir les infos actuelles (debug)
    function getCurrentData() {
        return {
            sirenName: sirenName,
            midiNote: midiNote,
            clampedNote: clampedNote,
            frequency: frequency,
            rpm: rpm,
            noteName: noteName,
            configInfo: configController ? configController.getCurrentSirenInfo() : null
        }
    }
}
