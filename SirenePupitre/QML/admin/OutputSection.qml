import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        
        ColumnLayout {
            width: parent.width
            spacing: 30
            
            // Titre
            Text {
                text: "Configuration des Sorties"
                color: "#FFD700"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            
            // Section choix du mode de sortie
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                color: "#1a1a1a"
                border.color: "#333"
                border.width: 1
                radius: 5
                
                ColumnLayout {
                    id: modeColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    Text {
                        text: "Sortie Sirènes"
                        color: "#CCC"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    // Radio buttons pour UDP vs RTPMIDI
                    ButtonGroup {
                        id: sirenModeGroup
                    }
                    
                    RadioButton {
                        id: udpRadio
                        text: "Sirènes V1 via UDP"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp") === "udp" : true
                        ButtonGroup.group: sirenModeGroup
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: udpRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: udpRadio.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#FFD700"
                                visible: udpRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "udp")
                            }
                        }
                    }
                    
                    RadioButton {
                        id: rtpmidiRadio
                        text: "Sirènes V2 via RTPMIDI"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp") === "rtpmidi" : false
                        ButtonGroup.group: sirenModeGroup
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rtpmidiRadio.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: rtpmidiRadio.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: "#FFD700"
                                visible: rtpmidiRadio.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "sirenMode"], "rtpmidi")
                            }
                        }
                    }
                    
                    // Séparateur
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#333"
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                    }
                    
                    // Checkbox pour ComposeSirene
                    CheckBox {
                        id: composeSirenCheckbox
                        text: "ComposeSirene via midi interne"
                        checked: root.configController ? root.configController.getValueAtPath(["outputConfig", "composeSirenEnabled"], true) : true
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.checked ? "#FFD700" : "#AAA"
                            font.pixelSize: 14
                            leftPadding: parent.indicator.width + parent.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: composeSirenCheckbox.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 3
                            border.color: composeSirenCheckbox.checked ? "#FFD700" : "#666"
                            border.width: 2
                            color: "transparent"
                            
                            Rectangle {
                                width: 12
                                height: 12
                                x: 4
                                y: 4
                                radius: 2
                                color: "#FFD700"
                                visible: composeSirenCheckbox.checked
                            }
                        }
                        
                        onClicked: {
                            if (root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "composeSirenEnabled"], checked)
                            }
                        }
                    }
                }
            }
            
            // Section volume ComposeSirene
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "#1a1a1a"
                border.color: "#333"
                border.width: 1
                radius: 5
                
                ColumnLayout {
                    id: volumeColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Text {
                            text: "Master Volume ComposeSirene"
                            color: "#CCC"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            id: volumeValue
                            text: Math.round(volumeSlider.value)
                            color: "#FFD700"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    
                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 127
                        value: root.configController ? root.configController.getValueAtPath(["outputConfig", "composeSirenVolume"], 100) : 100
                        stepSize: 1
                        
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: volumeSlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: "#333"
                            
                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#FFD700"
                                radius: 3
                            }
                        }
                        
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: volumeSlider.pressed ? "#FFD700" : "#FFF"
                            border.color: "#FFD700"
                            border.width: 2
                        }
                        
                        onValueChanged: {
                            if (root.configController && !volumeSlider.pressed) {
                                return // Ne mettre à jour que quand l'utilisateur relâche
                            }
                        }
                        
                        onPressedChanged: {
                            if (!pressed && root.configController) {
                                root.configController.setValueAtPath(["outputConfig", "composeSirenVolume"], Math.round(value))
                            }
                        }
                    }
                    
                    // Marqueurs de volume
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        
                        Text {
                            text: "0"
                            color: "#666"
                            font.pixelSize: 12
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "64"
                            color: "#666"
                            font.pixelSize: 12
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "127"
                            color: "#666"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
        }
    }
    
    // Forcer la mise à jour quand le configController change
    Connections {
        target: root.configController
        function onUpdateCounterChanged() {
            // Force la mise à jour des RadioButtons, Checkbox et Slider
            var currentSirenMode = root.configController.getValueAtPath(["outputConfig", "sirenMode"], "udp")
            udpRadio.checked = (currentSirenMode === "udp")
            rtpmidiRadio.checked = (currentSirenMode === "rtpmidi")
            
            var composeSirenEnabled = root.configController.getValueAtPath(["outputConfig", "composeSirenEnabled"], true)
            composeSirenCheckbox.checked = composeSirenEnabled
            
            var currentVolume = root.configController.getValueAtPath(["outputConfig", "composeSirenVolume"], 100)
            if (!volumeSlider.pressed) {
                volumeSlider.value = currentVolume
            }
        }
    }
}
