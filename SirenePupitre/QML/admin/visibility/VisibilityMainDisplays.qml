import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var configController: null
    // Focus encodeur dans le panneau Admin (reçu depuis VisibilitySection)
    property int adminFocusIndex: -1
    property color focusColor: "#00BFFF"

    // Nombre d'éléments navigables dans cette section (pour NavigationManager)
    readonly property int focusCount: 5  // 5 CheckBox

    // Liste des IDs des CheckBox pour la navigation
    readonly property var checkboxIds: ["rpm", "frequency", "sirenCircle", "noteDetails", "musicalStaff"]

    // Fonction appelée par NavigationManager pour gérer la rotation de l'encodeur
    function handleEncoderStep(delta) {
        if (adminFocusIndex < 1 || adminFocusIndex > focusCount) return
        var checkboxIndex = adminFocusIndex - 1  // adminFocusIndex 1 = première checkbox (index 0)
        var componentId = checkboxIds[checkboxIndex]
        if (!componentId || !configController) return

        var currentValue = configController.isComponentVisible(componentId)
        configController.setComponentVisibility(componentId, !currentValue)
    }
    
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
                id: rpmCheckbox
                text: "Tours par minute (RPM)"
                property bool isFocused: root.adminFocusIndex === 1
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("rpm")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
                id: frequencyCheckbox
                text: "Fréquence (Hz)"
                property bool isFocused: root.adminFocusIndex === 2
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("frequency")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
                id: sirenCircleCheckbox
                text: "Cercle nom de sirène"
                property bool isFocused: root.adminFocusIndex === 3
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("sirenCircle")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
                id: noteDetailsCheckbox
                text: "Encadré détails note"
                property bool isFocused: root.adminFocusIndex === 4
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("noteDetails")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
                id: musicalStaffCheckbox
                text: "Portée musicale"
                property bool isFocused: root.adminFocusIndex === 5
                checked: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("musicalStaff")
                }
                font.pixelSize: 13
                
                contentItem: Text {
                    text: parent.text
                    color: parent.isFocused ? root.focusColor : "#bbb"
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
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
