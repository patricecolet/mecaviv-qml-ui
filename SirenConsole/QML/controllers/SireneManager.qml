import QtQuick 2.15

QtObject {
    id: sireneManager
    
    // === PROPRIÉTÉS ===
    
    // Mapping des sirènes : {sireneId: pupitreId}
    property var sireneOwnership: ({})
    
    // Sirènes utilisées par le séquenceur externe
    property var sequencerSireneList: []
    
    // Sirènes disponibles pour les pupitres
    property var availableSireneList: []
    
    // === SIGNALS ===
    
    signal ownershipChanged(string sireneId, string oldPupitreId, string newPupitreId)
    signal sequencerChanged(var sireneList)
    signal errorOccurred(string error)
    
    // === INITIALISATION ===
    
    Component.onCompleted: {
        console.log("🎺 SireneManager initialisé")
        initializeAvailableSirenes()
    }
    
    function initializeAvailableSirenes() {
        // Initialiser la liste des sirènes disponibles (S1 à S7)
        availableSireneList = []
        for (var i = 1; i <= 7; i++) {
            availableSireneList.push(i)
        }
        console.log("🎺 Sirènes disponibles:", availableSireneList)
    }
    
    // === GESTION DE LA PROPRIÉTÉ DES SIRÈNES ===
    
    // Vérifier si une sirène peut être assignée à un pupitre
    function canAssignSirene(sireneId, pupitreId) {
        // Vérifier si la sirène est utilisée par le séquenceur
        if (sequencerSireneList.indexOf(sireneId) !== -1) {
            console.log("🚫 Sirène", sireneId, "utilisée par le séquenceur")
            return false
        }
        
        // Vérifier si la sirène est déjà assignée à un autre pupitre
        var currentOwner = sireneOwnership[sireneId]
        if (currentOwner && currentOwner !== pupitreId) {
            console.log("🚫 Sirène", sireneId, "déjà assignée à pupitre", currentOwner)
            return false
        }
        
        return true
    }
    
    // Assigner une sirène à un pupitre
    function assignSirene(sireneId, pupitreId) {
        if (!canAssignSirene(sireneId, pupitreId)) {
            errorOccurred("Impossible d'assigner la sirène " + sireneId + " au pupitre " + pupitreId)
            return false
        }
        
        var oldOwner = sireneOwnership[sireneId]
        sireneOwnership[sireneId] = pupitreId
        
        console.log("✅ Sirène", sireneId, "assignée au pupitre", pupitreId)
        ownershipChanged(sireneId, oldOwner, pupitreId)
        
        return true
    }
    
    // Désassigner une sirène d'un pupitre
    function unassignSirene(sireneId, pupitreId) {
        var currentOwner = sireneOwnership[sireneId]
        if (currentOwner === pupitreId) {
            delete sireneOwnership[sireneId]
            console.log("❌ Sirène", sireneId, "désassignée du pupitre", pupitreId)
            ownershipChanged(sireneId, pupitreId, "")
            return true
        }
        return false
    }
    
    // Obtenir le propriétaire actuel d'une sirène
    function getSireneOwner(sireneId) {
        return sireneOwnership[sireneId] || ""
    }
    
    // Obtenir toutes les sirènes assignées à un pupitre
    function getPupitreSirenes(pupitreId) {
        var assignedSirenes = []
        for (var sireneId in sireneOwnership) {
            if (sireneOwnership[sireneId] === pupitreId) {
                assignedSirenes.push(parseInt(sireneId))
            }
        }
        return assignedSirenes.sort()
    }
    
    // === GESTION DU SÉQUENCEUR EXTERNE ===
    
    // Définir les sirènes utilisées par le séquenceur
    function setSequencerSirenes(sirenes) {
        sequencerSireneList = sirenes || []
        console.log("🎵 Sirènes du séquenceur:", sequencerSireneList)
        sequencerChanged(sequencerSireneList)
        
        // Vérifier les conflits avec les pupitres
        checkConflictsWithSequencer()
    }
    
    // Vérifier les conflits avec le séquenceur
    function checkConflictsWithSequencer() {
        for (var i = 0; i < sequencerSireneList.length; i++) {
            var sireneId = sequencerSireneList[i]
            var owner = getSireneOwner(sireneId)
            if (owner) {
                console.log("⚠️ Conflit détecté: Sirène", sireneId, "utilisée par pupitre", owner, "et séquenceur")
                // Désassigner automatiquement du pupitre
                unassignSirene(sireneId, owner)
            }
        }
    }
    
    // === ÉTAT DES SIRÈNES ===
    
    // Obtenir l'état d'une sirène (available, assigned, sequencer)
    function getSireneStatus(sireneId) {
        if (sequencerSireneList.indexOf(sireneId) !== -1) {
            return "sequencer"
        }
        if (sireneOwnership[sireneId]) {
            return "assigned"
        }
        return "available"
    }
    
    // Obtenir la couleur d'affichage pour une sirène
    function getSireneColor(sireneId) {
        var status = getSireneStatus(sireneId)
        switch (status) {
            case "sequencer": return "#ff4444" // Rouge pour séquenceur
            case "assigned": return "#4a90e2"  // Bleu pour assignée
            default: return "#666666"          // Gris pour disponible
        }
    }
    
    // === SYNCHRONISATION AVEC LES PUPITRES ===
    
    // Synchroniser les sirènes assignées avec un pupitre
    function syncPupitreSirenes(pupitreId, requestedSirenes) {
        var currentSirenes = getPupitreSirenes(pupitreId)
        
        // Désassigner les sirènes qui ne sont plus demandées
        for (var i = 0; i < currentSirenes.length; i++) {
            var sireneId = currentSirenes[i]
            if (requestedSirenes.indexOf(sireneId) === -1) {
                unassignSirene(sireneId, pupitreId)
            }
        }
        
        // Assigner les nouvelles sirènes
        for (var j = 0; j < requestedSirenes.length; j++) {
            var newSireneId = requestedSirenes[j]
            if (currentSirenes.indexOf(newSireneId) === -1) {
                if (!assignSirene(newSireneId, pupitreId)) {
                    console.log("⚠️ Impossible d'assigner la sirène", newSireneId, "au pupitre", pupitreId)
                }
            }
        }
        
        return getPupitreSirenes(pupitreId)
    }
}
