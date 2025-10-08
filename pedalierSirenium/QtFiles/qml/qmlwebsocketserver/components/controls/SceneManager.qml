import QtQuick
import QtQuick.Controls

Rectangle {
    id: sceneManager
    width: 600
    height: 400
    color: "#222"
    radius: 12
    border.color: "#444"
    border.width: 2
    
    property var logger
    property var webSocketController
    property int currentPage: 1
    property int totalPages: 8
    property int currentScene: -1
    onCurrentSceneChanged: {
        if (logger) {
            logger.info("SCENES", "🎯 CurrentScene changé:", currentScene)
        }
    }
    property var scenes: ({}) // Stockage des scènes par ID global
    property var scenesByPage: ({}) // Cache des scènes par page pour performance
    property int scenesVersion: 0 // Pour forcer la mise à jour des boutons
    property int currentPageVersion: 0 // Pour forcer la mise à jour quand currentPage change
    
    signal sceneSelected(int sceneId, string sceneName)
    signal pageChanged(int newPage)
    signal scenesUpdated()
    
    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // Navigation entre pages
        SceneNavigation {
            logger: sceneManager.logger
            currentPage: sceneManager.currentPage
            totalPages: sceneManager.totalPages
            
            onPageChanged: function(newPage) {
                changePage(newPage)
            }
        }
        
        // Grille des scènes
        SceneGrid {
            logger: sceneManager.logger
            webSocketController: sceneManager.webSocketController
            currentPage: sceneManager.currentPage
            currentScene: sceneManager.currentScene
            scenes: sceneManager.scenes
            scenesVersion: sceneManager.scenesVersion
            currentPageVersion: sceneManager.currentPageVersion
            sceneSaveDialog: sceneSaveDialog
            
            onSceneSelected: function(sceneId, sceneName) {
                sceneManager.sceneSelected(sceneId, sceneName)
            }
        }
        
        // Informations de la scène courante
        SceneInfo {
            currentScene: sceneManager.currentScene
            
            function getSceneName(sceneId) {
                return sceneManager.getSceneName(sceneId)
            }
        }
    }
    
    // Dialogue de sauvegarde
    SceneSaveDialog {
        id: sceneSaveDialog
        anchors.centerIn: parent
        logger: sceneManager.logger
        webSocketController: sceneManager.webSocketController
        mainWindow: window
        
        onSceneSaved: function(sceneName, sceneId) {
            // SUPPRIMER l'ajout immédiat - attendre la confirmation serveur
            // addScene(sceneId, sceneName)  // SUPPRIMÉ
            
            if (logger) {
                logger.info("SCENES", "📤 Demande de sauvegarde envoyée:", sceneName, "ID:", sceneId)
            }
            
            // Optionnel : Feedback visuel pendant l'attente
            showSavingFeedback(sceneId, sceneName)
        }
        
        // Nouvelle fonction pour feedback pendant l'attente
        function showSavingFeedback(sceneId, sceneName) {
            // Afficher un indicateur "En cours de sauvegarde..."
            if (logger) {
                logger.info("SCENES", "⏳ Sauvegarde en cours:", sceneName)
            }
        }
    }
    
    // Fonctions principales
    function changePage(newPage) {
        if (newPage >= 1 && newPage <= totalPages) {
            currentPage = newPage
            currentPageVersion++ // Forcer la mise à jour des boutons
            pageChanged(newPage)
            
            if (logger) {
                logger.info("SCENES", "📄 Changement page:", newPage)
            }
            
            // Informer le serveur du changement de page
            if (webSocketController) {
                webSocketController.sendMessage({
                    device: "LOOPER_SCENES",
                    action: "changePage", 
                    page: newPage
                })
            }
        }
    }
    
    function addScene(sceneId, sceneName) {
        // Calculer la page à partir de l'ID global
        let page = Math.floor((sceneId - 1) / 8) + 1
        
        scenes[sceneId] = {
            id: sceneId,
            name: sceneName,
            page: page,  // ← AJOUTER CETTE LIGNE
            created: new Date()
        }
        
        if (logger) {
            logger.info("SCENES", "➕ Scène ajoutée:", sceneId, sceneName, "page:", page)
        }
        
        // Forcer la mise à jour de l'interface
        scenesVersion++ // Incrémenter pour forcer la mise à jour
        scenesUpdated()
    }
    
    function removeScene(sceneId) {
        delete scenes[sceneId]
        if (currentScene === sceneId) {
            currentScene = -1
        }
    }
    
    function hasScene(sceneId) {
        if (!scenes.hasOwnProperty(sceneId)) {
            return false
        }
        // Vérifier que la scène appartient à la page courante
        let scenePage = scenes[sceneId].page
        return scenePage === currentPage
    }
    
    function getSceneName(sceneId) {
        return hasScene(sceneId) ? scenes[sceneId].name : "Vide"
    }
    
    function loadScenesFromServer(scenesList) {
        if (logger) {
            logger.info("SCENES", "📥 Chargement de", scenesList.length, "scènes depuis le serveur")
            logger.info("SCENES", "📋 Données reçues:", JSON.stringify(scenesList))
            logger.info("SCENES", " CurrentScene avant chargement:", currentScene)
        }
        
        scenes = {}
        scenesByPage = {} // Clear cache
        
        scenesList.forEach(scene => {
            // Utiliser globalSceneId comme clé
            let sceneId = scene.globalSceneId || scene.id
            let sceneName = scene.sceneName || scene.name
            let page = scene.page
            
            scenes[sceneId] = {
                id: sceneId,
                name: sceneName,
                page: page,
                sceneId: scene.sceneId,
                globalSceneId: scene.globalSceneId
            }
            
            // Pré-calculer par page pour performance
            if (!scenesByPage[page]) {
                scenesByPage[page] = {}
            }
            scenesByPage[page][sceneId] = scenes[sceneId]
            
            if (logger) {
                logger.info("SCENES", "➕ Scène ajoutée:", sceneId, sceneName, "page:", page)
            }
        })
        
        // Mettre à jour currentScene depuis les données du serveur
        if (scenesList.currentScene !== undefined) {
            currentScene = scenesList.currentScene
            if (logger) {
                logger.info("SCENES", " CurrentScene mis à jour depuis serveur:", currentScene)
            }
        }
        
        if (logger) {
            logger.info("SCENES", "✅ Scènes chargées:", Object.keys(scenes))
            logger.info("SCENES", "📊 Cache par page:", Object.keys(scenesByPage))
            logger.info("SCENES", " CurrentScene après chargement:", currentScene)
        }
        
        // Forcer la mise à jour de l'interface
        scenesVersion++ // Incrémenter pour forcer la mise à jour
        scenesUpdated()
    }
    
    // Raccourcis clavier pour navigation
    Keys.onPressed: function(event) {
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
            let pedalPos = event.key - Qt.Key_0
            let globalId = (currentPage - 1) * 8 + pedalPos
            selectScene(globalId)
            event.accepted = true
        } else if (event.key === Qt.Key_Left && currentPage > 1) {
            changePage(currentPage - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right && currentPage < totalPages) {
            changePage(currentPage + 1)
            event.accepted = true
        }
    }

    // Nouvelles fonctions pour le feedback
    function showSaveSuccess(sceneId, sceneName) {
        if (logger) {
            logger.info("SCENES", "🎉 Sauvegarde réussie:", sceneName)
        }
        // Optionnel : Animation de succès, notification temporaire, etc.
    }
    
    function showSaveError(sceneId, errorMessage) {
        if (logger) {
            logger.error("SCENES", "💥 Erreur de sauvegarde pour scène", sceneId, ":", errorMessage)
        }
        // Optionnel : Afficher popup d'erreur, réessayer, etc.
    }
} 