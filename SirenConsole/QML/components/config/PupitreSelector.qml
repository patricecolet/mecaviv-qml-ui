import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: pupitreSelector
    
    // Propriétés publiques
    property var pupitreNames: []
    property var pupitres: []
    property int currentPupitreIndex: 0
    property bool isAllMode: false // Mode "All" activé
    property var consoleController: null // Référence au ConsoleController pour accéder à l'état de sync
    
    // Signal émis quand un pupitre est sélectionné
    signal pupitreSelected(int index)
    signal allModeToggled(bool enabled)
    
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    color: "#2a2a2a"
    border.color: "#555555"
    border.width: 1
    radius: 8
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        
        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
            visible: true
        }
        
        RowLayout {
            width: parent.width
            spacing: 10

            // Bouton "All"
            Button {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 40
                text: "All"
                highlighted: pupitreSelector.isAllMode
                onClicked: {
                    pupitreSelector.isAllMode = !pupitreSelector.isAllMode
                    pupitreSelector.allModeToggled(pupitreSelector.isAllMode)
                    // Mode All
                }
                
                background: Rectangle {
                    color: parent.highlighted ? "#ff6b35" : (parent.hovered ? "#3a3a3a" : "#333333")
                    border.color: parent.highlighted ? "#ff8c5a" : "#555555"
                    border.width: 1
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.highlighted ? "#ffffff" : "#cccccc"
                    font.pixelSize: 12
                    font.bold: parent.highlighted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Repeater {
                model: pupitreSelector.pupitreNames
                
                Button {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 40
                    text: modelData
                    highlighted: index === pupitreSelector.currentPupitreIndex
                    onClicked: {
                        pupitreSelector.currentPupitreIndex = index
                        pupitreSelector.pupitreSelected(index)
                    }
                    
                    background: Rectangle {
                        color: parent.highlighted ? "#4a90e2" : (parent.hovered ? "#3a3a3a" : "#333333")
                        border.color: parent.highlighted ? "#6bb6ff" : "#555555"
                        border.width: 1
                        radius: 6
                    }
                    
                    contentItem: RowLayout {
                        spacing: 6
                        
                        // Indicateur de statut (connected/error/déconnecté)
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: {
                                var pupitre = pupitreSelector.pupitres[index]
                                if (!pupitre) return "#666666" // déconnecté
                                switch(pupitre.status) {
                                    case "connected": return "#00CC66"   // vert
                                    case "error":     return "#FF3333"   // rouge
                                    default:           return "#666666"   // déconnecté
                                }
                            }
                        }
                        
                        // Indicateur de synchronisation
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: {
                                // Obtenir l'état de sync depuis ConsoleController
                                if (pupitreSelector.consoleController) {
                                    var pupitreId = "P" + (index + 1)
                                    var propName = "pupitre" + (index + 1) + "Synced"
                                    var isSynced = false
                                    try {
                                        if (pupitreSelector.consoleController) {
                                            isSynced = pupitreSelector.consoleController[propName] || false
                                        }
                                    } catch (e) {
                                        // Ignorer les erreurs d'accès aux propriétés
                                    }
                                    return isSynced ? "#00ff00" : "#666666"
                                }
                                return "#666666" // non synchronisé par défaut
                            }
                        }
                        
                        Text {
                            text: parent.parent.text
                            color: parent.parent.highlighted ? "#ffffff" : "#cccccc"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
