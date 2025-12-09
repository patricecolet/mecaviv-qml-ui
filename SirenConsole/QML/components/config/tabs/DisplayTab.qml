import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: displayTab
    
    property var pupitre: null
    property int currentPupitreIndex: 0
    property int updateTrigger: 0
    property bool isAllMode: false
    property var allPupitres: []
    property var currentPresetSnapshot: null
    property var consoleController: null
    
    function forceRefresh() {
        updateTrigger++
    }
    
    // Fonction pour appliquer le paramètre à un pupitre spécifique
    function applyToPupitre(pupitreId, enabled) {
        if (!consoleController) return false
        return consoleController.setPupitreUiControlsEnabled(pupitreId, enabled)
    }
    
    // Fonction pour appliquer à tous les pupitres
    function applyToAllPupitres(enabled) {
        if (!isAllMode || !allPupitres || allPupitres.length === 0) return
        if (!consoleController) return
        
        var successCount = 0
        for (var i = 0; i < allPupitres.length; i++) {
            var pupitre = allPupitres[i]
            if (!pupitre || !pupitre.id) continue
            
            if (applyToPupitre(pupitre.id, enabled)) {
                successCount++
            }
        }
        
        forceRefresh()
        return successCount > 0
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15
        
        Text {
            text: "Affichage"
            color: "#ffffff"
            font.pixelSize: 18
            font.bold: true
        }
        
        Text {
            text: isAllMode ? "Paramètres d'affichage appliqués à tous les pupitres" : "Paramètres d'affichage pour ce pupitre"
            color: "#cccccc"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#555555"
        }
        
        // Contrôle pour masquer/afficher les boutons UI
        GroupBox {
            title: "Contrôles de l'interface"
            Layout.fillWidth: true
            
            background: Rectangle {
                color: "#2a2a2a"
                border.color: "#666666"
                border.width: 1
                radius: 6
            }
            
            label: Text {
                text: parent.title
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
                leftPadding: 10
                topPadding: 8
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                Text {
                    text: "Afficher les boutons de contrôle (admin, fretté, mode jeu, play, contrôleurs, morceaux)"
                    color: "#cccccc"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                
                CheckBox {
                    id: uiControlsCheckbox
                    text: "Afficher les boutons de contrôle"
                    Layout.preferredWidth: 300
                    
                    checked: true  // Par défaut, les boutons sont visibles
                    
                    indicator: Rectangle {
                        implicitWidth: 16
                        implicitHeight: 16
                        x: parent.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 2
                        border.color: parent.checked ? "#4a90e2" : "#666666"
                        color: parent.checked ? "#4a90e2" : "#444444"
                        
                        Text {
                            text: "✓"
                            color: "#ffffff"
                            anchors.centerIn: parent
                            visible: parent.parent.checked
                            font.pixelSize: 10
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        leftPadding: parent.indicator.width + parent.spacing
                        font.pixelSize: 14
                    }
                    
                    onToggled: {
                        // La checkbox représente "Afficher les boutons"
                        // checked = true → afficher → enabled = true → value = 1
                        // checked = false → masquer → enabled = false → value = 0
                        var enabled = checked
                        
                        if (isAllMode) {
                            // Mode "All" : appliquer à tous les pupitres
                            displayTab.applyToAllPupitres(enabled)
                        } else {
                            // Mode normal : appliquer au pupitre actuel
                            if (!pupitre || !pupitre.id) return
                            displayTab.applyToPupitre(pupitre.id, enabled)
                        }
                    }
                }
                
                Text {
                    text: "Quand décoché, tous les boutons de contrôle (admin, fretté, mode jeu, play, contrôleurs, morceaux) seront masqués sur le pupitre."
                    color: "#888888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}

