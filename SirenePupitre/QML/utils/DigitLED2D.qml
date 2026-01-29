import QtQuick
import "./LEDText2D.qml"

Item {
    id: root
    
    property int value: 0
    property color activeColor: "red"
    property color inactiveColor: "#330000"
    
    LEDText2D {
        anchors.centerIn: parent
        text: "" + root.value  // Convertir en string
        textColor: root.activeColor
        offColor: root.inactiveColor
        letterHeight: 30
        letterSpacing: 25
        segmentWidth: 3
    }
}
