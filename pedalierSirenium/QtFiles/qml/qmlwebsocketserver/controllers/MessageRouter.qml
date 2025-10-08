import QtQuick

QtObject {
    id: root
    
    property var logger  // Logger passé depuis main
    property var sirenController
    property var beatController  
    property var pedalConfigController
    property var tempoControl
    property var sceneManager  // Ajout du SceneManager
    property var _voiceStates: ({})
    
    // Router les batches
    function routeBatch(batchType, data) {
        if (logger) {
            if (batchType !== "voices" && batchType !== "clock" && batchType !== "loops" && batchType !== "presets") {
                logger.info("BATCH", "Batch reçu:", batchType, "avec", Object.keys(data).length, "éléments");
            }
            logger.debug("BATCH", "Traitement du batch:", batchType);
        }
        
        switch(batchType) {
            case "voices":
                // data est directement l'array des voices
                if (Array.isArray(data)) {
                    // Suppression du log DEBUG inutile
                    // Traiter chaque voice
                    data.forEach(voice => {
                        if (voice.channel && voice.hasOwnProperty('enable')) {
                            if (_voiceStates[voice.channel] !== voice.enable) {
                                if (logger) logger.info("VOICE", "Voix", voice.channel, voice.enable === 1 ? "activée" : "désactivée");
                                _voiceStates[voice.channel] = voice.enable;
                            }
                            if (logger) {
                                logger.trace("VOICE", "Channel", voice.channel, "enable:", voice.enable);
                            }
                            sirenController.setCurrentSiren(voice.channel, voice.enable === 1);
                            
                            if (voice.hasOwnProperty('pedal')) {
                                let siren = sirenController.getSirenById(voice.channel);
                                if (siren) {
                                    siren.pedalActive = (voice.pedal === 1);
                                }
                            }
                        }
                    });
                }
                break;
                
            case "clock":
                if (logger) {
                    logger.debug("CLOCK", "Update - BPM:", data.bpm, "Beat:", data.beat, "Bar:", data.bar);
                }
                // Appeler processLoopAndClock pour transmettre clock
                beatController.processLoopAndClock(null, data);
                // Mettre à jour le BPM
                if (data.bpm) {
                    beatController.bpm = data.bpm;
                    tempoControl.tempo = data.bpm;
                }
                
                // Traiter le beat
                if (data.hasOwnProperty('beat')) {
                    // Faire pulser les sirènes actives
                    for (let i = 1; i <= 7; i++) {
                        let siren = sirenController.getSirenById(i);
                        if (siren && siren.isCurrent) {
                            let isFirstBeat = data.beat === 1;
                            siren.pulseSphere(isFirstBeat, 60000 / beatController.bpm / 2);
                        }
                    }
                }
                
                // Mettre à jour la barre
                if (data.hasOwnProperty('bar')) {
                    beatController.currentBar = data.bar;
                }
                break;
                
            case "loops":
                beatController.processLoopAndClock(data, null);
                break;
                
            case "presets":
                if (data.pedals) {
                    if (logger) {
                        logger.info("PRESET", "Chargement des configurations de presets");
                    }
                    pedalConfigController.loadConfigs(data);
                }
                break;
            case "presetList":
                if (logger) {
                    logger.info("PRESET", "📋 Liste des presets reçue:", JSON.stringify(data));
                }
                pedalConfigController.availablePresets = data;
                break;
            case "currentPreset":
                if (logger) {
                    logger.info("PRESET", "🎯 Preset courant reçu:", JSON.stringify(data));
                }
                if (pedalConfigController.loadPreset(data)) {
                    if (logger) logger.info("PRESET", "✅ Preset courant chargé et interface mise à jour");
                } else {
                    if (logger) logger.warn("PRESET", "⚠️ Échec du chargement du preset courant");
                }
                break;
            case "knob":
                if (logger) {
                    logger.info("KNOB", "Batch knob reçu:", JSON.stringify(data));
                }
                break;
            case "router":
                if (logger) {
                    logger.info("ROUTER", "Batch router reçu:", JSON.stringify(data));
                }
                break;
            case "parser":
                if (logger) {
                    logger.info("PARSER", "Batch parser reçu:", JSON.stringify(data));
                }
                break;
            case "init":
                if (logger) {
                    logger.info("INIT", "Batch init reçu:", JSON.stringify(data));
                }
                break;
            case "monitoringData":
                if (logger) {
                    logger.info("MONITORING", "Batch monitoringData reçu:", JSON.stringify(data));
                }
                break;

            case "monitoringStatus":
                if (logger) {
                    logger.info("MONITORING", "Batch monitoringStatus reçu:", JSON.stringify(data));
                }
                break;
            case "scenesList":
                if (logger) {
                    logger.info("SCENES", "📋 Liste des scènes reçue:", JSON.stringify(data));
                }
                // Mettre à jour le SceneManager
                if (sceneManager) {
                    sceneManager.loadScenesFromServer(data);
                }
                break;
            case "sceneLoaded":
                if (logger) {
                    logger.info("SCENES", "🎵 Scène chargée:", JSON.stringify(data));
                    logger.info("SCENES", "🔍 Structure data:", Object.keys(data));
                }
                // Mettre à jour la scène active
                if (sceneManager) {
                    if (data.sceneId) {
                        sceneManager.currentScene = data.sceneId;
                        logger.info("SCENES", "✅ Scène active mise à jour:", data.sceneId);
                    } else if (data.id) {
                        sceneManager.currentScene = data.id;
                        logger.info("SCENES", "✅ Scène active mise à jour (id):", data.id);
                    } else {
                        logger.warn("SCENES", "⚠️ Pas de sceneId trouvé dans:", JSON.stringify(data));
                    }
                } else {
                    logger.warn("SCENES", "⚠️ SceneManager non disponible");
                }
                break;
            case "sceneSaved":
                if (logger) {
                    logger.info("SCENES", "💾 Scène sauvegardée:", JSON.stringify(data));
                    logger.info("SCENES", "🔍 Structure data:", Object.keys(data));
                }
                
                // Vérifier s'il y a une erreur
                if (data.error || data.status === "error") {
                    handleSceneSaveError(data)
                    break;
                }
                
                // Ajouter la scène sauvegardée (succès)
                if (sceneManager) {
                    let sceneId = data.sceneId || data.id || data.globalSceneId;
                    let sceneName = data.sceneName || data.name;
                    
                    if (sceneId && sceneName) {
                        sceneManager.addScene(sceneId, sceneName);
                        logger.info("SCENES", "✅ Scène ajoutée à l'interface:", sceneId, sceneName);
                        
                        // Feedback de succès
                        sceneManager.showSaveSuccess(sceneId, sceneName)
                    } else {
                        logger.warn("SCENES", "⚠️ Données manquantes pour ajouter la scène:", JSON.stringify(data));
                    }
                } else {
                    logger.warn("SCENES", "⚠️ SceneManager non disponible");
                }
                break;
                
            case "sceneError":
                handleSceneSaveError(data)
                break;
        }
    }
    
    // Router les messages de scènes
    function routeSceneMessage(data) {
        if (logger) {
            logger.info("SCENES", "🎭 Message de scène reçu:", JSON.stringify(data));
        }
        
        switch(data.action) {
            case "loadScene":
                if (logger) {
                    logger.info("SCENES", "🎵 Chargement de scène demandé:", data.sceneId);
                }
                // Mettre à jour la scène active
                if (sceneManager) {
                    sceneManager.currentScene = data.sceneId;
                    logger.info("SCENES", "✅ Scène active mise à jour:", data.sceneId);
                } else {
                    logger.warn("SCENES", "⚠️ SceneManager non disponible");
                }
                break;
                
            case "saveScene":
                if (logger) {
                    logger.info("SCENES", "💾 Sauvegarde de scène demandée:", data.sceneId);
                }
                // Traitement de la sauvegarde si nécessaire
                break;
                
            case "deleteScene":
                if (logger) {
                    logger.info("SCENES", "️ Suppression de scène demandée:", data.sceneId);
                }
                // Traitement de la suppression si nécessaire
                break;
                
            default:
                if (logger) {
                    logger.warn("SCENES", "⚠️ Action inconnue:", data.action);
                }
                break;
        }
    }
    
    // Pour compatibilité avec l'ancien système
    function routePathMessage(path, value) {
        if (logger) logger.debug("ROUTER", "📍 Route path:", JSON.stringify(path), "value:", value);
    }
    
    // Nouvelle fonction pour gérer les erreurs
    function handleSceneSaveError(errorData) {
        if (logger) {
            logger.error("SCENES", "❌ Erreur de sauvegarde:", JSON.stringify(errorData));
        }
        
        if (sceneManager) {
            let errorMessage = errorData.message || errorData.error || "Erreur inconnue";
            let sceneId = errorData.sceneId || errorData.id;
            
            sceneManager.showSaveError(sceneId, errorMessage)
        }
    }
}
