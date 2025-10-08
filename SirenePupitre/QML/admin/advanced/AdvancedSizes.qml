import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    
    property var configController: null
    property var webSocketController: null
    
    ColumnLayout {
        width: parent.width
        spacing: 15
        
        Item { height: 10 }
        
        // Section Afficheurs LED
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Tailles des afficheurs"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            GridLayout {
                anchors.fill: parent
                columns: 3
                columnSpacing: 15
                rowSpacing: 10
                
                // Taille des digits
                Text {
                    text: "Taille des chiffres:"
                    color: "#CCC"
                    Layout.preferredWidth: 150
                }
                
                Slider {
                    id: digitSizeSlider
                    from: 0.5
                    to: 2.0
                    stepSize: 0.1
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "rpm", "ledSettings", "digitSize"]) || 1.0
                        }
                        return 1.0
                    }
                    Layout.preferredWidth: 150
                    
                    onValueChanged: {
                        if (configController && pressed) {
                            configController.setValueAtPath(["displayConfig", "components", "rpm", "ledSettings", "digitSize"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "rpm", "ledSettings", "digitSize"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: digitSizeSlider.value.toFixed(1)
                    color: "#888"
                    font.family: "monospace"
                }
                
                // Espacement entre digits
                Text {
                    text: "Espacement:"
                    color: "#CCC"
                }
                
                SpinBox {
                    id: digitSpacingSpinBox
                    from: 0
                    to: 50
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "rpm", "ledSettings", "spacing"]) || 10
                        }
                        return 10
                    }
                    Layout.preferredWidth: 150
                    
                    onValueModified: {
                        if (configController) {
                            configController.setValueAtPath(["displayConfig", "components", "rpm", "ledSettings", "spacing"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "rpm", "ledSettings", "spacing"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: "pixels"
                    color: "#888"
                }
            }
        }
        
        // Section Portée musicale
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Tailles sur la portée musicale"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            GridLayout {
                anchors.fill: parent
                columns: 3
                columnSpacing: 15
                rowSpacing: 10
                
                // Taille des notes
                Text {
                    text: "Taille des notes:"
                    color: "#CCC"
                    Layout.preferredWidth: 150
                }
                
                Slider {
                    id: noteSizeSlider
                    from: 0.05
                    to: 0.3
                    stepSize: 0.01
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "ambitus", "noteSize"]) || 0.15
                        }
                        return 0.15
                    }
                    Layout.preferredWidth: 150
                    
                    onValueChanged: {
                        if (configController && pressed) {
                            configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "ambitus", "noteSize"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "musicalStaff", "ambitus", "noteSize"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: noteSizeSlider.value.toFixed(2)
                    color: "#888"
                    font.family: "monospace"
                }
                
                // Largeur du curseur
                Text {
                    text: "Largeur curseur:"
                    color: "#CCC"
                }
                
                SpinBox {
                    id: cursorWidthSpinBox
                    from: 1
                    to: 10
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "width"]) || 3
                        }
                        return 3
                    }
                    Layout.preferredWidth: 150
                    
                    onValueModified: {
                        if (configController) {
                            configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "width"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "musicalStaff", "cursor", "width"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: "pixels"
                    color: "#888"
                }
                
                // Hauteur barre de progression
                Text {
                    text: "Hauteur barre:"
                    color: "#CCC"
                }
                
                SpinBox {
                    id: barHeightSpinBox
                    from: 2
                    to: 20
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "progressBar", "barHeight"]) || 5
                        }
                        return 5
                    }
                    Layout.preferredWidth: 150
                    
                    onValueModified: {
                        if (configController) {
                            configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "progressBar", "barHeight"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "musicalStaff", "progressBar", "barHeight"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: "pixels"
                    color: "#888"
                }
                
                // Offset Y du curseur
                Text {
                    text: "Offset Y curseur:"
                    color: "#CCC"
                }
                
                SpinBox {
                    id: cursorOffsetSpinBox
                    from: -50
                    to: 50
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "offsetY"]) || 30
                        }
                        return 30
                    }
                    Layout.preferredWidth: 150
                    
                    onValueModified: {
                        if (configController) {
                            configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "offsetY"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "musicalStaff", "cursor", "offsetY"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: "pixels"
                    color: "#888"
                }
            }
        }
        
        // Section Contrôleurs
        GroupBox {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            title: "Tailles des contrôleurs"
            
            label: Text {
                text: parent.title
                color: "#FFD700"
                font.pixelSize: 14
                font.bold: true
            }
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#444"
                radius: 5
            }
            
            GridLayout {
                anchors.fill: parent
                columns: 3
                columnSpacing: 15
                rowSpacing: 10
                
                // Échelle globale
                Text {
                    text: "Échelle globale:"
                    color: "#CCC"
                    Layout.preferredWidth: 150
                }
                
                Slider {
                    id: controllerScaleSlider
                    from: 0.5
                    to: 2.0
                    stepSize: 0.1
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "controllers", "scale"]) || 0.8
                        }
                        return 0.8
                    }
                    Layout.preferredWidth: 150
                    
                    onValueChanged: {
                        if (configController && pressed) {
                            configController.setValueAtPath(["displayConfig", "components", "controllers", "scale"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "controllers", "scale"],
                                    value: value
                                })
                            }
                        }
                    }
                }
                
                Text {
                    text: controllerScaleSlider.value.toFixed(1)
                    color: "#888"
                    font.family: "monospace"
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
                Text {
                    text: "Taille highlight:"
                    color: "#CCC"
                }

                Slider {
                    id: highlightSizeSlider
                    from: 0.1
                    to: 0.5
                    stepSize: 0.05
                    value: {
                        if (configController && configController.updateCounter >= 0) {
                            return configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightSize"]) || 0.25
                        }
                        return 0.25
                    }
                    Layout.preferredWidth: 150
                    
                    onValueChanged: {
                        if (configController && pressed) {
                            configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "highlightSize"], value)
                            
                            if (webSocketController) {
                                webSocketController.sendBinaryMessage({
                                    type: "PARAM_CHANGED",
                                    path: ["displayConfig", "components", "musicalStaff", "cursor", "highlightSize"],
                                    value: value
                                })
                            }
                        }
                    }
                }

                Text {
                    text: highlightSizeSlider.value.toFixed(2)
                    color: "#888"
                    font.family: "monospace"
                }
}