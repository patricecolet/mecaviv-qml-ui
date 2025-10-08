import QtQuick
import QtQuick.Controls

Column {
    id: sceneGrid
    width: parent.width
    spacing: 8
    
    property var logger
    property var webSocketController
    property int currentPage: 1
    property int currentScene: -1  // ← Remettre cette propriété
    property var scenes: ({})
    property int scenesVersion: 0
    property var sceneSaveDialog
    property int currentPageVersion: 0 // Pour forcer la mise à jour quand currentPage change
    property int currentSceneVersion: 0 // Pour forcer la mise à jour quand currentScene change
    
    signal sceneSelected(int sceneId, string sceneName)
    
    // Fonctions utilitaires
    function hasScene(sceneId) {
        if (!scenes.hasOwnProperty(sceneId)) {
            return false
        }
        // Vérifier que la scène appartient à la page courante
        let scenePage = scenes[sceneId].page
        return scenePage === currentPage
    }
    
    function getSceneName(sceneId) {
        if (hasScene(sceneId)) {
            return scenes[sceneId].name
        }
        return "Vide"
    }
    
    function selectScene(sceneId) {
        if (hasScene(sceneId)) {
            let sceneName = getSceneName(sceneId)
            sceneSelected(sceneId, sceneName)
            
            if (logger) {
                logger.info("SCENES", "🎯 Scène sélectionnée:", sceneName, "ID:", sceneId)
            }
            
            // Envoyer sélection au serveur
            if (webSocketController) {
                webSocketController.sendMessage({
                    device: "LOOPER_SCENES",
                    action: "selectScene",
                    sceneId: sceneId,
                    sceneName: sceneName,
                    page: currentPage
                })
            }
        }
    }
    
    // Première rangée (positions 5-8)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        
        Repeater {
            model: 4
            delegate: SceneButton {
                pedalPosition: index + 5
                globalSceneId: (sceneGrid.currentPage - 1) * 8 + (index + 5)
                sceneName: getSceneName(globalSceneId)
                isEmpty: !hasScene(globalSceneId)
                currentScene: sceneGrid.currentScene
                
                // Miroir des versions pour déclencher les mises à jour
                property int scenesVersionMirror: sceneGrid.scenesVersion
                onScenesVersionMirrorChanged: {
                    sceneName = getSceneName(globalSceneId)
                    isEmpty = !hasScene(globalSceneId)
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                property int currentPageVersionMirror: sceneGrid.currentPageVersion
                onCurrentPageVersionMirrorChanged: {
                    sceneName = getSceneName(globalSceneId)
                    isEmpty = !hasScene(globalSceneId)
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                property int currentSceneVersionMirror: sceneGrid.currentSceneVersion
                onCurrentSceneVersionMirrorChanged: {
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                onSceneClicked: function(sceneId) {
                    selectScene(sceneId)
                }
                
                onSaveRequested: function(sceneId) {
                    let pedalPos = ((sceneId - 1) % 8) + 1
                    sceneSaveDialog.openDialog(sceneGrid.currentPage, pedalPos)
                }
            }
        }
    }
    
    // Deuxième rangée (positions 1-4)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        
        Repeater {
            model: 4
            delegate: SceneButton {
                pedalPosition: index + 1
                globalSceneId: (sceneGrid.currentPage - 1) * 8 + (index + 1)
                sceneName: getSceneName(globalSceneId)
                isEmpty: !hasScene(globalSceneId)
                currentScene: sceneGrid.currentScene
                
                // Miroir des versions pour déclencher les mises à jour
                property int scenesVersionMirror: sceneGrid.scenesVersion
                onScenesVersionMirrorChanged: {
                    sceneName = getSceneName(globalSceneId)
                    isEmpty = !hasScene(globalSceneId)
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                property int currentPageVersionMirror: sceneGrid.currentPageVersion
                onCurrentPageVersionMirrorChanged: {
                    sceneName = getSceneName(globalSceneId)
                    isEmpty = !hasScene(globalSceneId)
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                property int currentSceneVersionMirror: sceneGrid.currentSceneVersion
                onCurrentSceneVersionMirrorChanged: {
                    isActive = (sceneGrid.currentScene === globalSceneId)
                }
                
                onSceneClicked: function(sceneId) {
                    selectScene(sceneId)
                }
                
                onSaveRequested: function(sceneId) {
                    let pedalPos = ((sceneId - 1) % 8) + 1
                    sceneSaveDialog.openDialog(sceneGrid.currentPage, pedalPos)
                }
            }
        }
    }
} 