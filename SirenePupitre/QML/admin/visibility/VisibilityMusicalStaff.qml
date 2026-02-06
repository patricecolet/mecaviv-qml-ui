import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        Item { height: 20 }
        
        Text {
            Layout.leftMargin: 20
            text: "Options de la portée musicale"
            color: "#FFD700"
            font.pixelSize: 18
            font.bold: true
        }
        
        Text {
            Layout.leftMargin: 20
            text: configController && !configController.isComponentVisible("musicalStaff") ? 
                  "⚠ La portée musicale est désactivée" : ""
            color: "#ff6666"
            font.pixelSize: 12
            visible: text !== ""
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 8
            enabled: configController ? configController.isComponentVisible("musicalStaff") : true
            opacity: enabled ? 1.0 : 0.5
            
            CheckBox {
                text: "Nom de la note (sur la portée)"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "noteName") : true
                }
                font.pixelSize: 13
                
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "noteName", checked)
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                text: "RPM sur la portée"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "rpm") : true
                }
                font.pixelSize: 13
                
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "rpm", checked)
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                text: "Fréquence sur la portée"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "frequency") : true
                }
                font.pixelSize: 13
                
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "frequency", checked)
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
                        
            CheckBox {
                text: "Ambitus"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "ambitus") : true
                }
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "ambitus", checked)
                    }
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                text: "Curseur de note"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "cursor") : true
                }
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "cursor", checked)
                    }
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: highlightCheckBox
                Layout.leftMargin: 20  // Indentation pour montrer que c'est une sous-option
                text: "Highlight de la note"
                enabled: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "cursor") : true
                }
                opacity: enabled ? 1.0 : 0.5
                checked: {
                    configController.updateCounter
                    return configController ? configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], true) : true
                }
                font.pixelSize: 13
                
                onToggled: {
                    if (configController) {
                        configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], checked)
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                text: "Barre de progression"
                checked: {
                    configController.updateCounter
                    return configController ? configController.isSubComponentVisible("musicalStaff", "progressBar") : true
                }
                onToggled: {
                    if (configController) {
                        configController.setSubComponentVisibility("musicalStaff", "progressBar", checked)
                    }
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}