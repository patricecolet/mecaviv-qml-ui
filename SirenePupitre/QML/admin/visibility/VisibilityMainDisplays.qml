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
            text: "Affichages principaux"
            color: "#FFD700"
            font.pixelSize: 18
            font.bold: true
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 8
            
            CheckBox {
                text: "Tours par minute (RPM)"
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("rpm")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                onToggled: {
                    if (configController) {
                        configController.setComponentVisibility("rpm", checked)
                    }
                }
            }
            
            CheckBox {
                text: "Fréquence (Hz)"
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("frequency")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                onToggled: {
                    if (configController) {
                        configController.setComponentVisibility("frequency", checked)
                    }
                }
            }
            
            CheckBox {
                text: "Cercle nom de sirène"
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("sirenCircle")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                onToggled: {
                    if (configController) {
                        configController.setComponentVisibility("sirenCircle", checked)
                    }
                }
            }
            
            CheckBox {
                text: "Encadré détails note"
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("noteDetails")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                onToggled: {
                    if (configController) {
                        configController.setComponentVisibility("noteDetails", checked)
                    }
                }
            }

            CheckBox {
                text: "Portée musicale"
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("musicalStaff")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
                
                onToggled: {
                    if (configController) {
                        configController.setComponentVisibility("musicalStaff", checked)
                    }
                }
            }
        }
        
        // Note d'information
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.preferredHeight: 50
            color: "#2a2a2a"
            border.color: "#555"
            radius: 5
            
            Row {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "ℹ"
                    color: "#FFD700"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                Text {
                    text: "Les changements sont appliqués en temps réel"
                    color: "#888"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
