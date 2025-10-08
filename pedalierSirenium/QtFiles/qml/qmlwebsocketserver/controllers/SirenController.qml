import QtQuick

Item {
    id: root
    
    // Propriétés publiques
    property var webSocketController
    property var beatController  // Référence au BeatController
    property var sirenNodes: []
    property var logger
    
    // Nouvelle fonction pour traiter directement les données des voix
    function processVoices(voices) {
        if (!voices || !Array.isArray(voices)) return;
        
        // Utiliser un flag pour indiquer qu'une mise à jour massive est en cours
        let updatingStates = true;
        
        // Traitement des voix
        voices.forEach(voice => {
            if (voice.hasOwnProperty("channel")) {
                let siren = getSirenById(voice.channel);
                if (siren) {
                    // Stocker l'état de l'animation actuelle
                    let wasAnimating = siren.isAnimating;
                    
                    // Appliquer les changements d'état
                    if (voice.hasOwnProperty("enable")) {
                        setCurrentSiren(voice.channel, voice.enable === 1);
                    }
                    
                    if (voice.hasOwnProperty("pedal")) {
                        siren.pedalActive = (voice.pedal === 1);
                    }
                    
                    // Restaurer l'état d'animation si nécessaire
                    if (wasAnimating && !siren.isAnimating) {
                        siren.restoreAnimation();
                    }
                }
            }
        });
        
        updatingStates = false;
    }

    function getSirenById(id) {
        for (let i = 0; i < sirenNodes.length; i++) {
            if (sirenNodes[i].sphereId === id) {
                return sirenNodes[i];
            }
        }
        return null;
    }
    
    function setActiveSiren(sirenId, active) {
        let siren = getSirenById(sirenId);
        if (siren) {
            siren.setActive(active);
        }
    }
    
    function setCurrentSiren(sirenId, current) {
        let siren = getSirenById(sirenId);
        if (siren) {
            siren.setCurrent(current);
            siren.setActive(current);
        }
    }
    
    function registerSiren(siren) {
        sirenNodes.push(siren);
    }
    
    // Transformer cette fonction en proxy qui appelle BeatController
    function resetSegmentAnimation(sirenId) {
        if (!beatController) {
            if (logger) logger.error("ANIMATION", "SirenController: beatController n'est pas défini");
            return;
        }
        beatController.resetSegmentAnimation(sirenId);
    }
    
    // Fonction proxy qui appelle BeatController
    function ensureSegmentAnimationContinues(sirenId) {
        if (!beatController) {
            if (logger) logger.error("ANIMATION", "SirenController: beatController n'est pas défini");
            return;
        }
        beatController.ensureSegmentAnimationContinues(sirenId);
    }
    
    // Ajouter cette fonction proxy pour vérifier si une animation existe
    function hasSegmentAnimation(sirenId) {
        if (!beatController) {
            if (logger) logger.error("ANIMATION", "SirenController: beatController n'est pas défini");
            return false;
        }
        return beatController.hasSegmentAnimation(sirenId);
    }
    
    // Ajouter cette fonction proxy pour arrêter une animation
    function stopSegmentAnimation(sirenId) {
        if (!beatController) {
            if (logger) logger.error("ANIMATION", "SirenController: beatController n'est pas défini");
            return;
        }
        beatController.stopSegmentAnimation(sirenId);
    }
}
