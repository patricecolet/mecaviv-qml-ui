import QtQuick 2.15
import "../../../shared/qml/common"

QtObject {
    id: root
    
    // Lien vers le ConfigController
    property var configController: null
    
    // Données d'entrée
    property real midiNote: 60.0
    property real clampedNote: 60.0
    
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
        if (!configController || !configController.currentSiren) {
            return
        }
        
        var siren = configController.currentSiren
        sirenName = siren.name
        
        // Limiter la note selon le mode et l'ambitus
        var minNote = configController.getMinNote()
        var maxNote = configController.getMaxNote()
        clampedNote = Math.max(minNote, Math.min(midiNote, maxNote))
        
        // Appliquer le mode fretté si activé pour la sirène actuelle
        var currentSirenId = configController.getValueAtPath(["sirenConfig", "currentSiren"], "1")
        var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
            return siren.id === currentSirenId
        })?.frettedMode?.enabled || false
        
        if (frettedModeEnabled) {
            var frettedNote = Math.round(clampedNote)
            // Log désactivé pour performance
            clampedNote = frettedNote
        }
        
        // Logs désactivés pour performance
        
        // Calculer les vraies valeurs (non limitées)
        var trueFreq = musicUtils.midiToFrequency(midiNote, siren.transposition)
        trueFrequency = musicUtils.formatFrequency(trueFreq)
        var trueCalculatedRpm = musicUtils.frequencyToRPM(trueFreq, siren.outputs)
        trueRpm = musicUtils.formatRPM(trueCalculatedRpm)
        trueNoteName = musicUtils.midiToNoteName(midiNote)
        
        // Calculer les valeurs limitées (pour l'ambitus)
        var freq = musicUtils.midiToFrequency(clampedNote, siren.transposition)
        frequency = musicUtils.formatFrequency(freq)
        var calculatedRpm = musicUtils.frequencyToRPM(freq, siren.outputs)
        rpm = musicUtils.formatRPM(calculatedRpm)
        noteName = musicUtils.midiToNoteName(clampedNote)
        
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
