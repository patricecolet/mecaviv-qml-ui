import QtQuick
import QtQuick.Controls

Button {
    id: root
    
    property bool isActive: false
    property bool isSelected: false
    property bool isPressedState: false
    property string labelText: ""
    property color activeColor: "#FF0000"
    property color selectedColor: "#FFD700"
    property color normalColor: "#444444"
    property color textColor: "#FFFFFF"
    
    // Support pour images (si disponibles)
    property string imageSource: ""
    property string imageSourceActive: ""
    
    contentItem: Text {
        text: root.labelText
        color: {
            if (root.isPressedState || root.isSelected) return "#000000"
            return root.textColor
        }
        font.pixelSize: Math.min(root.height * 0.5, 20)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
    }
    
    background: Rectangle {
        id: bgRect
        color: {
            if (root.isSelected) return root.selectedColor
            if (root.isActive || root.isPressedState) return root.activeColor
            return root.normalColor
        }
        border.color: {
            if (root.isSelected) return "#FFFFFF"
            if (root.isActive) return "#FF6666"
            return "#666666"
        }
        border.width: root.isSelected ? 3 : 2
        radius: root.height / 2
        
        Behavior on color {
            ColorAnimation { duration: 100 }
        }
        
        Behavior on border.color {
            ColorAnimation { duration: 100 }
        }
    }
    
    onPressedChanged: {
        isPressedState = pressed
    }
}
