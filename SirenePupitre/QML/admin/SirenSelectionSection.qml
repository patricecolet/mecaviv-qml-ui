import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../shared/qml/common"

Item {
    id: root
    
    property var configController: null
    
    MusicUtils {
        id: musicUtils
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        Item { height: 10 }
        
        // Titre de la section
        Text {
            Layout.leftMargin: 20
            text: "Sélection de la sirène"
            color: "#FFD700"
            font.pixelSize: 20
            font.bold: true
        }
        
        // Zone de sélection des sirènes (sans ScrollView)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            Layout.margins: 20
            color: "#1a1a1a"
            border.color: "#333"
            radius: 10
            
            Flow {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                Repeater {
                    model: {
                        if (!root.configController || !root.configController.config) return []
                        // IMPORTANT: Forcer la reconstruction du modèle
                        var dummy = root.configController.updateCounter
                        return root.configController.config.sirenConfig.sirens
                    }
                    
                    delegate: Button {
                        id: sirenButton
                        width: 100
                        height: 80
                        
                        property bool isSelected: root.configController &&
                                                 root.configController.currentSiren &&
                                                 root.configController.currentSiren.id === modelData.id
                        
                        background: Rectangle {
                            color: sirenButton.isSelected ? "#FFD700" :
                                   (sirenButton.hovered ? "#3a3a3a" : "#2a2a2a")
                            border.color: sirenButton.isSelected ? "#FFA500" : "#555"
                            border.width: sirenButton.isSelected ? 2 : 1
                            radius: 8
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                        
                        contentItem: Column {
                            spacing: 3
                            anchors.centerIn: parent
                            
                            Text {
                                text: modelData.name
                                color: sirenButton.isSelected ? "black" : "white"
                                font.pixelSize: 18
                                font.bold: sirenButton.isSelected
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            
                            Text {
                                text: modelData.outputs + " sorties"
                                color: sirenButton.isSelected ? "#333" : "#888"
                                font.pixelSize: 13
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            
                            Text {
                                text: {
                                    if (!root.configController) return "♪ -"
                                    var min = modelData.ambitus.min
                                    var max = modelData.ambitus.max
                                    
                                    if (root.configController.mode === "restricted") {
                                        max = modelData.restrictedMax  // Utiliser directement modelData
                                    }
                                    
                                    return "♪ " + min + "-" + max
                                }
                                color: sirenButton.isSelected ? "#333" : "#666"
                                font.pixelSize: 11
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.selectSiren(modelData.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444"
        }
        
        // Informations détaillées sur la sirène sélectionnée
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            color: "#2a2a2a"
            border.color: "#444"
            radius: 5
            Layout.margins: 20
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                // En-tête avec le nom de la sirène
                Text {
                    text: configController && configController.currentSiren ? 
                          "Sirène " + configController.currentSiren.name : "Aucune sirène sélectionnée"
                    color: "#FFD700"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                // Section RestrictedMax seulement
                RowLayout {
                    spacing: 10
                    
                    Text {
                        text: "Mode global géré via bouton engrenage"
                        color: "#666"
                        font.pixelSize: 12
                        font.italic: true
                    }
                    
                    // Séparateur vertical
                    Rectangle {
                        width: 1
                        height: 30
                        color: "#444"
                        visible: configController ? configController.mode === "restricted" : true
                    }
                    
                    // Section RestrictedMax
                    RowLayout {
                        visible: configController ? configController.mode === "restricted" : true
                        spacing: 10
                        
                        Text {
                            text: "Note max:"
                            color: "#bbb"
                            font.pixelSize: 14
                        }
                        
                        SpinBox {
                            id: restrictedMaxSpinBox
                            from: configController && configController.currentSiren ? configController.currentSiren.ambitus.min : 0
                            to: configController && configController.currentSiren ? configController.currentSiren.ambitus.max : 127
                            value: {
                                if (!configController || !configController.currentSiren) return 72
                                var dummy = configController.updateCounter  // Force la réévaluation
                                return configController.currentSiren.restrictedMax
                            }
                            editable: true
                            
                            contentItem: TextInput {
                                text: parent.textFromValue(parent.value, parent.locale)
                                font: parent.font
                                color: "#FFD700"
                                horizontalAlignment: Qt.AlignHCenter
                                verticalAlignment: Qt.AlignVCenter
                                readOnly: !parent.editable
                                validator: parent.validator
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                rightPadding: 35  // Ajouter cette ligne pour la marge
                            }
                            
                            background: Rectangle {
                                implicitWidth: 90  // Augmenter un peu la largeur
                                color: "#1a1a1a"
                                border.color: "#FFD700"
                                radius: 5
                            }
                            
                            up.indicator: Rectangle {
                                x: parent.width - width - 1
                                height: parent.height / 2
                                width: 30
                                color: parent.up.pressed ? "#3a3a3a" : "#2a2a2a"
                                border.color: "#FFD700"
                                
                                Text {
                                    text: "+"
                                    color: "#FFD700"
                                    anchors.centerIn: parent
                                    font.pixelSize: 16
                                }
                            }
                            
                            down.indicator: Rectangle {
                                x: parent.width - width - 1
                                y: parent.height / 2
                                height: parent.height / 2
                                width: 30
                                color: parent.down.pressed ? "#3a3a3a" : "#2a2a2a"
                                border.color: "#FFD700"
                                
                                Text {
                                    text: "-"
                                    color: "#FFD700"
                                    anchors.centerIn: parent
                                    font.pixelSize: 16
                                }
                            }
                            
                            onValueModified: {
                                if (configController) {
                                    configController.setRestrictedMax(value)
                                }
                            }
                        }
                        
                        Text {
                            text: configController && configController.currentSiren ? 
                                  musicUtils.midiToNoteName(restrictedMaxSpinBox.value) : ""
                            color: "#FFD700"
                            font.pixelSize: 14
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                }
                
                // Infos de la sirène
                DetailItem {
                    label: "Ambitus"
                    value: configController && configController.currentSiren ? 
                           musicUtils.midiToNoteName(configController.currentSiren.ambitus.min) + 
                           " - " + musicUtils.midiToNoteName(configController.currentSiren.ambitus.max) : "-"
                }
                
                       DetailItem {
                           label: "Transposition"
                           value: configController && configController.currentSiren ? 
                                  configController.currentSiren.transposition + " octave(s)" : "-"
                       }
                
                       // Transposition d'affichage
                       RowLayout {
                           Layout.fillWidth: true
                           spacing: 10
                    
                           Text {
                               text: "Transposition affichage:"
                               color: "#888"
                               font.pixelSize: 13
                               Layout.preferredWidth: 120
                           }
                    
                           SpinBox {
                               id: displayOctaveSpinBox
                               from: -4
                               to: 4
                               value: {
                                   if (!configController || !configController.currentSiren) return 0
                                   var dummy = configController.updateCounter
                                   return configController.currentSiren.displayOctaveOffset || 0
                               }
                        
                               contentItem: TextInput {
                                   text: parent.textFromValue(parent.value, parent.locale)
                                   font: parent.font
                                   color: "#FFD700"
                                   horizontalAlignment: Qt.AlignHCenter
                                   verticalAlignment: Qt.AlignVCenter
                                   readOnly: !parent.editable
                                   validator: parent.validator
                                   inputMethodHints: Qt.ImhFormattedNumbersOnly
                                   rightPadding: 35
                               }
                        
                               background: Rectangle {
                                   implicitWidth: 90
                                   color: "#1a1a1a"
                                   border.color: "#FFD700"
                                   radius: 5
                               }
                        
                               up.indicator: Rectangle {
                                   x: parent.width - width - 1
                                   height: parent.height / 2
                                   width: 30
                                   color: parent.up.pressed ? "#3a3a3a" : "#2a2a2a"
                                   border.color: "#FFD700"
                            
                                   Text {
                                       text: "+"
                                       color: "#FFD700"
                                       anchors.centerIn: parent
                                       font.pixelSize: 16
                                   }
                               }
                        
                               down.indicator: Rectangle {
                                   x: parent.width - width - 1
                                   y: parent.height / 2
                                   height: parent.height / 2
                                   width: 30
                                   color: parent.down.pressed ? "#3a3a3a" : "#2a2a2a"
                                   border.color: "#FFD700"
                            
                                   Text {
                                       text: "-"
                                       color: "#FFD700"
                                       anchors.centerIn: parent
                                       font.pixelSize: 16
                                   }
                               }
                        
                               textFromValue: function(value) {
                                   if (value === 0) return "0"
                                   return (value > 0 ? "+" : "") + value
                               }
                        
                               onValueModified: {
                                   if (configController && configController.currentSiren) {
                                       var sirens = configController.config.sirenConfig.sirens
                                       for (var i = 0; i < sirens.length; i++) {
                                           if (sirens[i].id === configController.currentSiren.id) {
                                               configController.setValueAtPath(["sirenConfig", "sirens", i, "displayOctaveOffset"], value)
                                               break
                                           }
                                       }
                                   }
                               }
                           }
                    
                           Text {
                               text: "octave(s)"
                               color: "#888"
                               font.pixelSize: 13
                           }
                    
                           Item { Layout.fillWidth: true }
                       }
                
                       Text {
                           Layout.leftMargin: 120
                           text: "Décale l'affichage des notes sur la portée"
                           color: "#666"
                           font.pixelSize: 11
                           font.italic: true
                       }
                
                       Item { Layout.fillHeight: true }
            }
        }
    }
    
    // Composant pour afficher un détail
    component DetailItem : Row {
        property string label: ""
        property string value: ""
        
        spacing: 10
        
        Text {
            text: label + ":"
            color: "#888"
            font.pixelSize: 13
        }
        
        Text {
            text: value
            color: "#FFD700"
            font.pixelSize: 13
        }
    }
}
