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
            text: "Panneau des contrôleurs"
            color: "#FFD700"
            font.pixelSize: 18
            font.bold: true
        }
        
        CheckBox {
            Layout.leftMargin: 20
            text: "Afficher le panneau des contrôleurs"
            checked: {
                configController.updateCounter  // AJOUTER
                return configController ? configController.isComponentVisible("controllers") : true
            }
            font.pixelSize: 13
            font.bold: true
            
            contentItem: Text {
                text: parent.text
                color: "#FFD700"
                font.pixelSize: parent.font.pixelSize
                font.bold: parent.font.bold
                leftPadding: parent.indicator.width + 8
                verticalAlignment: Text.AlignVCenter
            }
            
            onToggled: {
                if (configController) {
                    configController.setComponentVisibility("controllers", checked)
                }
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            height: 1
            color: "#333"
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 20
            spacing: 8
            enabled: configController ? configController.isComponentVisible("controllers") : false
            opacity: enabled ? 1.0 : 0.5
            
            CheckBox {
                text: "Volant"
                checked: true
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
                text: "Joystick"
                checked: true
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
                text: "Levier de vitesse"
                checked: true
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
                text: "Fader"
                checked: true
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
                text: "Pédale de modulation"
                checked: true
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
                text: "Pad"
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#bbb" : "#666"
                    font.pixelSize: parent.font.pixelSize
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: -20
                Layout.rightMargin: 20
                height: 1
                color: "#333"
            }
            
            CheckBox {
                text: "Afficher les valeurs"
                checked: true
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
