import QtQuick
import QtQuick.Controls
import "../../../utils" as Utils

Rectangle {
    id: dialog
    width: 500
    height: 400
    color: "#333"
    radius: 12
    border.color: "#666"
    border.width: 2
    visible: false
    z: 1000
    
    property var logger
    property var webSocketController
    property var mainWindow  // ← Ajouter cette propriété
    property int currentPage: 1
    property int selectedSceneId: 1
    
    signal sceneSaved(string sceneName, int sceneId)
    signal dialogClosed()
    
    // Overlay sombre
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        radius: parent.radius
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 20
        width: parent.width - 40
        
        // En-tête
        Text {
            text: "💾 Sauvegarder la scène"
            color: "white"
            font.pixelSize: 20
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Info scène
        Rectangle {
            width: parent.width
            height: 60
            color: "#444"
            radius: 8
            border.color: "#666"
            
            Column {
                anchors.centerIn: parent
                Text {
                    text: "Page " + dialog.currentPage + " - Position " + dialog.selectedSceneId
                    color: "#aaa"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Scène ID: " + ((dialog.currentPage - 1) * 8 + dialog.selectedSceneId)
                    color: "lime"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Champ de saisie
        Rectangle {
            width: parent.width
            height: 50
            color: "#222"
            radius: 8
            border.color: sceneNameField.focus ? "lime" : "#555"
            border.width: 2
            
            TextField {
                id: sceneNameField
                anchors.fill: parent
                anchors.margins: 8
                color: "white"
                font.pixelSize: 16
                placeholderText: "Nom de la scène (ex: chorus_buildup)"
                background: Rectangle { color: "transparent" }
                selectByMouse: true
                
                onActiveFocusChanged: {
                    if (activeFocus) {
                        // Utiliser le clavier global au-dessus du champ
                        if (mainWindow) {
                            mainWindow.showKeyboard(sceneNameField, "above-target", sceneNameField);
                        }
                    }
                }
            }
            
            // MouseArea pour réouvrir le clavier
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (mainWindow && !mainWindow.globalVirtualKeyboard.visible) {
                        mainWindow.showKeyboard(sceneNameField, "above-target", sceneNameField);
                    }
                }
            }
        }
        
        // Boutons d'action
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15
            
            Button {
                text: "✅ Sauvegarder"
                width: 120
                height: 40
                enabled: sceneNameField.text.length > 0
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#5a8a5a" : "#6a9a6a") : "#444"
                    radius: 8
                    border.color: parent.enabled ? "#8aba8a" : "#666"
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : "#888"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    saveScene()
                }
            }
            
            Button {
                text: "❌ Annuler"
                width: 100
                height: 40
                
                background: Rectangle {
                    color: parent.pressed ? "#8a5a5a" : "#9a6a6a"
                    radius: 8
                    border.color: "#ba8a8a"
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    closeDialog()
                }
            }
        }
    }
    
    // Clavier virtuel direct avec position explicite
    Utils.VirtualKeyboard {
        id: virtualKeyboard
        
        // Ancrage forcé en haut
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 50
        
        visible: false
        
        onOkClicked: {
            visible = false
            sceneNameField.focus = false
        }
    }
    
    // ========== FONCTIONS MANQUANTES ==========
    
    function openDialog(page, sceneId) {
        currentPage = page;
        selectedSceneId = sceneId;
        sceneNameField.text = "";
        dialog.visible = true;
        sceneNameField.focus = true;
    }
    
    function closeDialog() {
        dialog.visible = false;
        if (mainWindow) {
            mainWindow.hideKeyboard();  // Fermer le clavier global
        }
        dialogClosed();
    }
    
    function saveScene() {
        if (sceneNameField.text.length === 0) return;
        
        let globalSceneId = (currentPage - 1) * 8 + selectedSceneId;
        let sceneName = sceneNameField.text;
        
        if (logger) {
            logger.info("SCENES", "💾 Sauvegarde scène:", sceneName, "ID global:", globalSceneId, "Page:", currentPage, "SceneId:", selectedSceneId);
        }
        
        if (webSocketController) {
            webSocketController.sendMessage({
                device: "LOOPER_SCENES",
                action: "saveScene",
                sceneId: selectedSceneId,      // ← ID local (1-8)
                page: currentPage,             // ← Page (1-8)
                globalSceneId: globalSceneId,  // ← ID global (1-64)
                sceneName: sceneName
            });
        }
        
        sceneSaved(sceneName, globalSceneId);
        closeDialog();
    }
} 