// @TODO: Ajouter la gestion de la suppression de 
// @NOTE: Les presets sont stockés côté serveur uniquement

import QtQuick
import QtQuick.Controls  // ← Ajoutez cet import !
// plus d'import statique du VirtualKeyboard

Item {
    id: root
    
    property var pedalConfigController
    property var webSocketController
    property var mainWindow
    property var logger
    
    width: 155
    height: 40
    //clip: true
    
    state: "normal"
    
    states: [
        State { name: "normal" },
        State { name: "saving" },
        State { name: "loading" }
    ]
    
    property Item virtualKeyboardInstance
    property var window: Qt.application.activeWindow
    property var overlayContainer
    
    // Propriété simple pour éviter le binding loop
    property var presetListModel: []
    
    // Connexion pour mettre à jour la liste des presets
    Connections {
        target: root.pedalConfigController
        function onAvailablePresetsChanged() {
            root.presetListModel = root.pedalConfigController.availablePresets || [];
            if (logger) logger.debug("PRESET", "🔍 presetListModel mis à jour :", root.presetListModel);
        }
    }
    
    onStateChanged: {
        if (logger) logger.debug("PRESET", "PedalPresetManager state:", root.state);
        if (root.virtualKeyboardInstance) {
            root.virtualKeyboardInstance.visible = (root.state === "saving");
            if (root.virtualKeyboardInstance.visible) {
                if (logger) logger.debug("PRESET", "Clavier virtuel affiché (état saving)");
            } else {
                if (logger) logger.debug("PRESET", "Clavier virtuel masqué (état non-saving)");
            }
        }
    }
    
    Component.onCompleted: {
        console.log("PedalPresetManager QML natif onCompleted exécuté");
        if (logger) logger.info("PRESET", "[PedalPresetManager] Component.onCompleted exécuté");
        
        // Initialiser la liste des presets
        root.presetListModel = root.pedalConfigController ? root.pedalConfigController.availablePresets : [];
        
        // La requête du preset courant est maintenant gérée dans WebSocketController.onStatusChanged
    }
    
    // Vue normale avec les boutons
    Row {
        visible: root.state === "normal"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 5
        
        Rectangle {
            width: 1
            height: 40
            color: "#606060"
        }
        
        Rectangle {
            width: 70
            height: 40
            color: saveMouseArea.pressed ? "#505050" : "#404040"
            border.color: "#808080"
            border.width: 1
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "Sauver"
                color: "white"
                font.pixelSize: 11
            }
            
            MouseArea {
                id: saveMouseArea
                anchors.fill: parent
                onClicked: {
                    root.state = "saving";
                    saveInput.text = "";
                    saveInput.forceActiveFocus();
                }
            }
        }
        
        Column {
            spacing: 2
            
            Rectangle {
                width: 70
                height: 40
                color: loadMouseArea.pressed ? "#505050" : "#404040"
                border.color: "#808080"
                border.width: 1
                radius: 3
                
                Text {
                    anchors.centerIn: parent
                    text: "Charger"
                    color: "white"
                    font.pixelSize: 11
                }
                
                MouseArea {
                    id: loadMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (logger) logger.debug("PRESET", "🔵 Ouverture du popup des presets");
                        if (root.webSocketController) {
                            root.webSocketController.requestPresetList();
                        }
                        presetListPopup.open();  // ← Ouvrir le popup au lieu de changer l'état
                    }
                }
            }
            
            // Affichage du preset courant
            Text {
                width: 70
                text: root.pedalConfigController ? root.pedalConfigController.currentPresetName : ""
                color: "#cccccc"
                font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
    
    // Vue de sauvegarde
    Row {
        visible: root.state === "saving"
        anchors.fill: parent
        spacing: 3
        
        Rectangle {
            width: 100
            height: 40
            color: "#404040"
            border.color: "#606060"
            radius: 3
            
            TextInput {
                id: saveInput
                anchors.fill: parent
                anchors.margins: 8
                color: "white"
                font.pixelSize: 11
                verticalAlignment: TextInput.AlignVCenter
                
                onAccepted: {
                    if (text.length > 0) {
                        savePreset(text);
                    }
                }
                
                Keys.onEscapePressed: {
                    root.state = "normal";
                }
                
                onActiveFocusChanged: {
                    if (logger) logger.debug("PRESET", "saveInput focus:", activeFocus);
                    if (activeFocus) {
                        if (logger) logger.debug("PRESET", "Appel showVirtualKeyboard depuis focus");
                        root.showVirtualKeyboard();
                    }
                    // On ne masque plus le clavier sur perte de focus
                }
            }
        }
        
        Rectangle {
            width: 25
            height: 40
            color: "#505050"
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "white"
                font.pixelSize: 14
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (saveInput.text.length > 0) {
                        savePreset(saveInput.text);
                    }
                }
            }
        }
        
        Rectangle {
            width: 25
            height: 40
            color: "#505050"
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "✗"
                color: "white"
                font.pixelSize: 14
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.state = "normal";
                }
            }
        }
    }
    
    // Clavier virtuel affiché uniquement en mode saving
    // VK.VirtualKeyboard { // This line is removed as per the edit hint
    //     id: virtualKeyboard
    //     anchors.top: parent.bottom
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     visible: root.state === "saving"
    //     z: 10000
    //     targetField: saveInput
    // }
    
    // Popup pour la liste des presets
    Popup {
        id: presetListPopup
        // parent: root
        // Position AU-DESSUS du bouton
        x: -10
        y: -height - 5  // Se positionne au-dessus
        z: 1000
        width: 200
        height: Math.min(listView.contentHeight + padding * 2, 250)  // Max 250px
        
        padding: 10
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        
        //z: 10000  // ← AJOUTER ICI pour que le Popup soit au-dessus de tout
        
        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#606060"
            border.width: 1
            radius: 5
        }
        
        // ListView avec ScrollBar
        ListView {
            id: listView
            anchors.fill: parent
            model: root.pedalConfigController ? root.pedalConfigController.availablePresets : []
            spacing: 2
            clip: true  // Important pour la scrollbar
            
            // SCROLLBAR
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded  // Apparaît seulement si nécessaire
                width: 8
                
                contentItem: Rectangle {
                    radius: 4
                    color: "#808080"
                }
            }
            
            delegate: Rectangle {
                width: listView.width - (listView.ScrollBar.vertical.visible ? 8 : 0)
                height: 30
                color: presetMouse.containsMouse ? "#505050" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 5
                    spacing: 5
                    
                    // Nom du preset
                    Text {
                        text: modelData
                        color: "white"
                        font.pixelSize: 12
                        width: parent.width - deleteButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }
                    
                    // Bouton supprimer
                    Rectangle {
                        id: deleteButton
                        width: 20
                        height: 20
                        radius: 3
                        color: deleteMouseArea.containsMouse ? "#aa4444" : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✕"  // ou "🗑" 
                            color: deleteMouseArea.containsMouse ? "white" : "#888888"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: deleteMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData === "default") {
                                    if (logger) logger.warn("PRESET", "⚠️ Impossible de supprimer le preset par défaut");
                                    return;
                                }
                                // Simple confirmation (vous pouvez faire mieux avec un Dialog)
                                if (logger) logger.info("PRESET", "🗑️ Suppression du preset:", modelData);
                                root.webSocketController.deletePreset(modelData);
                            }
                        }
                    }
                }
                
                // Zone cliquable pour charger (évite le bouton delete)
                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    anchors.rightMargin: 25  // Éviter la zone du bouton delete
                    hoverEnabled: true
                    onClicked: {
                        if (logger) logger.info("PRESET", "🎯 Chargement du preset:", modelData);
                        root.webSocketController.loadPreset(modelData);
                        presetListPopup.close();
                        root.state = "normal";
                    }
                }
            }
        }
    }
    
    // Liste déroulante pour charger
    Rectangle {
        visible: root.state === "loading"
        width: 180
        height: Math.min(presetList.count * 25 + 30, 200)
        y: 45    // ✅ Position sous le composant
        x: 10
        color: "#2a2a2a"
        border.color: "#606060"
        border.width: 1
        radius: 5
        //z: 1000  // S'assurer qu'il est au-dessus
        
        ListView {
            id: presetList
            anchors.fill: parent
            anchors.margins: 5
            anchors.bottomMargin: 30
            model: presetListModel
            spacing: 2
            //clip: true
            
            delegate: Rectangle {
                width: parent.width
                height: 25
                color: presetMouseLoading.containsMouse ? "#505050" : "transparent"
                radius: 3
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: "white"
                    font.pixelSize: 11
                }
                
                MouseArea {
                    id: presetMouseLoading
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.webSocketController) {
                            if (logger) logger.info("PRESET", "🎯 Chargement du preset:", modelData);
                            root.webSocketController.loadPreset(modelData);
                        }
                        root.state = "normal";
                    }
                }
            }
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 5
            width: 50
            height: 20
            color: "#505050"
            radius: 3
            
            Text {
                anchors.centerIn: parent
                text: "Fermer"
                color: "white"
                font.pixelSize: 10
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.state = "normal";
                }
            }
        }
    }
    
    function savePreset(name) {
        if (root.pedalConfigController && root.webSocketController) {
            let presetData = root.pedalConfigController.preparePresetData(name);
            if (logger) logger.info("PRESET", "💾 Sauvegarde du preset:", name);
            root.webSocketController.savePreset(name, presetData);
            root.state = "normal";
        }
    }

    function showVirtualKeyboard() {
        if (logger) logger.debug("PRESET", "Appel showVirtualKeyboard()");
        if (!root.virtualKeyboardInstance) {
            let component = Qt.createComponent("qrc:/qml/utils/VirtualKeyboard.qml");
            if (component.status === Component.Ready) {
                root.virtualKeyboardInstance = component.createObject(root.overlayContainer, {
                    targetField: saveInput,
                    z: 10000,
                    visible: true
                });
                if (logger) logger.debug("PRESET", "Clavier virtuel créé et affiché");
                Qt.callLater(function() {
                    root.virtualKeyboardInstance.x = (root.overlayContainer.width - root.virtualKeyboardInstance.width) / 2;
                    root.virtualKeyboardInstance.y = 20;
                });
            } else if (component.status === Component.Error) {
                if (logger) logger.error("PRESET", "Erreur lors du chargement du VirtualKeyboard:", component.errorString());
            }
        } else {
            root.virtualKeyboardInstance.visible = true;
            root.virtualKeyboardInstance.targetField = saveInput;
            root.virtualKeyboardInstance.x = (root.overlayContainer.width - root.virtualKeyboardInstance.width) / 2;
            root.virtualKeyboardInstance.y = 20;
            if (logger) logger.debug("PRESET", "Clavier virtuel réaffiché");
        }
    }
}
