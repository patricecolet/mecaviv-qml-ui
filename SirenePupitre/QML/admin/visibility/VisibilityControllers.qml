import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    // Focus encodeur dans le panneau Admin (reçu depuis VisibilitySection)
    property int adminFocusIndex: -1
    property color focusColor: "#00BFFF"

    // Nombre d'éléments navigables dans cette section
    // 1 = CheckBox principale "Afficher le panneau", 2-7 = CheckBox secondaires, 8 = "Afficher les valeurs"
    readonly property int focusCount: 8

    // Fonction appelée par NavigationManager pour gérer la rotation de l'encodeur
    function handleEncoderStep(delta) {
        if (adminFocusIndex < 1 || adminFocusIndex > focusCount) return

        if (adminFocusIndex === 1) {
            // CheckBox principale "Afficher le panneau des contrôleurs"
            if (configController) {
                var current = configController.isComponentVisible("controllers")
                configController.setComponentVisibility("controllers", !current)
            }
        }
        // Les autres CheckBox (2-8) sont en lecture seule pour l'instant, pas de logique
    }
    
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
            id: controllersPanelCheckbox
            Layout.leftMargin: 20
            text: "Afficher le panneau des contrôleurs"
            property bool isFocused: root.adminFocusIndex === 1
            checked: {
                configController.updateCounter
                return configController ? configController.isComponentVisible("controllers") : true
            }
            font.pixelSize: 13
            font.bold: true
            
            contentItem: Text {
                text: parent.text
                color: parent.isFocused ? root.focusColor : "#FFD700"
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
                id: volantCheckbox
                text: "Volant"
                property bool isFocused: root.adminFocusIndex === 2
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: joystickCheckbox
                text: "Joystick"
                property bool isFocused: root.adminFocusIndex === 3
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: gearshiftCheckbox
                text: "Levier de vitesse"
                property bool isFocused: root.adminFocusIndex === 4
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: faderCheckbox
                text: "Fader"
                property bool isFocused: root.adminFocusIndex === 5
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: modPedalCheckbox
                text: "Pédale de modulation"
                property bool isFocused: root.adminFocusIndex === 6
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: padCheckbox
                text: "Pad"
                property bool isFocused: root.adminFocusIndex === 7
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
                id: showValuesCheckbox
                text: "Afficher les valeurs"
                property bool isFocused: root.adminFocusIndex === 8
                checked: true
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
