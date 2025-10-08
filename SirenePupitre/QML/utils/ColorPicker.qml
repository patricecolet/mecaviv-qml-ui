import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    id: root
    
    property string label: "Couleur:"
    property var configPath: []
    property string defaultColor: "#FFFFFF"
    property var configController: null
    property var webSocketController: null
    
    spacing: 10
    
    Text {
        text: root.label
        color: "#CCC"
        Layout.preferredWidth: 120
    }
    
    Rectangle {
        id: colorPreview
        Layout.preferredWidth: 60
        Layout.preferredHeight: 30
           color: {
               // Forcer la mise à jour avec updateCounter
               if (configController && configController.updateCounter >= 0) {
                   return configController.getValueAtPath(configPath) || defaultColor
               }
               return defaultColor
           }
        border.color: "#666"
        radius: 3
        
        ColorDialog {
            id: colorDialog
            
            onAccepted: {
                if (configController && configPath.length > 0) {
                    var hexColor = selectedColor.toString()
                    configController.setValueAtPath(configPath, hexColor)
                    
                    if (webSocketController) {
                        webSocketController.sendBinaryMessage({
                            type: "PARAM_CHANGED",
                            path: configPath,
                            value: hexColor
                        })
                    }
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                colorDialog.selectedColor = parent.color
                colorDialog.open()
            }
        }
    }
    
    Text {
        text: colorPreview.color
        color: "#888"
        font.family: "monospace"
    }
}