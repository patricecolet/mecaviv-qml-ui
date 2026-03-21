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
    // 1 = ComboBox viewMode, 2-8 = CheckBox (noteName, rpm, frequency, ambitus, cursor, highlight, progressBar)
    readonly property int focusCount: 8

    // Fonction appelée par NavigationManager pour gérer la rotation de l'encodeur
    function handleEncoderStep(delta) {
        if (adminFocusIndex < 1 || adminFocusIndex > focusCount) return
        var step = (delta > 0) ? 1 : -1

        if (adminFocusIndex === 1) {
            // ComboBox viewMode
            var newIndex = viewModeCombo.currentIndex + step
            if (newIndex < 0) newIndex = 0
            if (newIndex > 1) newIndex = 1
            viewModeCombo.currentIndex = newIndex
            if (configController) {
                configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "viewMode"], newIndex === 1 ? "piano" : "staff")
            }
        } else {
            // CheckBox (adminFocusIndex 2-8)
            var checkboxIndex = adminFocusIndex - 2
            // Mapping: 0=noteName, 1=rpm, 2=frequency, 3=ambitus, 4=cursor, 5=highlight, 6=progressBar
            var subComponentIds = ["noteName", "rpm", "frequency", "ambitus", "cursor", null, "progressBar"]

            if (checkboxIndex === 5) {
                // highlight (sous-option de cursor, adminFocusIndex 7)
                if (configController) {
                    var current = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], true)
                    configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "cursor", "showNoteHighlight"], !current)
                }
            } else if (checkboxIndex < subComponentIds.length && subComponentIds[checkboxIndex]) {
                var componentId = subComponentIds[checkboxIndex]
                if (componentId && configController) {
                    var currentValue = configController.isSubComponentVisible("musicalStaff", componentId)
                    configController.setSubComponentVisibility("musicalStaff", componentId, !currentValue)
                }
            }
        }
    }
    
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

        RowLayout {
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 12
            enabled: configController ? configController.isComponentVisible("musicalStaff") : true
            opacity: enabled ? 1.0 : 0.5
            Text {
                text: "Vue de l'ambitus :"
                color: root.adminFocusIndex === 1 ? root.focusColor : "#bbb"
                font.pixelSize: 13
                font.bold: root.adminFocusIndex === 1
            }
            ComboBox {
                id: viewModeCombo
                Layout.preferredWidth: 180
                model: ["Portée", "Piano"]
                property bool isFocused: root.adminFocusIndex === 1
                currentIndex: {
                    if (!configController) return 0
                    var dummy = configController.updateCounter
                    var mode = configController.getValueAtPath(["displayConfig", "components", "musicalStaff", "viewMode"], "staff")
                    return (mode === "piano") ? 1 : 0
                }
                onActivated: function(index) {
                    if (configController) {
                        configController.setValueAtPath(["displayConfig", "components", "musicalStaff", "viewMode"], index === 1 ? "piano" : "staff")
                    }
                }
                contentItem: Text {
                    text: viewModeCombo.displayText
                    color: viewModeCombo.isFocused ? root.focusColor : "#eee"
                    font.pixelSize: 13
                    font.bold: viewModeCombo.isFocused
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: viewModeCombo.indicator.width + 10
                }
                background: Rectangle {
                    color: "#2a2a2a"
                    border.color: viewModeCombo.isFocused ? root.focusColor : "#555"
                    border.width: viewModeCombo.isFocused ? 2 : 1
                    radius: 4
                }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 8
            enabled: configController ? configController.isComponentVisible("musicalStaff") : true
            opacity: enabled ? 1.0 : 0.5
            
            CheckBox {
                id: noteNameCheckbox
                text: "Nom de la note (sur la portée)"
                property bool isFocused: root.adminFocusIndex === 2
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: rpmStaffCheckbox
                text: "RPM sur la portée"
                property bool isFocused: root.adminFocusIndex === 3
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: frequencyStaffCheckbox
                text: "Fréquence sur la portée"
                property bool isFocused: root.adminFocusIndex === 4
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
                        
            CheckBox {
                id: ambitusCheckbox
                text: "Ambitus"
                property bool isFocused: root.adminFocusIndex === 5
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: cursorCheckbox
                text: "Curseur de note"
                property bool isFocused: root.adminFocusIndex === 6
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: highlightCheckBox
                Layout.leftMargin: 20  // Indentation pour montrer que c'est une sous-option
                text: "Highlight de la note"
                property bool isFocused: root.adminFocusIndex === 7
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
                    color: parent.isFocused ? root.focusColor : (parent.enabled ? "#bbb" : "#666")
                    font.pixelSize: parent.font.pixelSize
                    font.bold: parent.isFocused
                    leftPadding: parent.indicator.width + 8
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: progressBarCheckbox
                text: "Barre de progression"
                property bool isFocused: root.adminFocusIndex === 8
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