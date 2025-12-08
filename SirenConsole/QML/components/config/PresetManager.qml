import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: presetManager
    
    property var consoleController: null
    property var currentPresets: []
    
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 1
    radius: 8
    
    // Popup pour créer/modifier un preset
    Popup {
        id: presetDialog
        
        property bool isEditing: false
        property var editingPreset: null
        
        width: 400
        height: 300
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        // Titre du popup
        Text {
            text: presetDialog.isEditing ? "Modifier le Preset" : "Nouveau Preset"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
        }
        
        GridLayout {
            columns: 2
            rowSpacing: 10
            columnSpacing: 10
            anchors.fill: parent
            anchors.topMargin: 40
            
            Text {
                text: "Nom:"
                color: "#cccccc"
                Layout.preferredWidth: 80
            }
            TextField {
                id: presetNameField
                Layout.fillWidth: true
                placeholderText: "Nom du preset"
                text: presetDialog.isEditing ? (presetDialog.editingPreset ? presetDialog.editingPreset.name : "") : ""
            }
            
            Text {
                text: "Description:"
                color: "#cccccc"
                Layout.preferredWidth: 80
                Layout.alignment: Qt.AlignTop
            }
            TextArea {
                id: presetDescriptionField
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                placeholderText: "Description du preset"
                text: presetDialog.isEditing ? (presetDialog.editingPreset ? presetDialog.editingPreset.description : "") : ""
                wrapMode: TextArea.Wrap
            }
            
            Text {
                text: "Configuration:"
                color: "#cccccc"
                Layout.preferredWidth: 80
                Layout.alignment: Qt.AlignTop
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    visible: true
                }
                
                TextArea {
                    id: presetConfigField
                    placeholderText: "Configuration JSON (optionnel)"
                    text: presetDialog.isEditing ? (presetDialog.editingPreset ? JSON.stringify(presetDialog.editingPreset.config || {}, null, 2) : "") : ""
                    wrapMode: TextArea.Wrap
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }
        
        // Boutons en bas du popup
        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 10
            
            Button {
                text: "Annuler"
                onClicked: {
                    // Reset fields
                    presetNameField.text = ""
                    presetDescriptionField.text = ""
                    presetConfigField.text = ""
                    presetDialog.close()
                }
            }
            
            Button {
                text: isEditing ? "Modifier" : "Créer"
                onClicked: {
                    var presetData = {
                        name: presetNameField.text,
                        description: presetDescriptionField.text,
                        config: {}
                    }
                    
                    // Parser la configuration JSON si fournie
                    if (presetConfigField.text.trim() !== "") {
                        try {
                            presetData.config = JSON.parse(presetConfigField.text)
                        } catch (e) {
                            // Configuration JSON invalide
                        }
                    }
                    
                    if (isEditing && editingPreset) {
                        // Modifier le preset existant
                        consoleController.updatePreset(editingPreset.name, presetData)
                    } else {
                        // Créer un nouveau preset
                        consoleController.createPreset(presetData)
                    }
                    
                    // Reset fields
                    presetNameField.text = ""
                    presetDescriptionField.text = ""
                    presetConfigField.text = ""
                    presetDialog.close()
                }
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // Titre et boutons d'action
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Gestion des Presets"
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }
            
            Button {
                text: "Nouveau"
                implicitWidth: 80
                onClicked: {
                    presetDialog.isEditing = false
                    presetDialog.editingPreset = null
                    presetNameField.text = ""
                    presetDescriptionField.text = ""
                    presetConfigField.text = ""
                    presetDialog.open()
                }
            }
            
            Button {
                text: "Charger"
                implicitWidth: 80
                enabled: presetList.currentItem !== null
                onClicked: {
                    if (presetList.currentItem && presetList.currentItem.preset) {
                        consoleController.loadPreset(presetList.currentItem.preset.name)
                    }
                }
            }
        }
        
        // Liste des presets
        ListView {
            id: presetList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: currentPresets
            spacing: 5
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                visible: true
            }
            
            delegate: Rectangle {
                id: presetItem
                width: presetList.width
                height: 60
                color: presetList.currentIndex === index ? "#404040" : "#333333"
                border.color: "#555555"
                border.width: 1
                radius: 4
                
                property var preset: modelData
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: modelData.name || "Preset sans nom"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: modelData.description || "Aucune description"
                            color: "#cccccc"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                    
                    RowLayout {
                        spacing: 5
                        
                        Button {
                            text: "Modifier"
                            implicitWidth: 70
                            implicitHeight: 30
                            onClicked: {
                                presetDialog.isEditing = true
                                presetDialog.editingPreset = modelData
                                presetNameField.text = modelData.name || ""
                                presetDescriptionField.text = modelData.description || ""
                                presetConfigField.text = modelData.config ? JSON.stringify(modelData.config, null, 2) : ""
                                presetDialog.open()
                            }
                        }
                        
                        Button {
                            text: "Supprimer"
                            implicitWidth: 70
                            implicitHeight: 30
                            onClicked: {
                                deletePresetDialog.presetToDelete = modelData
                                deletePresetDialog.open()
                            }
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        presetList.currentIndex = index
                    }
                }
            }
            
            highlight: Rectangle {
                color: "#404040"
                border.color: "#00ff00"
                border.width: 2
                radius: 4
            }
        }
        
        // Message si aucun preset
        Text {
            text: "Aucun preset disponible"
            color: "#888888"
            font.italic: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: currentPresets.length === 0
        }
    }
    
    // Popup de confirmation de suppression
    Popup {
        id: deletePresetDialog
        
        property var presetToDelete: null
        
        width: 300
        height: 150
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        // Titre du popup
        Text {
            text: "Supprimer le Preset"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
        }
        
        Text {
            text: "Êtes-vous sûr de vouloir supprimer le preset \"" + (deletePresetDialog.presetToDelete ? deletePresetDialog.presetToDelete.name : "") + "\" ?"
            color: "#cccccc"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            anchors.centerIn: parent
            anchors.topMargin: 40
        }
        
        // Boutons de confirmation
        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 10
            
            Button {
                text: "Non"
                onClicked: deletePresetDialog.close()
            }
            
            Button {
                text: "Oui"
                onClicked: {
                    if (deletePresetDialog.presetToDelete) {
                        consoleController.deletePreset(deletePresetDialog.presetToDelete.name)
                    }
                    deletePresetDialog.close()
                }
            }
        }
    }
    
    // Fonction pour mettre à jour la liste des presets
    function updatePresets(presets) {
        currentPresets = presets || []
    }
    
    // Connexion au contrôleur
    Connections {
        target: consoleController
        function onPresetsListChanged(presets) {
            updatePresets(presets)
        }
    }
    
    Component.onCompleted: {
        if (consoleController) {
            updatePresets(consoleController.presets)
        }
    }
}
