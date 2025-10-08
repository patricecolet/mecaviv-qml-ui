import QtQuick

Item {
    id: root
    
    property var logger  // Logger passé depuis main
    
    // Propriétés inchangées
    property var sirenController
    property var webSocketController
    property int bpm: 120
    property int globalLoopSize: 16
    property int globalLoopPosition: 0
    property int mainLoopSirenId: -1
    property var segmentAnimations: ({})
    property int currentBar: 1
    
    onBpmChanged: {
        updateAllAnimationSpeeds();
    }
    
    // Nouvelle fonction pour traiter directement les données des loops et du clock
    function processLoopAndClock(loops, clock) {
        // Traiter le clock s'il est présent
        if (clock) {
            // Mettre à jour le BPM
            if (clock.hasOwnProperty("bpm")) {
                if (clock.bpm !== bpm) {
                    if (logger) logger.info("CLOCK", "Nouveau BPM:", clock.bpm);
                }
                bpm = clock.bpm;
            }
            
            // Mettre à jour le numéro de mesure global (pour référence)
            if (clock.hasOwnProperty("bar")) {
                if (logger) logger.debug("CLOCK", "Changement de mesure (bar):", clock.bar);
                currentBar = clock.bar;
            }
            
            // Traiter les pulsations de beat pour les sirènes actives
            if (clock.hasOwnProperty("beat")) {
                if (logger) logger.debug("CLOCK", "Beat reçu:", clock.beat);
                for (let i = 0; i < sirenController.sirenNodes.length; i++) {
                    let siren = sirenController.sirenNodes[i];
                    if (siren.isCurrent) {
                        let isFirstBeat = clock.beat === 1;
                        let beatColor = isFirstBeat ? "red" : "lime";
                        siren.pulseSphere(isFirstBeat, 60000 / bpm / 2);
                    }
                }
            }
        }
        
        // Traiter les loops si elles sont présentes
        if (loops) {
            if (logger) logger.debug("ANIMATION", "🔄 processLoopAndClock reçu loops:", JSON.stringify(loops));
            
            // Mettre à jour la loop principale
            if (loops.hasOwnProperty("main_loop")) {
                mainLoopSirenId = loops.main_loop;
            }
            
            // Traiter les états des sirènes
            if (loops.hasOwnProperty("states") && Array.isArray(loops.states)) {
                // Traiter les boucles et leurs états
                loops.states.forEach(state => {
                    if (logger) logger.debug("ANIMATION", "🎯 Traitement état:", JSON.stringify(state));
                    let siren = sirenController.getSirenById(state.siren_id);
                    if (siren) {
                        if (logger) logger.debug("ANIMATION", "✅ Sirène trouvée ID:", state.siren_id, "transport:", state.transport);
                        // Mettre à jour la mesure actuelle pour cette boucle spécifique
                if (state.hasOwnProperty("current_bar")) {
            if (root.logger) {
                root.logger.debug("ANIMATION", "Bar update - Sirène", state.siren_id, 
                                 "mode:", state.transport, "valeur:", state.current_bar);
            }
                    siren.currentBar = state.current_bar;
                }
                        
                        let animationId = "segmentAnimation_" + state.siren_id;
                        
                        // Stocker l'état actuel d'animation
                        let wasAnimating = siren.isAnimating;
                        
                        // Mettre à jour le loopSize si présent
                        if (state.hasOwnProperty("loopSize")) {
                            siren.loopSize = state.loopSize;
                        }
                        
                        // Traitement de l'état de transport
                        if (state.hasOwnProperty("transport")) {
                            switch(state.transport) {
                                case "playing":
                                    if (!segmentAnimations[animationId]) {
                                        // Utiliser l'animation existante dans SirenColumn au lieu d'en créer une nouvelle
                                        let animation = siren.getPieChartAnimation();
                                        if (animation) {
                                            segmentAnimations[animationId] = animation;
                                            animation.start();
                                            siren.isAnimating = true;
                                            if (logger) logger.debug("ANIMATION", "Animation démarrée pour sirène", state.siren_id);
                                        }
                                    } else if (!wasAnimating) {
                                        segmentAnimations[animationId].start();
                                        siren.isAnimating = true;
                                        if (logger) logger.debug("ANIMATION", "Animation redémarrée pour sirène", state.siren_id);
                                    }
                                    break;
                                    
                                case "recording":
                                    if (logger) {
                                        logger.info("RECORDING", "Sirène", state.siren_id,
                                                    "| Mesure en cours:", state.current_bar || "?",
                                                    "| Longueur de la boucle principale:", state.loopSize || "?");
                                    }
                                    // LOG SPÉCIFIQUE POUR RECORDING
                                    if (logger) {
                                        logger.info("RECORDING", "Sirène", state.siren_id, 
                                                    "| Bar:", state.current_bar || "?",
                                                    "| Size:", state.loopSize || "?");
                                    }
                                    
                                    // Déclencher un flash rouge de l'anneau (recording)
                                    if (!segmentAnimations[animationId]) {
                                        let animation = siren.getPieChartAnimation();
                                        if (animation) {
                                            segmentAnimations[animationId] = animation;
                                        }
                                    }
                                    if (segmentAnimations[animationId] && segmentAnimations[animationId].flashRecording) {
                                        segmentAnimations[animationId].flashRecording();
                                    }
                                    siren.isAnimating = false;
                                    break;

                                case "stopped":
                                    if (logger) {
                                        logger.info("ANIMATION", "Boucle mise en pause pour sirène", state.siren_id);
                                    }
                                    if (segmentAnimations[animationId]) {
                                        segmentAnimations[animationId].stop();
                                        if (logger) logger.debug("ANIMATION", "Animation pausée (stopped) pour sirène", state.siren_id);
                                    }
                                    siren.isAnimating = false;
                                    break;
                                    
                                case "cleared":
                                    if (logger) {
                                        logger.info("ANIMATION", "🗑️ Boucle effacée pour sirène", state.siren_id);
                                    }
                                    // Supprimer complètement l'animation
                                    if (segmentAnimations[animationId]) {
                                        segmentAnimations[animationId].stop();
                                        segmentAnimations[animationId].destroy();
                                        delete segmentAnimations[animationId];
                                        if (logger) logger.debug("ANIMATION", "Animation supprimée (cleared) pour sirène", state.siren_id);
                                    }
                                    // Remise à zéro de l'anneau: rien à colorer, l'animation est arrêtée
    // 🔧 RÉINITIALISER LE COMPTEUR DE RÉVOLUTIONS
                                    siren.setRevolutionCount(0);
                                    if (logger) logger.info("ANIMATION", "🔄 Compteur de révolutions réinitialisé à 0 pour sirène", state.siren_id);
    
                                    siren.isAnimating = false;
                                    if (logger) logger.debug("ANIMATION", "✅ Sirène", state.siren_id, "isAnimating set to false");
                                    break;
                            }
                        }
                        
                        // Traitement des révolutions
                        if (state.transport === "playing" && state.hasOwnProperty("revolutions")) {
                            // Vérifier si le compteur de révolutions a changé
                            let previousRevCount = siren.revolutionCount || 0;
                            
                            if (state.revolutions > previousRevCount) {
                                if (logger) {
                                    logger.info("ANIMATION", "Nouvelle révolution pour sirène", state.siren_id);
                                }
                                
                                // Mettre à jour le compteur
                                siren.setRevolutionCount(state.revolutions);
                                
                                // Réinitialiser l'animation immédiatement 
                                if (segmentAnimations[animationId]) {
                                    segmentAnimations[animationId].resetAnimation();
                                    if (logger) logger.debug("ANIMATION", "Animation réinitialisée pour sirène", state.siren_id);
                                }
                            } else {
                                siren.setRevolutionCount(state.revolutions);
                            }
                        }
                        
                        // Mettre à jour la durée d'animation si elle a changé
                        if (state.hasOwnProperty("loopSize") && segmentAnimations[animationId]) {
                            let newDuration = siren.loopSize * (60000 / bpm) * 4;
                            segmentAnimations[animationId].updateDuration(newDuration);
                        }
                    }
                });
            }
        }
    }
    
    // Fonction utilitaire inchangée
    function animationInit(animationId) {
        if (segmentAnimations[animationId]) {
            let siren = segmentAnimations[animationId].siren;
            segmentAnimations[animationId].stop();
            segmentAnimations[animationId].destroy();
            delete segmentAnimations[animationId];
            if (siren) {
                siren.isAnimating = false;
            }
        }
    }
    
    // Fonction pour mettre à jour la vitesse de toutes les animations
    function updateAllAnimationSpeeds() {
        for (let animId in segmentAnimations) {
            if (segmentAnimations.hasOwnProperty(animId)) {
                let animation = segmentAnimations[animId];
                
                let sirenId = parseInt(animId.split("_")[1]);
                let siren = sirenController.getSirenById(sirenId);
                
                if (siren && animation) {
                    let newDuration = siren.loopSize * (60000 / bpm) * 4;
                    animation.updateDuration(newDuration);
                    
                    if (logger) logger.debug("ANIMATION", "Animation mise à jour pour sirène", sirenId,
                                "durée:", newDuration, "active:", siren.isAnimating);
                }
            }
        }
    }
    
    // Fonction pour mettre à jour la durée d'animation
    function updateAnimationDuration(sirenId) {
        let siren = sirenController.getSirenById(sirenId);
        if (!siren) return;
        
        let animationId = "segmentAnimation_" + sirenId;
        let animation = segmentAnimations[animationId];
        
        if (animation) {
            let beatsPerMeasure = 4;
            let newDuration = siren.loopSize * beatsPerMeasure * (60000 / bpm);
            
            if (logger) logger.debug("ANIMATION", "Mise à jour durée animation pour sirène", sirenId,
                       "loopSize:", siren.loopSize, 
                       "nouvelle durée:", newDuration, "ms");
            
            animation.updateDuration(newDuration);
        }
    }
    
    // Fonctions pour gérer les animations de segments
    function hasSegmentAnimation(sirenId) {
        let animationId = "segmentAnimation_" + sirenId;
        return segmentAnimations.hasOwnProperty(animationId) && 
               segmentAnimations[animationId] !== null && 
               segmentAnimations[animationId] !== undefined;
    }
    
    function resetSegmentAnimation(sirenId) {
        let animationId = "segmentAnimation_" + sirenId;
        if (logger) logger.debug("ANIMATION", "Tentative de réinitialisation de l'animation", animationId);
        
        let animation = segmentAnimations[animationId];
        let siren = sirenController.getSirenById(sirenId);
        
        if (animation && siren) {
            if (logger) logger.debug("ANIMATION", "Animation trouvée, réinitialisation");
            animation.stop();
            
            Qt.callLater(function() {
                animation.animationProgress = 0;
                animation.start();
                siren.isAnimating = true;
                if (logger) logger.debug("ANIMATION", "Animation redémarrée");
            });
        } else {
            if (logger) logger.debug("ANIMATION", "Création d'une nouvelle animation pour la sirène", sirenId);
            let animationComponent = Qt.createComponent("../components/monitoring/PieChartAnimation.qml");
            if (animationComponent.status === Component.Ready) {
                let loopDuration = siren.loopSize * (60000 / bpm) * 4;
                let animation = animationComponent.createObject(siren, {  // <- Créer sur la sirène, pas sur root
                    "siren": siren,
                    "segmentCount": siren.segmentCount,
                    "loopDuration": loopDuration,
                    "activeColor": "lime",
                    "inactiveColor": siren.inactiveColor
                });
                segmentAnimations[animationId] = animation;
                animation.start();
                siren.isAnimating = true;
            }
        }
    }
    
    function ensureSegmentAnimationContinues(sirenId) {
        let animationId = "segmentAnimation_" + sirenId;
        let animation = segmentAnimations[animationId];
        let siren = sirenController.getSirenById(sirenId);
        
        if (siren) {
            if (animation) {
                if (!animation.running) {
                    animation.start();
                    siren.isAnimating = true;
                    if (logger) logger.debug("ANIMATION", "Animation redémarrée pour sirène", sirenId);
                }
            } else {
                if (logger) logger.debug("ANIMATION", "Animation non trouvée pour sirène", sirenId, "- création d'une nouvelle");
                let animationComponent = Qt.createComponent("../components/monitoring/PieChartAnimation.qml");
                if (animationComponent.status === Component.Ready) {
                    let loopDuration = siren.loopSize * (60000 / bpm) * 4;
                    let animation = animationComponent.createObject(siren, {  // <- Créer sur la sirène, pas sur root
                        "siren": siren,
                        "segmentCount": siren.segmentCount,
                        "loopDuration": loopDuration,
                        "activeColor": "lime",
                        "inactiveColor": siren.inactiveColor
                    });
                    segmentAnimations[animationId] = animation;
                    animation.start();
                    siren.isAnimating = true;
                }
            }
        }
    }
    
    function stopSegmentAnimation(sirenId) {
        let animationId = "segmentAnimation_" + sirenId;
        let animation = segmentAnimations[animationId];
        let siren = sirenController.getSirenById(sirenId);
        
        if (animation && siren) {
            animation.stop();
            siren.isAnimating = false;
            if (logger) logger.debug("ANIMATION", "Animation arrêtée pour sirène", sirenId);
        }
    }
    
    // Fonction de synchronisation des animations
    function updateAllSegmentAnimationsPosition() {
        for (let i = 0; i < sirenController.sirenNodes.length; i++) {
            let siren = sirenController.sirenNodes[i];
            if (siren.isCurrent) {
                let relativePosition = (globalLoopPosition % siren.loopSize) / siren.loopSize;
                
                // Cette fonction n'existe plus dans le SirenController - à mettre à jour
                let animationId = "segmentAnimation_" + (i + 1);
                let animation = segmentAnimations[animationId];
                if (animation) {
                    animation.setPosition(relativePosition);
                }
            }
        }
    }
}
