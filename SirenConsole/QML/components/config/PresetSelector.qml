import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: presetSelector
    
    property var consoleController: null
    property var presets: []
    property string currentPreset: ""
    
    // Connexion directe au PresetManager
    property var presetManager: null
    
    // Timer pour vérification périodique des connexions
    Timer {
        id: connectionTimer
        interval: 1000 // 1 seconde
        repeat: true
        onTriggered: {
            if (consoleController && consoleController.presets && consoleController.presets.length > 0) {
                updatePresets()
                stop() // Arrêter le timer une fois les presets trouvés
            }
        }
    }
    
    height: 60
    Layout.fillWidth: true
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 1
    radius: 8
    
    // Popup pour créer/sauvegarder un preset
    Popup {
        id: savePresetDialog
        
        width: 400
        height: 200
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        Rectangle {
            anchors.fill: parent
            color: "#2a2a2a"
            border.color: "#555555"
            border.width: 1
            radius: 8
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "Sauvegarder un Preset"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Text {
                        text: "Nom:"
                        color: "#cccccc"
                        Layout.preferredWidth: 80
                    }
                    
                    TextField {
                        id: presetNameField
                        Layout.fillWidth: true
                        placeholderText: "Nom du preset"
                        color: "#ffffff"
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 4
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Text {
                        text: "Description:"
                        color: "#cccccc"
                        Layout.preferredWidth: 80
                    }
                    
                    TextField {
                        id: presetDescriptionField
                        Layout.fillWidth: true
                        placeholderText: "Description (optionnel)"
                        color: "#ffffff"
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 4
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    
                    Button {
                        text: "Annuler"
                        onClicked: {
                            presetNameField.text = ""
                            presetDescriptionField.text = ""
                            savePresetDialog.close()
                        }
                    }
                    
                    Button {
                        text: "Sauvegarder"
                        enabled: presetNameField.text.trim() !== ""
                        onClicked: {
                            if (consoleController) {
                                consoleController.createPresetFromCurrent(
                                    presetNameField.text.trim(),
                                    presetDescriptionField.text.trim()
                                )
                                currentPreset = presetNameField.text.trim()
                            }
                            presetNameField.text = ""
                            presetDescriptionField.text = ""
                            savePresetDialog.close()
                        }
                    }
                }
            }
        }
    }
    
    // Popup de confirmation de suppression
    Popup {
        id: deletePresetDialog
        
        width: 350
        height: 150
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        Rectangle {
            anchors.fill: parent
            color: "#2a2a2a"
            border.color: "#555555"
            border.width: 1
            radius: 8
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "Supprimer le Preset"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                Text {
                    text: "Êtes-vous sûr de vouloir supprimer le preset \"" + currentPreset + "\" ?"
                    color: "#cccccc"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    
                    Button {
                        text: "Non"
                        onClicked: deletePresetDialog.close()
                    }
                    
                    Button {
                        text: "Oui"
                        onClicked: {
                            if (consoleController && currentPreset !== "") {
                                consoleController.deletePreset(currentPreset)
                                currentPreset = ""
                            }
                            deletePresetDialog.close()
                        }
                    }
                }
            }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // Titre
        Text {
            text: "Preset:"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            Layout.preferredWidth: 80
        }
        
        // Button avec Menu pour sélectionner le preset
        Button {
            id: presetButton
            text: currentPreset || "Sélectionner un preset"
            Layout.fillWidth: true
            
            Menu {
                id: presetMenu
                
                Repeater {
                    model: presets
                    delegate: MenuItem {
                        text: modelData.name
                        onTriggered: {
                            currentPreset = modelData.name
                            if (consoleController) {
                                consoleController.loadPreset(modelData.name)
                            }
                        }
                    }
                }
            }
            
            onClicked: presetMenu.open()
        }
        
        // Bouton pour sauvegarder un preset
        Button {
            text: "Sauvegarder"
            Layout.preferredWidth: 80
            onClicked: savePresetDialog.open()
        }
        
        // Bouton pour appliquer le preset
        Button {
            text: "Appliquer"
            enabled: currentPreset !== ""
            Layout.preferredWidth: 80
            onClicked: {
                if (consoleController && currentPreset !== "") {
                    consoleController.loadPreset(currentPreset)
                }
            }
        }
        
        // Bouton pour supprimer le preset
        Button {
            text: "Supprimer"
            enabled: currentPreset !== ""
            Layout.preferredWidth: 80
            onClicked: {
                if (currentPreset !== "") {
                    deletePresetDialog.open()
                }
            }
        }
    }
    
    // Fonction pour mettre à jour la liste des presets
    function updatePresets() {
        // updatePresets appelé
        if (consoleController) {
            // consoleController.presets disponible
        }
        
        if (consoleController && consoleController.presets) {
            presets = consoleController.presets
            // Presets mis à jour
            for (var i = 0; i < presets.length; i++) {
                // Preset trouvé
            }
        } else {
            // Pas de presets disponibles
        }
    }
    
    // Connexion aux changements de presets
    Connections {
        target: consoleController
        function onPresetsListChanged(presetsList) {
            presets = presetsList
        }
    }
    
    // Connexion directe au PresetManager
    Connections {
        target: presetManager
        function onPresetsListChanged(presetsList) {
            presets = presetsList
        }
    }
    
    // Initialisation
    Component.onCompleted: {
        // Délai pour s'assurer que tout est bien connecté
        Qt.callLater(function() {
            if (consoleController) {
                updatePresets()
            }
            if (presetManager) {
                presetManager.loadPresetsFromStorage()
            }
            
            // Vérification périodique avec Timer QML
            connectionTimer.start()
        })
    }
    
    // Mise à jour quand le consoleController change
    onConsoleControllerChanged: {
        if (consoleController) {
            updatePresets()
        }
    }
    
    // Mise à jour quand le presetManager change
    onPresetManagerChanged: {
        if (presetManager) {
            presetManager.loadPresetsFromStorage()
        }
    }
}